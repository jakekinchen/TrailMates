const functions = require("firebase-functions");
const admin = require("firebase-admin");
// const {DocumentSnapshot} = require("firebase-admin/firestore");

admin.initializeApp();

async function updateFriendArrays(userId, friendId, shouldAdd) {
  const userRef = admin.firestore().collection("users").doc(userId);
  const friendRef = admin.firestore().collection("users").doc(friendId);

  await admin.firestore().runTransaction(async (transaction) => {
    const [userDoc, friendDoc] = await Promise.all([
      transaction.get(userRef),
      transaction.get(friendRef),
    ]);

    if (!userDoc.exists || !friendDoc.exists) {
      throw new Error("User document not found.");
    }

    const userFriends = Array.isArray(userDoc.data().friends) ?
      userDoc.data().friends : [];
    const friendFriends = Array.isArray(friendDoc.data().friends) ?
      friendDoc.data().friends : [];

    const userSet = new Set(userFriends);
    const friendSet = new Set(friendFriends);

    if (shouldAdd) {
      userSet.add(friendId);
      friendSet.add(userId);
    } else {
      userSet.delete(friendId);
      friendSet.delete(userId);
    }

    transaction.update(userRef, {friends: Array.from(userSet)});
    transaction.update(friendRef, {friends: Array.from(friendSet)});
  });
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
  const {hashedPhoneNumbers} = data;
  if (!hashedPhoneNumbers || !Array.isArray(hashedPhoneNumbers)) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "The function must be called with an array of hashed phone numbers.",
    );
  }

  if (hashedPhoneNumbers.length === 0) {
    return {users: []};
  }

  try {
    // 3. Query Firestore for all matching users in chunks (Firestore "in" limit = 10)
    const usersRef = admin.firestore().collection("users");
    const uniqueHashes = [...new Set(hashedPhoneNumbers)];
    const chunkSize = 10;
    const matchedUsers = [];
    const matchedUserIds = new Set();

    for (let i = 0; i < uniqueHashes.length; i += chunkSize) {
      const batch = uniqueHashes.slice(i, i + chunkSize);
      const snapshot = await usersRef
          .where("hashedPhoneNumber", "in", batch)
          .get();

      snapshot.forEach((doc) => {
        if (matchedUserIds.has(doc.id)) {
          return;
        }

        const userData = doc.data();
        matchedUserIds.add(doc.id);

        // Only return necessary user data for matching
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
    }

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
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "The function must be called while authenticated.",
    );
  }

  // 1. Validate input
  const {username, excludeUserId} = data || {};
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
        .get();

    // 3. Return true/false
    const usernameTaken = snapshot.docs.some((doc) => doc.id !== excludeUserId);
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

// Cloud Function: acceptFriendRequest
exports.acceptFriendRequest = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "The function must be called while authenticated.",
    );
  }

  const {requestId} = data || {};
  if (!requestId) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "requestId is required.",
    );
  }

  const userId = context.auth.uid;
  const requestRef = admin.database()
      .ref(`friend_requests/${userId}/${requestId}`);
  const snapshot = await requestRef.get();

  if (!snapshot.exists()) {
    throw new functions.https.HttpsError(
        "not-found",
        "Friend request not found.",
    );
  }

  const fromUserId = snapshot.child("fromUserId").val();
  if (!fromUserId || typeof fromUserId !== "string") {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Invalid friend request payload.",
    );
  }

  if (fromUserId === userId) {
    throw new functions.https.HttpsError(
        "failed-precondition",
        "Cannot friend yourself.",
    );
  }

  try {
    await updateFriendArrays(userId, fromUserId, true);

    const updates = {};
    updates[`friend_requests/${userId}/${requestId}`] = null;
    updates[`notifications/${userId}/${requestId}`] = null;
    await admin.database().ref().update(updates);

    return {success: true, friendId: fromUserId};
  } catch (error) {
    console.error("Error accepting friend request:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// Cloud Function: removeFriend
exports.removeFriend = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "The function must be called while authenticated.",
    );
  }

  const {friendId} = data || {};
  if (!friendId || typeof friendId !== "string") {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "friendId is required.",
    );
  }

  const userId = context.auth.uid;
  if (friendId === userId) {
    throw new functions.https.HttpsError(
        "failed-precondition",
        "Cannot remove yourself as a friend.",
    );
  }

  try {
    await updateFriendArrays(userId, friendId, false);
    return {success: true};
  } catch (error) {
    console.error("Error removing friend:", error);
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

// Firestore trigger: sync friends list to RTDB for privacy checks
exports.syncFriendsToRTDB = functions.firestore
    .document("users/{userId}")
    .onWrite(async (change, context) => {
      const userId = context.params.userId;
      const beforeData = change.before.exists ? change.before.data() : null;
      const afterData = change.after.exists ? change.after.data() : null;

      const beforeFriendsList =
          beforeData && Array.isArray(beforeData.friends) ? beforeData.friends : [];
      const afterFriendsList =
          afterData && Array.isArray(afterData.friends) ? afterData.friends : [];

      const beforeFriends = new Set(beforeFriendsList);
      const afterFriends = new Set(afterFriendsList);

      const updates = {};

      for (const friendId of afterFriends) {
        if (!beforeFriends.has(friendId)) {
          updates[`friends/${userId}/${friendId}`] = true;
        }
      }

      for (const friendId of beforeFriends) {
        if (!afterFriends.has(friendId)) {
          updates[`friends/${userId}/${friendId}`] = null;
        }
      }

      if (Object.keys(updates).length === 0) {
        return null;
      }

      await admin.database().ref().update(updates);
      return null;
    });
