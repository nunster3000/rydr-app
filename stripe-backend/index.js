const express = require("express");
const Stripe = require("stripe");
const dotenv = require("dotenv");

dotenv.config();

const app = express();
const stripe = Stripe(process.env.STRIPE_SECRET_KEY);

app.use(express.json());

// ✅ Health check route
app.get("/", (req, res) => {
  res.send("Rydr Stripe backend is running");
});

// ✅ Create SetupIntent using existing customerId from frontend
app.post("/create-setup-intent", async (req, res) => {
  const { customerId } = req.body;

  if (!customerId) {
    return res.status(400).json({ error: "Missing customerId" });
  }

  try {
    const setupIntent = await stripe.setupIntents.create({
      customer: customerId,
    });

    res.json({ clientSecret: setupIntent.client_secret });
  } catch (error) {
    console.error("Error creating SetupIntent:", error);
    res.status(500).json({ error: error.message });
  }
});

// ✅ Create a new Stripe customer and return the ID
app.post("/create-customer", async (req, res) => {
  const { email, uid } = req.body;

  if (!email || !uid) {
    return res.status(400).json({ error: "Missing email or uid" });
  }

  try {
    const customer = await stripe.customers.create({
      email,
      metadata: { firebaseUID: uid },
    });

    res.json({ customerId: customer.id });
  } catch (error) {
    console.error("Error creating customer:", error);
    res.status(400).json({ error: error.message });
  }
});

const PORT = process.env.PORT || 10000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

