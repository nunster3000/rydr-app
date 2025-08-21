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
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

// ---------- CORS ----------
const allowed = (process.env.CORS_ORIGINS || "")
  .split(",")
  .map(o => o.trim())
  .filter(Boolean);

app.use(
  cors({
    origin: (origin, cb) => {
      if (!origin || allowed.includes(origin)) return cb(null, true);
      return cb(new Error("Not allowed by CORS"));
    },
  })
);

// ---------- Health ----------
app.get("/", (_req, res) => {
  res.send("✅ Rydr Stripe backend is running");
});

// ---------- WEBHOOK (RAW BODY) ----------
app.post(
  "/webhook",
  express.raw({ type: "application/json" }),
  (req, res) => {
    const sig = req.headers["stripe-signature"];
    const endpointSecret = process.env.STRIPE_WEBHOOK_SECRET;
    let event;

    try {
      event = stripe.webhooks.constructEvent(req.body, sig, endpointSecret);
    } catch (err) {
      console.error("❌ Webhook signature verification failed:", err.message);
      return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    switch (event.type) {
      case "payment_intent.succeeded": {
        const pi = event.data.object;
        console.log("💰 Payment succeeded:", pi.id);
        break;
      }
      case "payment_intent.payment_failed": {
        const pi = event.data.object;
        console.log("⚠️ Payment failed:", pi.id);
        break;
      }
      case "setup_intent.succeeded": {
        const si = event.data.object;
        console.log("💳 Setup succeeded:", si.id);
        break;
      }
      default:
        console.log(`ℹ️ Unhandled event type: ${event.type}`);
    }

    res.json({ received: true });
  }
);

// ---------- JSON parser for all *other* routes ----------
app.use(express.json());

// ---------- Customers (create-or-get) ----------
/**
 * Body: { uid?: string, email?: string, name?: string }
 * Returns: { customerId }
 * Strategy: prefer metadata.firebase_uid; fallback to email; else create.
 */
app.post("/create-customer", async (req, res) => {
  try {
    const { uid, email, name } = req.body || {};

    // 1) Find by uid in metadata (if provided)
    if (uid) {
      const byUid = await stripe.customers.search({
        query: `metadata['firebase_uid']:'${uid}'`,
      });
      if (byUid.data.length) {
        return res.json({ customerId: byUid.data[0].id });
      }
    }

    // 2) Fallback by email (if provided)
    if (email) {
      const byEmail = await stripe.customers.search({ query: `email:'${email}'` });
      if (byEmail.data.length) {
        // backfill uid for future lookups
        if (uid) {
          await stripe.customers.update(byEmail.data[0].id, {
            metadata: { firebase_uid: uid },
          });
        }
        return res.json({ customerId: byEmail.data[0].id });
      }
    }

    // 3) Create new customer
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

// ---------- Ephemeral Key ----------
/**
 * Headers: { "Stripe-Version": "<iOS SDK API version>" }
 * Body: { customerId: "cus_..." }
 */
app.post("/ephemeral-key", async (req, res) => {
  try {
    const { customerId } = req.body || {};
    const stripeVersion =
      req.headers["stripe-version"] || req.headers["Stripe-Version"];
    if (!customerId) throw new Error("customerId is required");
    if (!stripeVersion) throw new Error("Stripe-Version header is required");

    const key = await stripe.ephemeralKeys.create(
      { customer: customerId },
      { apiVersion: String(stripeVersion) }
    );
    res.status(200).json(key);
  } catch (err) {
    console.error("❌ ephemeral-key:", err);
    res.status(400).json({ error: err.message });
  }
});

// ---------- SetupIntent (save card) ----------
/**
 * Body: { customerId: "cus_..." }
 * Returns: { clientSecret }
 */
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

// ---------- PaymentIntent (charge) ----------
/**
 * Body: { amount: <int cents>, currency: "usd", customerId?: "cus_..." }
 * Returns: { clientSecret, paymentIntentId }
 */
app.post("/create-payment-intent", async (req, res) => {
  try {
    const { amount, currency = "usd", customerId, automatic = true } =
      req.body || {};

    if (!Number.isInteger(amount) || amount <= 0) {
      throw new Error("amount (integer, cents) is required and must be > 0");
    }

    const pi = await stripe.paymentIntents.create({
      amount,
      currency,
      customer: customerId,
      automatic_payment_methods: { enabled: !!automatic },
      metadata: req.body?.metadata || {},
    });

    res.json({ clientSecret: pi.client_secret, paymentIntentId: pi.id });
  } catch (err) {
    console.error("❌ create-payment-intent:", err);
    res.status(400).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 10000;
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});

});





