//
//  server.js
//  RydrPlayground
//
//  Created by Khris Nunnally on 8/19/25.
//
import express from "express";
import cors from "cors";
import admin from "firebase-admin";

// ---- Firebase Admin (we’ll point to the secret file on Render in Step 4) ----
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(process.env.GOOGLE_APPLICATION_CREDENTIALS || "/etc/secrets/firebase.json")
  });
}
const db = admin.firestore();

// ---- Express ----
const app = express();
app.use(express.json());
app.use(cors({ origin: true })); // tighten later if you want

// ---- Auth middleware (expects Authorization: Bearer <Firebase ID token>) ----
async function requireAuth(req, res, next) {
  try {
    const authz = req.headers.authorization || "";
    const [, token] = authz.split(" ");
    if (!token) return res.status(401).json({ error: "Missing token" });
    const decoded = await admin.auth().verifyIdToken(token);
    req.uid = decoded.uid;
    next();
  } catch (e) {
    res.status(401).json({ error: "Invalid token" });
  }
}

// ---- Helpers for codes ----
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no I,O,1,0
function randomCode(len = 8) {
  let s = "";
  for (let i = 0; i < len; i++) s += ALPHABET[Math.floor(Math.random() * ALPHABET.length)];
  return `RB-${s.slice(0,4)}-${s.slice(4,8)}`;
}

async function mintUniqueCode(t, uid) {
  let code, indexRef;
  while (true) {
    code = randomCode(8);
    indexRef = db.collection("codes_index").doc(code);
    const snap = await t.get(indexRef);
    if (!snap.exists) break;
  }
  const userCodes = db.collection("users").doc(uid).collection("rydrBankCodes");
  const newDocRef = userCodes.doc();

  t.set(indexRef, {
    code,
    currentOwnerUid: uid,
    codeDocPath: newDocRef.path,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });

  t.set(newDocRef, {
    code,
    status: "active",
    maxMiles: 15,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    reservedRideId: null,
    usedRideId: null,
    originalOwnerUid: uid,
    transferCount: 0,
    transferable: true
  });

  t.set(db.collection("users").doc(uid), {
    rydrBank: {
      codesAvailable: admin.firestore.FieldValue.increment(1),
      codesEarned: admin.firestore.FieldValue.increment(1)
    }
  }, { merge: true });

  return code;
}

async function incrementEligibleAndMaybeMint(t, uid, rideId) {
  const userRef    = db.collection("users").doc(uid);
  const contribRef = userRef.collection("rydrContrib").doc(rideId);

  // READS FIRST (required by Firestore)
  const [contribSnap, userSnap] = await Promise.all([
    t.get(contribRef),
    t.get(userRef),
  ]);

  // Idempotency: if we already counted this ride, do nothing
  if (contribSnap.exists) return null;

  const bank = (userSnap.exists ? userSnap.get("rydrBank") : null) || {};
  const currentEligible = bank.eligibleCount || 0;
  const nextEligible    = currentEligible + 1;

  // WRITES AFTER ALL READS
  t.set(contribRef, { contributedAt: admin.firestore.FieldValue.serverTimestamp() });
  t.set(userRef, {
    rydrBank: {
      eligibleCount:  admin.firestore.FieldValue.increment(1),
      totalEligible:  admin.firestore.FieldValue.increment(1),
    }
  }, { merge: true });

  // Every 10th eligible ride mints a code
  if (nextEligible % 10 === 0) {
    return await mintUniqueCode(t, uid);
  }
  return null;
}


// ---- Routes ----

// Health
app.get("/", (_, res) => res.send("RydrBank service up"));

// Earn on ride completion (eligible if distance >= 5)
app.post("/rides/complete", requireAuth, async (req, res) => {
  const { rideId, distanceMi } = req.body || {};
  if (!rideId || typeof distanceMi !== "number") return res.status(400).json({ error: "rideId and distanceMi required" });
  if (distanceMi < 5) return res.json({ eligible: false, minted: null });

  try {
    const minted = await db.runTransaction(async (t) => await incrementEligibleAndMaybeMint(t, req.uid, rideId));
    res.json({ eligible: true, minted });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "server_error" });
  }
});

// Validate + reserve a code for booking
app.post("/promo/preview", requireAuth, async (req, res) => {
  const { code, bookingId } = req.body || {};
  if (!code) return res.status(400).json({ error: "code required" });

  try {
    await db.runTransaction(async (t) => {
      const idxRef = db.collection("codes_index").doc(code);
      const idxSnap = await t.get(idxRef);
      if (!idxSnap.exists) throw new Error("not_found");

      const ownerUid = idxSnap.get("currentOwnerUid");
      if (ownerUid !== req.uid) throw new Error("not_owner");

      const codeRef = db.doc(idxSnap.get("codeDocPath"));
      const codeSnap = await t.get(codeRef);
      const data = codeSnap.data();
      if (!data) throw new Error("not_found");
      if (data.status !== "active") throw new Error("not_active");

      t.update(codeRef, { status: "reserved", reservedRideId: bookingId || "preview-" + Date.now() });
    });
    res.json({ ok: true, message: "RydrBank applied: up to 15 miles will be covered." });
  } catch (e) {
    res.status(400).json({ error: e.message || "cannot_preview" });
  }
});

// Release reservation (clear)
app.post("/promo/release", requireAuth, async (req, res) => {
  const { code } = req.body || {};
  if (!code) return res.status(400).json({ error: "code required" });

  try {
    await db.runTransaction(async (t) => {
      const idxRef = db.collection("codes_index").doc(code);
      const idxSnap = await t.get(idxRef);
      if (!idxSnap.exists) throw new Error("not_found");
      const ownerUid = idxSnap.get("currentOwnerUid");
      if (ownerUid !== req.uid) throw new Error("not_owner");

      const codeRef = db.doc(idxSnap.get("codeDocPath"));
      const codeSnap = await t.get(codeRef);
      const data = codeSnap.data();
      if (!data) throw new Error("not_found");
      if (data.status !== "reserved") return; // already free/used

      t.update(codeRef, { status: "active", reservedRideId: null });
    });
    res.json({ ok: true });
  } catch (e) {
    res.status(400).json({ error: e.message || "cannot_release" });
  }
});

// Consume after ride completion
app.post("/promo/consume", requireAuth, async (req, res) => {
  const { code, rideId } = req.body || {};
  if (!code || !rideId) return res.status(400).json({ error: "code and rideId required" });

  try {
    await db.runTransaction(async (t) => {
      const idxRef = db.collection("codes_index").doc(code);
      const idxSnap = await t.get(idxRef);
      if (!idxSnap.exists) throw new Error("not_found");
      const ownerUid = idxSnap.get("currentOwnerUid");
      if (ownerUid !== req.uid) throw new Error("not_owner");

      const codeRef = db.doc(idxSnap.get("codeDocPath"));
      const codeSnap = await t.get(codeRef);
      const data = codeSnap.data();
      if (!data) throw new Error("not_found");
      if (data.status !== "reserved" && data.status !== "active") throw new Error("bad_status");

      t.update(codeRef, { status: "used", usedRideId: rideId, reservedRideId: null });
      t.set(db.collection("users").doc(ownerUid), {
        rydrBank: { codesAvailable: admin.firestore.FieldValue.increment(-1) }
      }, { merge: true });
    });
    res.json({ ok: true });
  } catch (e) {
    res.status(400).json({ error: e.message || "cannot_consume" });
  }
});

// One-time transfer to a friend (by email)
app.post("/promo/transfer", requireAuth, async (req, res) => {
  const { code, recipientEmail } = req.body || {};
  if (!code || !recipientEmail) return res.status(400).json({ error: "code and recipientEmail required" });

  try {
    const recipient = await admin.auth().getUserByEmail(recipientEmail).catch(() => null);
    if (!recipient) return res.status(400).json({ error: "recipient_not_found" });
    if (recipient.uid === req.uid) return res.status(400).json({ error: "cannot_transfer_to_self" });

    await db.runTransaction(async (t) => {
      const idxRef = db.collection("codes_index").doc(code);
      const idxSnap = await t.get(idxRef);
      if (!idxSnap.exists) throw new Error("not_found");

      const ownerUid = idxSnap.get("currentOwnerUid");
      if (ownerUid !== req.uid) throw new Error("not_owner");

      const codeRef = db.doc(idxSnap.get("codeDocPath"));
      const codeSnap = await t.get(codeRef);
      const data = codeSnap.data();
      if (!data) throw new Error("not_found");
      if (data.status !== "active") throw new Error("not_active");
      if (data.transferCount !== 0 || data.transferable !== true) throw new Error("not_transferable");
      if (data.originalOwnerUid !== req.uid) throw new Error("only_original_owner_can_transfer");

      const recipRef = db.collection("users").doc(recipient.uid).collection("rydrBankCodes").doc();
      t.set(recipRef, {
        code: data.code,
        status: "active",
        maxMiles: data.maxMiles,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        reservedRideId: null,
        usedRideId: null,
        originalOwnerUid: data.originalOwnerUid,
        transferCount: 1,
        transferable: false
      });

      t.update(codeRef, { status: "void", transferCount: 1, transferable: false });
      t.update(idxRef, {
        currentOwnerUid: recipient.uid,
        codeDocPath: recipRef.path,
        transferredAt: admin.firestore.FieldValue.serverTimestamp()
      });

      t.set(db.collection("users").doc(req.uid), {
        rydrBank: { codesAvailable: admin.firestore.FieldValue.increment(-1) }
      }, { merge: true });
      t.set(db.collection("users").doc(recipient.uid), {
        rydrBank: { codesAvailable: admin.firestore.FieldValue.increment(1) }
      }, { merge: true });
    });

    res.json({ ok: true });
  } catch (e) {
    res.status(400).json({ error: e.message || "cannot_transfer" });
  }
});

// ---- Start server ----
const PORT = process.env.PORT || 8080;
app.listen(PORT, () => console.log("Listening on", PORT));
