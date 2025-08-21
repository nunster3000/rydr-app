// index.js
const express = require("express");
const cors = require("cors");
const Stripe = require("stripe");
const dotenv = require("dotenv");
dotenv.config();

if (!process.env.STRIPE_SECRET_KEY) {
  console.error("❌ Missing STRIPE_SECRET_KEY");
  process.exit(1);
}

const app = express();
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY, {
  apiVersion: "2024-06-20",
});

// ---- CORS (optional) ----
const allowed = (process.env.CORS_ORIGINS || "")
  .split(",").map(s => s.trim()).filter(Boolean);
app.use(
  cors({
    origin: (origin, cb) => {
      if (!origin || allowed.length === 0 || allowed.includes(origin)) return cb(null, true);
      cb(new Error("Not allowed by CORS"));
    },
  })
);

// ---- Health ----
app.get("/", (_req, res) => res.send("✅ Rydr Stripe backend is running"));

// ---- Webhook (RAW body; must be mounted BEFORE express.json) ----
app.post("/webhook", express.raw({ type: "application/json" }), (req, res) => {
  const sig = req.headers["stripe-signature"];
  try {
    const event = stripe.webhooks.constructEvent(
      req.body,
      sig,
      process.env.STRIPE_WEBHOOK_SECRET
    );

    switch (event.type) {
      case "setup_intent.succeeded":
        console.log("💳 Setup succeeded:", event.data.object.id);
        break;
      case "payment_intent.succeeded":
        console.log("💰 Payment succeeded:", event.data.object.id);
        break;
      case "payment_intent.payment_failed":
        console.log("⚠️ Payment failed:", event.data.object.id);
        break;
      default:
        console.log("ℹ️ Unhandled event:", event.type);
    }
    res.sendStatus(200);
  } catch (err) {
    console.error("❌ Webhook verify failed:", err.message);
    res.status(400).send(`Webhook Error: ${err.message}`);
  }
});

// ---- JSON parser for all other routes ----
app.use(express.json());

// ---- Create or get Customer ----
// Body: { uid?: string, email?: string, name?: string } -> { customerId }
app.post("/create-customer", async (req, res) => {
  try {
    const { uid, email, name } = req.body || {};

    // 1) Prefer lookup by Firebase UID in metadata
    if (uid) {
      const byUid = await stripe.customers.search({
        query: `metadata['firebase_uid']:'${uid}'`,
      });
      if (byUid.data.length) {
        return res.json({ customerId: byUid.data[0].id });
      }
    }

    // 2) Fallback by email (if migrating older customers)
    if (email) {
      const byEmail = await stripe.customers.search({ query: `email:'${email}'` });
      if (byEmail.data.length) {
        if (uid) {
          await stripe.customers.update(byEmail.data[0].id, {
            metadata: { firebase_uid: uid },
          });
        }
        return res.json({ customerId: byEmail.data[0].id });
      }
    }

    // 3) Create new
    const customer = await stripe.customers.create({
      email: email || undefined,
      name: name || undefined,
      metadata: uid ? { firebase_uid: uid } : undefined,
    });
    res.json({ customerId: customer.id });
  } catch (err) {
    console.error("❌ create-customer:", err);
    res.status(400).json({ error: err.message });
  }
});

// ---- Ephemeral Key ----
// Headers: Stripe-Version; Body: { customerId }
app.post("/ephemeral-key", async (req, res) => {
  try {
    const { customerId } = req.body || {};
    const apiVer = req.headers["stripe-version"];
    if (!customerId) throw new Error("customerId is required");
    if (!apiVer) throw new Error("Missing Stripe-Version header");

    const key = await stripe.ephemeralKeys.create(
      { customer: customerId },
      { apiVersion: String(apiVer) }
    );
    res.json(key);
  } catch (err) {
    console.error("❌ ephemeral-key:", err);
    res.status(400).json({ error: err.message });
  }
});

// ---- SetupIntent (save a card) ----
// Body: { customerId } -> { clientSecret }
app.post("/create-setup-intent", async (req, res) => {
  try {
    const { customerId } = req.body || {};
    if (!customerId) throw new Error("customerId is required");
    const si = await stripe.setupIntents.create({
      customer: customerId,
      payment_method_types: ["card"],
      usage: "off_session",
    });
    res.json({ clientSecret: si.client_secret });
  } catch (err) {
    console.error("❌ create-setup-intent:", err);
    res.status(400).json({ error: err.message });
  }
});

// ---- PaymentIntent (charge) ----
// Body: { amount (cents), currency, customerId? } -> { clientSecret, paymentIntentId }
app.post("/create-payment-intent", async (req, res) => {
  try {
    const { amount, currency = "usd", customerId } = req.body || {};
    if (!Number.isInteger(amount) || amount <= 0) {
      throw new Error("amount (integer cents) is required and must be > 0");
    }
    const pi = await stripe.paymentIntents.create({
      amount,
      currency,
      customer: customerId,
      automatic_payment_methods: { enabled: true },
    });
    res.json({ clientSecret: pi.client_secret, paymentIntentId: pi.id });
  } catch (err) {
    console.error("❌ create-payment-intent:", err);
    res.status(400).json({ error: err.message });
  }
});

// ---- Listen ----
const PORT = process.env.PORT || 10000;
app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));






