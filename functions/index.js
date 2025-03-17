const functions = require("firebase-functions");
const admin = require("firebase-admin");
// const {DocumentSnapshot} = require("firebase-admin/firestore");

admin.initializeApp();

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
  const {hashedPhoneNumbers} = data;
  if (!hashedPhoneNumbers || !Array.isArray(hashedPhoneNumbers)) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "The function must be called with an array of hashed phone numbers.",
    );
  }

  console.log("\n🔒 Input hashed phone numbers:");
  hashedPhoneNumbers.forEach((hash, index) => {
    console.log(`   ${index + 1}. ${hash}`);
  });

  try {
    // 3. Query Firestore for all matching users
    console.log("\n📚 Querying Firestore...");
    const usersRef = admin.firestore().collection("users");

    // First, let's log all users and their hashed numbers for debugging
    const allUsers = await usersRef.get();
    console.log("\n👥 All users in database:");
    allUsers.forEach((doc) => {
      const userData = doc.data();
      console.log(`   User: ${userData.firstName} ${userData.lastName}`);
      console.log(`   Hashed Phone: '${userData.hashedPhoneNumber}'`);
      console.log(`   ID: ${doc.id}\n`);
    });

    // Now perform the actual query
    console.log("\n🔎 Performing hashed phone number query...");
    const snapshot = await usersRef
        .where("hashedPhoneNumber", "in", hashedPhoneNumbers)
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
      console.log(`   - Hashed Phone: '${userData.hashedPhoneNumber}'`);
      console.log(`   - ID: ${doc.id}`);

      // Only return necessary user data for privacy
      matchedUsers.push({
        id: doc.id,
        firstName: userData.firstName,
        lastName: userData.lastName,
        username: userData.username,
        phoneNumber: userData.phoneNumber,
        hashedPhoneNumber: userData.hashedPhoneNumber,
        profileImageUrl: userData.profileImageUrl,
        profileThumbnailUrl: userData.profileThumbnailUrl,
      });
    });

    console.log(`\n📊 Results Summary:`);
    console.log(`   Input hashes: ${hashedPhoneNumbers.length}`);
    console.log(`   Matches found: ${matchedUsers.length}`);

    return {users: matchedUsers};
  } catch (error) {
    console.error("Error in findUsersByPhoneNumbers:", error);
    throw new functions.https.HttpsError("internal", error.message);
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
  const {hashedPhoneNumber} = data;
  if (!hashedPhoneNumber) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "The function must be called with a hashed phone number.",
    );
  }

  try {
    const snapshot = await admin.firestore()
        .collection("users")
        .where("hashedPhoneNumber", "==", hashedPhoneNumber)
        .limit(1)
        .get();

    return {userExists: !snapshot.empty};
  } catch (error) {
    console.error("Error checking user existence:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// Cloud Function: migratePhoneNumbers
exports.migratePhoneNumbers = functions.https.onCall(async (data, context) => {
  // Only allow admin users to run this migration
  if (!context.auth || !context.auth.token || !context.auth.token.admin) {
    throw new functions.https.HttpsError(
        "permission-denied",
        "Only admin users can run this migration.",
    );
  }

  try {
    const batch = admin.firestore().batch();
    const usersRef = admin.firestore().collection("users");
    const snapshot = await usersRef.get();
    let updatedCount = 0;

    console.log("Starting phone number migration...");

    snapshot.forEach((doc) => {
      const userData = doc.data();
      if (userData.phoneNumber && !userData.hashedPhoneNumber) {
        // Hash the phone number using the same algorithm as the client
        const hashedPhoneNumber = require("crypto")
            .createHash("sha256")
            .update(userData.phoneNumber)
            .digest("hex");

        batch.update(doc.ref, {hashedPhoneNumber});
        updatedCount++;
      }
    });

    if (updatedCount > 0) {
      await batch.commit();
      console.log(`Successfully migrated ${updatedCount} users`);
    } else {
      console.log("No users needed migration");
    }

    return {migratedCount: updatedCount};
  } catch (error) {
    console.error("Error during migration:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});
