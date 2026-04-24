const {onValueWritten} = require("firebase-functions/v2/database");
const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");
const twilio = require("twilio");

admin.initializeApp();

// Secrets managed by Firebase Secret Manager — never in code
const twilioSid = defineSecret("TWILIO_ACCOUNT_SID");
const twilioToken = defineSecret("TWILIO_AUTH_TOKEN");
const twilioFrom = defineSecret("TWILIO_FROM_NUMBER");
const twilioTo = defineSecret("TWILIO_TO_NUMBER");

/**
 * Cloud Function (v2) to handle emergency alerts.
 * Triggers on /test/alert write, sends WhatsApp via Twilio,
 * and resets the flag to false.
 */
exports.sendAlert = onValueWritten(
    {
      ref: "/test/alert",
      instance: "trinetra-guard-default-rtdb",
      secrets: [twilioSid, twilioToken, twilioFrom, twilioTo],
    },
    async (event) => {
      const newVal = event.data.after.val();

      // Only proceed if the new value is true
      if (newVal !== true) {
        console.log(`Alert value is ${newVal}, skipping.`);
        return;
      }

      console.log("Emergency Triggered! Processing alert...");

      const client = twilio(
          twilioSid.value(),
          twilioToken.value(),
      );
      const time = new Date().toLocaleString();

      try {
        const message = await client.messages.create({
          from: `whatsapp:${twilioFrom.value()}`,
          to: `whatsapp:${twilioTo.value()}`,
          body: "TRINETRA GUARD ALERT — Emergency detected. " +
                `Fall or critical movement detected. Timestamp: ${time}`,
        });

        console.log(`[CF] WhatsApp sent. SID: ${message.sid}`);

        // Reset the alert flag to false
        await event.data.after.ref.set(false);
        console.log("[CF] Reset /test/alert to false.");
      } catch (e) {
        console.error(`[CF] Error: ${e.message || e}`);
      }
    },
);
