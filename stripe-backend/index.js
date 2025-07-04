const express = require("express");
const Stripe = require("stripe");
const dotenv = require("dotenv");

dotenv.config();

const app = express();
const stripe = Stripe(process.env.STRIPE_SECRET_KEY);

app.use(express.json());

app.get("/", (req, res) => {
  res.send("Rydr Stripe backend is running 🚗");
});

app.post("/create-setup-intent", async (req, res) => {
  try {
    const customer = await stripe.customers.create();
    const setupIntent = await stripe.setupIntents.create({
      customer: customer.id,
    });

    res.send({
      clientSecret: setupIntent.client_secret,
    });
  } catch (error) {
    console.error("Error creating SetupIntent:", error);
    res.status(500).send({ error: error.message });
  }
});

const PORT = process.env.PORT || 10000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
