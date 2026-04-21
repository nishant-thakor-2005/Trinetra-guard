const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const Twilio = require("twilio");

// Twilio config
const accountSid = functions.config().twilio.sid;
const authToken = functions.config().twilio.token;

const client = new Twilio(accountSid, authToken);

// Firebase trigger
exports.sendAlert = functions.database
    .ref("/test/alert")
    .onWrite(async (change, context) => {
      const value = change.after.val();

      if (value === true) {
        await client.messages.create({
          from: "whatsapp:+14155238886",
          to: "whatsapp:+918955406512", // apna number
          body: "🚨 Emergency Alert from Trinetra!",
        });
      }

      return null;
    });
