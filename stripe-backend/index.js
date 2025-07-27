const express = require("express");
const Stripe = require("stripe");
const dotenv = require("dotenv");

dotenv.config();

const app = express();
const stripe = Stripe(process.env.STRIPE_SECRET_KEY);

app.use(express.json()); // ✅ Make sure JSON body is parsed

// Root Test Route
app.get("/", (req, res) => {
  res.send("✅ Rydr Stripe backend is running");
});

// 🔶 1. Create Customer (called from Swift when Firestore has no stripeCustomerId)
app.post("/create-customer", async (req, res) => {
  const { email, uid } = req.body;
  console.log("📩 Creating customer for:", email, uid);

  try {
    const customer = await stripe.customers.create({
      email,
      metadata: { firebaseUID: uid },
    });

    console.log("✅ Stripe customer created:", customer.id);
    res.send({ customerId: customer.id });
  } catch (err) {
    console.error("❌ Stripe customer creation failed:", err);
    res.status(400).send({ error: err.message });
  }
});

// 🔷 2. Create SetupIntent (called from Swift when ready to present PaymentSheet)
app.post("/create-setup-intent", async (req, res) => {
  const { customerId } = req.body;
  console.log("🎟️ Creating SetupIntent for:", customerId);

  try {
    const setupIntent = await stripe.setupIntents.create({
      customer: customerId,
    });

    console.log("✅ SetupIntent created:", setupIntent.id);
    res.send({ clientSecret: setupIntent.client_secret });
  } catch (err) {
    console.error("❌ SetupIntent creation failed:", err);
    res.status(400).send({ error: err.message });
  }
});

const PORT = process.env.PORT || 10000;
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});



