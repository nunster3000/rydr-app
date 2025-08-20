// server.js
// RydrBank service — Express + Firebase Admin + Firestore
// Fix: Firestore transactions now perform ALL READS before ANY WRITES.

import express from "express";
import cors from "cors";
import admin from "firebase-admin";

// ---------- Firebase Admin ----------
if (!admin.apps.length) {
  admin.initializeApp({
    // On Render, mount your service account JSON as a Secret File
    // Path should be /etc/secrets/firebase.json and exposed as env var below
    credential: admin.credential.cert(
      process.env.GOOGLE_APPLICATION_CREDENTIALS || "/etc/secrets/firebase.json"
    ),
  });
}
const db = admin.firestore();

// ---------- Express ----------
const app = express();
app.use(express.json());
app.use(cors({ origin: true })); // tighten later if needed

// ---------- Auth middleware ----------
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

// ---------- Helpers ----------
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no I,O,1,0
function randomCode(len = 8) {
  let s = "";
  for (let i = 0; i < len; i++) {
    s += ALPHABET[Math.floor(Math.random() * ALPHABET.length)];
  }
  // Format RB-XXXX-XXXX
  return `RB-${s.slice(0, 4)}-${s.slice(4, 8)}`;
}

// NOTE: We DO NOT write inside this function.
// It only generates an unused code value by reading codes_index docs.
// It will be called BEFORE any writes happen in the transaction.
async function reserveUniqueCodeReadsOnly(t) {
  while (true) {
    const code = randomCode(8);
    const indexRef = db.collection("codes_index").doc(code);
    const idxSnap = await t.get(indexRef); // READ
    if (!idxSnap.exists) {
      // Return the chosen code and the indexRef to write later
      return { code, indexRef };
    }
  }
}

// Combined accrual + (optional) mint inside ONE transaction with proper ordering.
async function accrueAndMaybeMintInOneTxn(uid, rideId, distanceMi) {
  if (typeof distanceMi !== "number" || distanceMi < 5) {
    return { eligible: false, minted: null };
  }

  const userRef = db.collection("users").doc(uid);
  const contribRef = userRef.collection("rydrContrib").doc(rideId);

  const result = await db.runTransaction(async (t) => {
    // === READS FIRST ===
    const [contribSnap, userSnap] = await Promise.all([
      t.get(contribRef),
      t.get(userRef),
    ]);

    // Idempotency: if we already counted this ride, do nothing.
    if (contribSnap.exists) {
      const bank = (userSnap.exists ? userSnap.get("rydrBank") : null) || {};
      return { eligible: true, minted: null, currentEligible: bank.eligibleCount || 0 };
    }

    const bank = (userSnap.exists ? userSnap.get("rydrBank") : null) || {};
    const currentEligible = bank.eligibleCount || 0;
    const nextEligible = currentEligible + 1;

    // If we will mint on this ride, we must also do ALL READS related to minting
    // BEFORE any writes. That includes checking codes_index to pick a unique code.
    let mintPlan = null;
    if (nextEligible % 10 === 0) {
      const { code, indexRef } = await reserveUniqueCodeReadsOnly(t); // READS ONLY
      // Prepare refs for writes later:
      const newCodeRef = userRef.collection("rydrBankCodes").doc(); // id chosen, no write yet
      mintPlan = { code, indexRef, newCodeRef };
    }

    // === WRITES AFTER ALL READS ===
    // 1) Count this ride as contributed
    t.set(contribRef, {
      contributedAt: admin.firestore.FieldValue.serverTimestamp(),
      distanceMi,
    });

    // 2) Update counters
    t.set(
      userRef,
      {
        rydrBank: {
          eligibleCount: admin.firestore.FieldValue.increment(1),
          totalEligible: admin.firestore.FieldValue.increment(1),
        },
      },
      { merge: true }
    );

    // 3) If minting, write new code docs/updates
    if (mintPlan) {
      const { code, indexRef, newCodeRef } = mintPlan;

      // codes_index (pointer to the owner + path)
      t.set(indexRef, {
        code,
        currentOwnerUid: uid,
        codeDocPath: newCodeRef.path,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // user copy
      t.set(newCodeRef, {
        code,
        status: "active", // active | reserved | used | void
        maxMiles: 15,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        reservedRideId: null,
        usedRideId: null,
        originalOwnerUid: uid,
        transferCount: 0,
        transferable: true,
      });

      // counters
      t.set(
        userRef,
        {
          rydrBank: {
            codesAvailable: admin.firestore.FieldValue.increment(1),
            codesEarned: admin.firestore.FieldValue.increment(1),
          },
        },
        { merge: true }
      );

      return { eligible: true, minted: code, currentEligible: nextEligible };
    }

    return { eligible: true, minted: null, currentEligible: nextEligible };
  });

  return { eligible: true, minted: result.minted || null };
}

// ---------- Routes ----------

// Health
app.get("/", (_, res) => res.send("RydrBank service up"));

// Earn (simulate ride completion). distanceMi >= 5 required to be eligible.
app.post("/rides/complete", requireAuth, async (req, res) => {
  try {
    const { rideId, distanceMi } = req.body || {};
    if (!rideId || typeof distanceMi !== "number") {
      return res.status(400).json({ error: "rideId and distanceMi required" });
    }
    const out = await accrueAndMaybeMintInOneTxn(req.uid, rideId, distanceMi);
    return res.json(out);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: "server_error" });
  }
});

// Reserve a code for a booking (preview/apply)
app.post("/promo/preview", requireAuth, async (req, res) => {
  const { code, bookingId } = req.body || {};
  if (!code) return res.status(400).json({ error: "code required" });

  try {
    await db.runTransaction(async (t) => {
      // READS
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

      // WRITES
      t.update(codeRef, {
        status: "reserved",
        reservedRideId: bookingId || "preview-" + Date.now(),
      });
    });

    res.json({
      ok: true,
      message: "RydrBank applied: up to 15 miles will be covered.",
    });
  } catch (e) {
    console.error(e);
    res.status(400).json({ error: e.message || "cannot_preview" });
  }
});

// Release a reserved code
app.post("/promo/release", requireAuth, async (req, res) => {
  const { code } = req.body || {};
  if (!code) return res.status(400).json({ error: "code required" });

  try {
    await db.runTransaction(async (t) => {
      // READS
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

      // WRITES
      t.update(codeRef, { status: "active", reservedRideId: null });
    });

    res.json({ ok: true });
  } catch (e) {
    console.error(e);
    res.status(400).json({ error: e.message || "cannot_release" });
  }
});

// Consume a code after the ride is completed
app.post("/promo/consume", requireAuth, async (req, res) => {
  const { code, rideId } = req.body || {};
  if (!code || !rideId) return res.status(400).json({ error: "code and rideId required" });

  try {
    await db.runTransaction(async (t) => {
      // READS
      const idxRef = db.collection("codes_index").doc(code);
      const idxSnap = await t.get(idxRef);
      if (!idxSnap.exists) throw new Error("not_found");
      const ownerUid = idxSnap.get("currentOwnerUid");
      if (ownerUid !== req.uid) throw new Error("not_owner");

      const codeRef = db.doc(idxSnap.get("codeDocPath"));
      const codeSnap = await t.get(codeRef);
      const data = codeSnap.data();
      if (!data) throw new Error("not_found");
      if (data.status !== "reserved" && data.status !== "active")
        throw new Error("bad_status");

      // WRITES
      t.update(codeRef, { status: "used", usedRideId: rideId, reservedRideId: null });
      t.set(
        db.collection("users").doc(ownerUid),
        { rydrBank: { codesAvailable: admin.firestore.FieldValue.increment(-1) } },
        { merge: true }
      );
    });

    res.json({ ok: true });
  } catch (e) {
    console.error(e);
    res.status(400).json({ error: e.message || "cannot_consume" });
  }
});

// One-time transfer to a friend (by email)
app.post("/promo/transfer", requireAuth, async (req, res) => {
  const { code, recipientEmail } = req.body || {};
  if (!code || !recipientEmail)
    return res.status(400).json({ error: "code and recipientEmail required" });

  try {
    const recipient = await admin.auth().getUserByEmail(recipientEmail).catch(() => null);
    if (!recipient) return res.status(400).json({ error: "recipient_not_found" });
    if (recipient.uid === req.uid) return res.status(400).json({ error: "cannot_transfer_to_self" });

    await db.runTransaction(async (t) => {
      // READS
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
      if (data.transferCount !== 0 || data.transferable !== true)
        throw new Error("not_transferable");
      if (data.originalOwnerUid !== req.uid)
        throw new Error("only_original_owner_can_transfer");

      const recipRef = db.collection("users").doc(recipient.uid).collection("rydrBankCodes").doc();

      // WRITES
      t.set(recipRef, {
        code: data.code,
        status: "active",
        maxMiles: data.maxMiles,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        reservedRideId: null,
        usedRideId: null,
        originalOwnerUid: data.originalOwnerUid,
        transferCount: 1,
        transferable: false,
      });

      t.update(codeRef, { status: "void", transferCount: 1, transferable: false });

      t.update(idxRef, {
        currentOwnerUid: recipient.uid,
        codeDocPath: recipRef.path,
        transferredAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      t.set(
        db.collection("users").doc(req.uid),
        { rydrBank: { codesAvailable: admin.firestore.FieldValue.increment(-1) } },
        { merge: true }
      );
      t.set(
        db.collection("users").doc(recipient.uid),
        { rydrBank: { codesAvailable: admin.firestore.FieldValue.increment(1) } },
        { merge: true }
      );
    });

    res.json({ ok: true });
  } catch (e) {
    console.error(e);
    res.status(400).json({ error: e.message || "cannot_transfer" });
  }
});

// ---------- Start ----------
const PORT = process.env.PORT || 8080;
app.listen(PORT, () => console.log("Listening on", PORT));
