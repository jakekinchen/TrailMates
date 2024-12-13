const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Normalizes a phone number by removing all non-digit characters.
 * @param {string} phoneNumber - The phone number to normalize
 * @return {string} The normalized phone number containing only digits
 */
function normalizePhoneNumber(phoneNumber) {
  return phoneNumber.replace(/\D/g, "");
}

// Cloud Function: getUserByPhoneNumber
exports.getUserByPhoneNumber = functions.https.onCall(async (data, context) => {
  console.log("Printing data:", data.data);
  // Firebase automatically wraps parameters in a data object
  const {phoneNumber, region = "US"} = data.data;
  console.log(`🔎 Searching user: ${phoneNumber}, Region: ${region}`);

  if (!phoneNumber || typeof phoneNumber !== "string") {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Invalid phone number",
    );
  }

  const normalized = normalizePhoneNumber(phoneNumber);
  if (!normalized) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Phone number normalization failed",
    );
  }

  console.log(`🔍 Searching for phone number: ${normalized}`);

  const [userDoc] = (await admin.firestore()
      .collection("users")
      .where("phoneNumber", "==", normalized)
      .limit(1)
      .get()).docs;

  return userDoc ?
      {userExists: true, userId: userDoc.id} :
      {userExists: false};
});
