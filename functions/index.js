const functions = require("firebase-functions");
const admin = require("firebase-admin");
// const {DocumentSnapshot} = require("firebase-admin/firestore");

admin.initializeApp();

/**
 * Normalizes a phone number by removing all non-digit characters.
 * @param {string} phoneNumber - The phone number to normalize
 * @return {string} The normalized phone number containing only digits
 */
function normalizePhoneNumber(phoneNumber) {
  return phoneNumber.replace(/\D/g, "");
}

// Cloud Function: findUsersByPhoneNumbers
exports.findUsersByPhoneNumbers =
functions.https.onCall(async (data, context) => {
  // 1. Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "The function must be called while authenticated.",
    );
  }
  console.log(`🔐 Authenticated user: ${context.auth.uid}`);

  // 2. Validate input
  const {phoneNumbers} = data;
  if (!phoneNumbers || !Array.isArray(phoneNumbers)) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "The function must be called with an array of phone numbers.",
    );
  }

  console.log("\n📱 Input phone numbers (already in E.164 format):");
  phoneNumbers.forEach((number, index) => {
    console.log(`   ${index + 1}. ${number}`);
  });

  try {
    // 3. Query Firestore for all matching users
    console.log("\n📚 Querying Firestore...");
    const usersRef = admin.firestore().collection("users");

    // First, let's log all users and their phone numbers for debugging
    const allUsers = await usersRef.get();
    console.log("\n👥 All users in database:");
    allUsers.forEach((doc) => {
      const userData = doc.data();
      console.log(`   User: ${userData.firstName} ${userData.lastName}`);
      console.log(`   Phone: '${userData.phoneNumber}'`);
      console.log(`   ID: ${doc.id}\n`);
    });

    // Now perform the actual query
    console.log("\n🔎 Performing phone number query...");
    const snapshot = await usersRef
        .where("phoneNumber", "in", phoneNumbers)
        .get();

    // 4. Process and return results
    const matchedUsers = [];
    console.log("\n✅ Query results:");
    if (snapshot.empty) {
      console.log("   No matches found!");
    }

    snapshot.forEach((doc) => {
      const userData = doc.data();
      console.log(`   Match found:`);
      console.log(`   - Name: ${userData.firstName} ${userData.lastName}`);
      console.log(`   - Phone: '${userData.phoneNumber}'`);
      console.log(`   - ID: ${doc.id}`);

      // Only return necessary user data for privacy
      matchedUsers.push({
        id: doc.id,
        firstName: userData.firstName,
        lastName: userData.lastName,
        username: userData.username,
        phoneNumber: userData.phoneNumber,
        profileImageUrl: userData.profileImageUrl,
        profileThumbnailUrl: userData.profileThumbnailUrl,
      });
    });

    console.log(`\n📊 Results Summary:`);
    console.log(`   Input numbers: ${phoneNumbers.length}`);
    console.log(`   Matches found: ${matchedUsers.length}`);

    return {users: matchedUsers};
  } catch (error) {
    console.error("\n❌ Error finding users:", error);
    console.error("   Stack trace:", error.stack);
    throw new functions.https.HttpsError(
        "internal",
        "Error processing phone numbers",
    );
  }
});

// Cloud Function: checkUsernameTaken
exports.checkUsernameTaken = functions.https.onCall(async (data, context) => {
  // 1. Validate input
  const {username} = data.data || {};
  if (!username || typeof username !== "string") {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "A valid username string is required.",
    );
  }

  console.log(`🔎 Checking if username is taken: ${username}`);

  // 2. Query Firestore
  try {
    const snapshot = await admin
        .firestore()
        .collection("users")
        .where("username", "==", username)
        .limit(1)
        .get();

    // 3. Return true/false
    const usernameTaken = !snapshot.empty;
    console.log(`Username: '${username}' isTaken: ${usernameTaken}`);
    return {usernameTaken};
  } catch (error) {
    console.error("Error checking username:", error);
    throw new functions.https.HttpsError(
        "internal",
        "An error occurred while checking username.",
    );
  }
});

// Cloud Function: checkUserExists
exports.checkUserExists = functions.https.onCall(async (data, context) => {
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

  const [userDoc] = (
    await admin
        .firestore()
        .collection("users")
        .where("phoneNumber", "==", normalized)
        .limit(1)
        .get()
  ).docs;

  if (userDoc) {
    console.log(`User found: ID=${userDoc.id}`);
    return {userExists: true};
  } else {
    console.log(`No user found for phone number: ${normalized}`);
    return {userExists: false};
  }
});
