const assert = require("assert");
const sinon = require("sinon");
const proxyquire = require("proxyquire");
const crypto = require("crypto");
const test = require("firebase-functions-test")();
const mocha = require("mocha");

// Create Firestore stub
const firestoreStub = {
  collection: sinon.stub(),
  batch: () => ({
    update: sinon.stub(),
    commit: sinon.stub().resolves(),
  }),
};

// Add get method to collection stub
firestoreStub.collection.returns({
  get: () => Promise.resolve({
    forEach: () => {},
    docs: [],
  }),
  where: sinon.stub(),
});

// Create admin stub
const authStub = {
  getUser: sinon.stub(),
};

const adminStub = {
  "initializeApp": () => {},
  "firestore": () => firestoreStub,
  "auth": () => authStub,
  "@global": true,
};

mocha.describe("Phone Number Functions", () => {
  let functionsMock;

  mocha.before(() => {
    // Load the functions with mocked dependencies
    functionsMock = proxyquire("../index", {
      "firebase-admin": adminStub,
    });
  });

  mocha.after(() => {
    test.cleanup();
  });

  mocha.describe("findUsersByPhoneNumbers", () => {
    mocha.it("should require authentication", async () => {
      try {
        await functionsMock.findUsersByPhoneNumbers.run({
          data: {hashedPhoneNumbers: []},
          auth: null,
        });
        assert.fail("Should have thrown an error");
      } catch (error) {
        assert.equal(error.code, "unauthenticated");
      }
    });

    mocha.it("should validate input", async () => {
      const auth = {uid: "test-user"};

      try {
        await functionsMock.findUsersByPhoneNumbers.run({data: {}, auth});
        assert.fail("Should have thrown an error");
      } catch (error) {
        assert.equal(error.code, "invalid-argument");
      }

      try {
        await functionsMock.findUsersByPhoneNumbers.run({
          data: {hashedPhoneNumbers: "not-an-array"},
          auth,
        });
        assert.fail("Should have thrown an error");
      } catch (error) {
        assert.equal(error.code, "invalid-argument");
      }
    });

    mocha.it("should return matching users", async () => {
      const auth = {uid: "test-user"};

      const mockUsers = [
        {
          id: "user1",
          firstName: "Test",
          lastName: "User",
          hashedPhoneNumber: "hash1",
        },
        {
          id: "user2",
          firstName: "Another",
          lastName: "User",
          hashedPhoneNumber: "hash2",
        },
      ];

      // Set up Firestore stub behavior
      const whereStub = sinon.stub().returns({
        get: () => Promise.resolve({
          empty: false,
          forEach: (callback) => mockUsers.forEach((user) => callback({
            id: user.id,
            data: () => user,
          })),
          docs: mockUsers.map((user) => ({
            id: user.id,
            data: () => user,
          })),
        }),
      });

      firestoreStub.collection.returns({
        where: whereStub,
        get: () => Promise.resolve({
          forEach: (callback) => mockUsers.forEach((doc) => callback({
            id: doc.id,
            data: () => doc,
          })),
          docs: mockUsers.map((user) => ({
            id: user.id,
            data: () => user,
          })),
        }),
      });

      const result = await functionsMock.findUsersByPhoneNumbers.run({
        data: {hashedPhoneNumbers: ["hash1", "hash2"]},
        auth,
      });

      assert.equal(result.users.length, 2);
      assert.equal(result.users[0].id, "user1");
      assert.equal(result.users[1].id, "user2");
      assert(firestoreStub.collection.calledWith("users"));
      assert(whereStub.calledWith(
          "hashedPhoneNumber",
          "in",
          ["hash1", "hash2"],
      ));
    });
  });

  mocha.describe("checkUserExists", () => {
    mocha.it("should validate input", async () => {
      try {
        await functionsMock.checkUserExists.run({data: {}, auth: null});
        assert.fail("Should have thrown an error");
      } catch (error) {
        assert.equal(error.code, "invalid-argument");
      }
    });

    mocha.it("should return true for existing user", async () => {
      // Set up Firestore stub behavior for existing user
      const whereStub = sinon.stub().returns({
        limit: sinon.stub().returns({
          get: () => Promise.resolve({
            empty: false,
          }),
        }),
      });

      firestoreStub.collection.returns({
        where: whereStub,
      });

      const result = await functionsMock.checkUserExists.run({
        data: {hashedPhoneNumber: "existing-hash"},
        auth: null,
      });
      assert.equal(result.userExists, true);
      assert(firestoreStub.collection.calledWith("users"));
      assert(whereStub.calledWith(
          "hashedPhoneNumber",
          "==",
          "existing-hash",
      ));
    });

    mocha.it("should return false for non-existent user", async () => {
      // Set up Firestore stub behavior for non-existent user
      const whereStub = sinon.stub().returns({
        limit: sinon.stub().returns({
          get: () => Promise.resolve({
            empty: true,
          }),
        }),
      });

      firestoreStub.collection.returns({
        where: whereStub,
      });

      const result = await functionsMock.checkUserExists.run({
        data: {hashedPhoneNumber: "non-existent-hash"},
        auth: null,
      });
      assert.equal(result.userExists, false);
      assert(firestoreStub.collection.calledWith("users"));
      assert(whereStub.calledWith(
          "hashedPhoneNumber",
          "==",
          "non-existent-hash",
      ));
    });
  });

  mocha.describe("ensureUserDocument", () => {
    mocha.it("should require authentication", async () => {
      try {
        await functionsMock.ensureUserDocument.run({data: {}, auth: null});
        assert.fail("Should have thrown an error");
      } catch (error) {
        assert.equal(error.code, "unauthenticated");
      }
    });

    mocha.it("should return existing when UID doc exists", async () => {
      const auth = {uid: "test-user"};

      const userRef = {
        get: sinon.stub().resolves({exists: true}),
      };

      firestoreStub.collection.returns({
        doc: sinon.stub().returns(userRef),
      });

      authStub.getUser.resetHistory();

      const result = await functionsMock.ensureUserDocument.run({
        data: {},
        auth,
      });

      assert.equal(result.ensured, true);
      assert.equal(result.action, "existing");
      assert.equal(result.uid, "test-user");
      assert(authStub.getUser.notCalled);
    });

    mocha.it("should migrate legacy doc when UID doc is missing", async () => {
      const auth = {uid: "test-user"};

      const phoneNumber = "+15551234567";
      const expectedHash = crypto
          .createHash("sha256")
          .update(phoneNumber)
          .digest("hex");

      authStub.getUser.resolves({phoneNumber});

      const userRef = {
        get: sinon.stub().resolves({exists: false}),
        set: sinon.stub().resolves(),
      };

      const legacyRef = {
        update: sinon.stub().resolves(),
      };

      const legacyDoc = {
        id: "legacy-user",
        ref: legacyRef,
        data: () => ({
          firstName: "Test",
          lastName: "User",
          username: "testuser",
          phoneNumber: "(555) 123-4567",
          hashedPhoneNumber: expectedHash,
        }),
      };

      const whereStub = sinon.stub().returns({
        limit: sinon.stub().returns({
          get: sinon.stub().resolves({
            empty: false,
            docs: [legacyDoc],
          }),
        }),
      });

      firestoreStub.collection.returns({
        doc: sinon.stub().returns(userRef),
        where: whereStub,
      });

      const result = await functionsMock.ensureUserDocument.run({
        data: {},
        auth,
      });

      assert.equal(result.ensured, true);
      assert.equal(result.action, "migrated");
      assert.equal(result.uid, "test-user");
      assert.equal(result.legacyUserId, "legacy-user");

      assert(userRef.set.calledOnce);
      const setArg = userRef.set.firstCall.args[0];
      assert.equal(setArg.id, "test-user");
      assert.equal(setArg.phoneNumber, phoneNumber);
      assert.equal(setArg.hashedPhoneNumber, expectedHash);

      assert(legacyRef.update.calledOnce);
      assert.deepEqual(legacyRef.update.firstCall.args[0], {
        hashedPhoneNumber: null,
        migratedToUserId: "test-user",
      });
    });

    mocha.it("should return not-found when no legacy doc exists", async () => {
      const auth = {uid: "test-user"};

      authStub.getUser.resolves({phoneNumber: "+15551234567"});

      const userRef = {
        get: sinon.stub().resolves({exists: false}),
        set: sinon.stub().resolves(),
      };

      const whereStub = sinon.stub().returns({
        limit: sinon.stub().returns({
          get: sinon.stub().resolves({
            empty: true,
            docs: [],
          }),
        }),
      });

      firestoreStub.collection.returns({
        doc: sinon.stub().returns(userRef),
        where: whereStub,
      });

      try {
        await functionsMock.ensureUserDocument.run({data: {}, auth});
        assert.fail("Should have thrown an error");
      } catch (error) {
        assert.equal(error.code, "not-found");
      }
    });
  });

  mocha.describe("migratePhoneNumbers", () => {
    mocha.it("should require admin authentication", async () => {
      const wrapped = test.wrap(functionsMock.migratePhoneNumbers);

      try {
        await wrapped({}, {auth: {token: {admin: false}}});
        assert.fail("Should have thrown an error");
      } catch (error) {
        assert.equal(error.code, "permission-denied");
      }
    });

    mocha.it("should migrate users without hashed numbers", async () => {
      const wrapped = test.wrap(functionsMock.migratePhoneNumbers);
      const auth = {token: {admin: true}};

      const mockUsers = [
        {
          id: "user1",
          phoneNumber: "+15551234567",
        },
        {
          id: "user2",
          phoneNumber: "+15559876543",
          hashedPhoneNumber: "already-hashed",
        },
      ];

      // Set up Firestore stub behavior
      const batchStub = {
        update: sinon.stub(),
        commit: sinon.stub().resolves(),
      };

      firestoreStub.batch = sinon.stub().returns(batchStub);
      firestoreStub.collection.returns({
        get: () => Promise.resolve({
          forEach: (callback) => mockUsers.forEach((user, index) => {
            callback({
              id: `user${index + 1}`,
              ref: {id: `user${index + 1}`},
              data: () => user,
            });
          }),
        }),
      });

      const result = await wrapped({}, {auth});

      assert.equal(result.migratedCount, 1);
      assert(batchStub.update.calledOnce);
      assert(batchStub.commit.calledOnce);
      assert(firestoreStub.collection.calledWith("users"));
    });
  });
});
