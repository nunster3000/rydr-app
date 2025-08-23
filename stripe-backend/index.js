// index.js
"use strict";

const express = require("express");
const cors = require("cors");
const dotenv = require("dotenv");
const Stripe = require("stripe");

dotenv.config();

if (!process.env.STRIPE_SECRET_KEY) {
  console.error("❌ Missing STRIPE_SECRET_KEY");
  process.exit(1);
}

const app = express();
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY, { apiVersion: "2024-06-20" });

// --- CORS (optional; iOS native calls don't need it, web would) ---
const allowed = (process.env.CORS_ORIGINS || "")
  .split(",").map(s => s.trim()).filter(Boolean);
app.use(cors({
  origin: (origin, cb) =>
    !origin || allowed.length === 0 || allowed.includes(origin)
      ? cb(null, true)
      : cb(new Error("Not allowed by CORS")),
}));

// --- Health ---
app.get("/", (_req, res) => res.send("✅ Rydr Stripe backend is running"));

// --- Webhook (RAW body; mount BEFORE json parser) ---
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
        console.log("💳 setup_intent.succeeded:", event.data.object.id);
        break;
      case "payment_intent.succeeded":
        console.log("💰 payment_intent.succeeded:", event.data.object.id);
        break;
      case "payment_intent.payment_failed":
        console.log("⚠️ payment_intent.payment_failed:", event.data.object.id);
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

// --- JSON parser for all OTHER routes ---
app.use(express.json());

// --- Create-or-get Customer (idempotent) ---
// Body: { email?: string, name?: string, uid?: string } -> { customerId }
app.post("/create-customer", async (req, res) => {
  try {
    const { email, name, uid } = req.body || {};

    // 1) Prefer lookup by metadata.firebase_uid (if provided)
    if (uid) {
      const byUid = await stripe.customers.search({
        query: `metadata['firebase_uid']:'${uid}'`,
      });
      if (byUid.data.length) {
        return res.json({ customerId: byUid.data[0].id });
      }
    }

    // 2) Fallback by email (if present)
    if (email) {
      const byEmail = await stripe.customers.search({ query: `email:'${email}'` });
      if (byEmail.data.length) {
        // Backfill UID so future lookups use metadata
        if (uid && byEmail.data[0].metadata?.firebase_uid !== uid) {
          await stripe.customers.update(byEmail.data[0].id, {
            metadata: { ...byEmail.data[0].metadata, firebase_uid: uid },
          });
        }
        return res.json({ customerId: byEmail.data[0].id });
      }
    }

    // 3) Create new customer (email optional)
    const customer = await stripe.customers.create({
      email: email || undefined,
      name: name || undefined,
      metadata: uid ? { firebase_uid: uid } : undefined,
    });
    return res.json({ customerId: customer.id });
  } catch (e) {
    console.error("❌ create-customer:", e);
    res.status(500).json({ error: "create_customer_failed" });
  }
});

// --- Ephemeral Key ---
// Headers: "Stripe-Version" required; Body: { customerId }
app.post("/ephemeral-key", async (req, res) => {
  try {
    const { customerId } = req.body || {};
    const apiVer = req.headers["stripe-version"];
    if (!customerId) return res.status(400).json({ error: "customerId_required" });
    if (!apiVer)    return res.status(400).json({ error: "stripe_version_required" });

    const key = await stripe.ephemeralKeys.create(
      { customer: customerId },
      { apiVersion: String(apiVer) }
    );
    res.json(key);
  } catch (e) {
    console.error("❌ ephemeral-key:", e);
    res.status(500).json({ error: "ephemeral_key_failed" });
  }
});

// --- SetupIntent (save a card) ---
// Body: { customerId } -> { clientSecret }
app.post("/create-setup-intent", async (req, res) => {
  try {
    const { customerId } = req.body || {};
    if (!customerId) return res.status(400).json({ error: "customerId_required" });

    const si = await stripe.setupIntents.create({
      customer: customerId,
      payment_method_types: ["card"],
      usage: "off_session",
    });
    res.json({ clientSecret: si.client_secret });
  } catch (e) {
    console.error("❌ create-setup-intent:", e);
    res.status(500).json({ error: "setup_intent_failed" });
  }
});

// --- PaymentIntent (charge) ---
// Body: { amount: <int cents>, currency: "usd", customerId?: "cus_..." }
app.post("/create-payment-intent", async (req, res) => {
  try {
    const { amount, currency = "usd", customerId } = req.body || {};
    if (!Number.isInteger(amount) || amount <= 0) {
      return res.status(400).json({ error: "invalid_amount" });
    }
    const pi = await stripe.paymentIntents.create({
      amount,
      currency,
      customer: customerId,
      automatic_payment_methods: { enabled: true },
    });
    res.json({ clientSecret: pi.client_secret, paymentIntentId: pi.id });
  } catch (e) {
    console.error("❌ create-payment-intent:", e);
    res.status(500).json({ error: "payment_intent_failed" });
  }
});

// --- List saved card PaymentMethods (for wallet tiles) ---
// Body: { customerId } -> { paymentMethods: [{id,brand,last4,expMonth,expYear,isDefault}] }
app.post("/list-payment-methods", async (req, res) => {
  try {
    const { customerId } = req.body || {};
    if (!customerId) return res.status(400).json({ error: "customerId_required" });

    const [pms, customer] = await Promise.all([
      stripe.paymentMethods.list({ customer: customerId, type: "card" }),
      stripe.customers.retrieve(customerId),
    ]);

    const defaultPm = customer?.invoice_settings?.default_payment_method || null;

    res.json({
      paymentMethods: pms.data.map(pm => ({
        id: pm.id,
        brand: pm.card.brand,
        last4: pm.card.last4,
        expMonth: pm.card.exp_month,
        expYear: pm.card.exp_year,
        isDefault: pm.id === defaultPm,
      })),
    });
  } catch (e) {
    console.error("❌ list-payment-methods:", e);
    res.status(500).json({ error: "list_failed" });
  }
});

// --- Set default card ---
// Body: { customerId, paymentMethodId } -> { ok: true }
app.post("/set-default-payment-method", async (req, res) => {
  try {
    const { customerId, paymentMethodId } = req.body || {};
    if (!customerId || !paymentMethodId)
      return res.status(400).json({ error: "required_params" });

    await stripe.customers.update(customerId, {
      invoice_settings: { default_payment_method: paymentMethodId },
    });
    res.json({ ok: true });
  } catch (e) {
    console.error("❌ set-default-payment-method:", e);
    res.status(500).json({ error: "update_failed" });
  }
});

// --- Detach a card ---
// Body: { paymentMethodId } -> { ok: true }
app.post("/detach-payment-method", async (req, res) => {
  try {
    const { paymentMethodId } = req.body || {};
    if (!paymentMethodId)
      return res.status(400).json({ error: "paymentMethodId_required" });

    await stripe.paymentMethods.detach(paymentMethodId);
    res.json({ ok: true });
  } catch (e) {
    console.error("❌ detach-payment-method:", e);
    res.status(500).json({ error: "detach_failed" });
  }
});

// --- Listen ---
const PORT = process.env.PORT || 10000;
app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));







