const {onValueWritten} = require("firebase-functions/v2/database");
const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");
const Twilio = require("twilio");

admin.initializeApp();

// Define secrets to be securely managed by Firebase Secret Manager
const twilioSid = defineSecret("TWILIO_ACCOUNT_SID");
const twilioAuthToken = defineSecret("TWILIO_AUTH_TOKEN");
const twilioFrom = defineSecret("TWILIO_FROM_NUMBER");
const twilioTo = defineSecret("TWILIO_TO_NUMBER");

/**
 * Triggers when an alert status is written to the database.
 * Sends a WhatsApp message via Twilio with available vital signs.
 */
exports.sendAlert = onValueWritten({
  ref: "/test/alert",
  secrets: [twilioSid, twilioAuthToken, twilioFrom, twilioTo],
}, async (event) => {
  const currentVal = event.data.after.val();

  // (3) Ensure the function checks change.after.val() === true properly
  // Also (8) ensures duplicate `true` writes won't be an issue because we reset to false below.
  if (currentVal !== true) {
    console.log(`Alert ignored or resolved. Current /test/alert value is: ${currentVal}`);
    return;
  }

  console.log("🚨 Emergency Triggered! Processing alert...");

  try {
    // (4) Fetch the latest inserted vitals from /emergency/active
    const vitalsSnap = await admin.database().ref("/emergency/active").once("value");
    const vitals = vitalsSnap.val() || {};

    const hr = vitals.hr || "N/A";
    const spo2 = vitals.spo2 || "N/A";
    const temp = vitals.temp || "N/A";

    console.log(`Vitals fetched -> HR: ${hr}, SpO2: ${spo2}, Temp: ${temp}`);

    const client = new Twilio(twilioSid.value(), twilioAuthToken.value());

    const body = `🚨 TRINETRA GUARD: EMERGENCY ALERT 🚨\n\n` +
                 `Vitals Detected:\n` +
                 `- Heart Rate: ${hr} bpm\n` +
                 `- SpO2: ${spo2}%\n` +
                 `- Temp: ${temp}°C\n\n` +
                 `Please check the app immediately!`;

    // (9) Log Twilio execution
    console.log(`Sending WhatsApp from: whatsapp:${twilioFrom.value()} to whatsapp:${twilioTo.value()}`);
    
    const message = await client.messages.create({
      from: `whatsapp:${twilioFrom.value()}`,
      to: `whatsapp:${twilioTo.value()}`,
      body: body,
    });

    console.log(`✅ Alert sent successfully. Message SID: ${message.sid}`);

    // (8) Reset the alert path to false to cleanly allow the exact false -> true toggle next time
    await event.data.after.ref.set(false);
    console.log("🔄 Reset /test/alert flag to false.");
    
  } catch (error) {
    // (9) Catch and log any Twilio or Firebase errors clearly
    console.error("❌ Failed to send WhatsApp alert:", error);
  }
});

