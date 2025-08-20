// index.js
const express = require("express");
const cors = require("cors");
const Stripe = require("stripe");
const dotenv = require("dotenv");

// Load .env locally; on Render, set env vars in the dashboard
dotenv.config();

if (!process.env.STRIPE_SECRET_KEY) {
  console.error("❌ Missing STRIPE_SECRET_KEY");
  process.exit(1);
}

const app = express();
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

// ---------- CORS ----------
/**
 * Allow your web origins for local/dev + prod.
 * Mobile apps (iOS/Android) often send no Origin, so we allow !origin too.
 */
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

// ---------- WEBHOOK (must receive RAW BODY; mount BEFORE express.json) ----------
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
        // TODO: mark order/booking paid in your DB
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
        // TODO: mark user has a saved payment method
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

// ---------- Customers ----------
/**
 * Create or fetch a Customer. If email is provided, reuse existing when possible.
 * Returns: { customerId }
 */
app.post("/create-customer", async (req, res) => {
  try {
    const { email, name, metadata } = req.body || {};

    let customerId;
    if (email) {
      const list = await stripe.customers.list({ email, limit: 1 });
      if (list.data.length) customerId = list.data[0].id;
    }

    if (!customerId) {
      const customer = await stripe.customers.create({ email, name, metadata });
      customerId = customer.id;
    }

    res.json({ customerId });
  } catch (err) {
    console.error("❌ create-customer:", err);
    res.status(400).json({ error: err.message });
  }
});

// ---------- Ephemeral Key (for PaymentSheet / CustomerSheet) ----------
/**
 * Create an Ephemeral Key for the given customer.
 * You *must* pass the Stripe API version used by the mobile SDK.
 * Request headers: { "Stripe-Version": "<sdk api version>" }
 * Body: { customerId: "cus_..." }
 */
app.post("/ephemeral-key", async (req, res) => {
  try {
    const { customerId } = req.body || {};
    const stripeVersion =
      req.headers["stripe-version"] || req.headers["Stripe-Version"];

    if (!customerId) throw new Error("customerId is required");
    if (!stripeVersion)
      throw new Error(
        'Stripe-Version header is required (use the mobile SDK’s API version)'
      );

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

// ---------- SetupIntent (save a card for later) ----------
/**
 * Create a SetupIntent tied to a Customer to collect & save a card.
 * Returns: { clientSecret }
 */
app.post("/create-setup-intent", async (req, res) => {
  try {
    const { customerId, usage } = req.body || {};
    if (!customerId) throw new Error("customerId is required");

    const si = await stripe.setupIntents.create({
      customer: customerId,
      usage: usage || "off_session", // or 'on_session' based on your flow
      payment_method_types: ["card"],
    });

    res.json({ clientSecret: si.client_secret });
  } catch (err) {
    console.error("❌ create-setup-intent:", err);
    res.status(400).json({ error: err.message });
  }
});

// ---------- PaymentIntent (charge now) ----------
/**
 * Create a PaymentIntent (e.g., for booking charges).
 * Request: { amount: 1099, currency: "usd", customerId?: "cus_..." }
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
      metadata: req.body?.metadata || {}, // link to booking/ride IDs here
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





