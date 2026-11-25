const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const { test, before, after, beforeEach } = require("node:test");
const fs = require("node:fs");

let testEnv;
const PROJECT_ID = process.env.GCP_PROJECT || "demo-no-project";
const ALICE_UID = "kiran_sharma_123";
const BOB_UID = "aarav_sharma_456";

const [emulatorHost, emulatorPortStr] = (
  process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8085"
).split(":");
const emulatorPort = parseInt(emulatorPortStr, 10);

before(async () => {
  const rules = fs.readFileSync("./firestore.rules", "utf8");
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules,
      host: emulatorHost,
      port: emulatorPort,
    },
  });
});

after(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

beforeEach(async () => {
  if (testEnv) {
    await testEnv.clearFirestore();
  }
});

test("Unauthenticated user: denied all reads and writes across Wakil collections", async () => {
  const unauthDb = testEnv.unauthenticatedContext().firestore();
  const ts = new Date(Date.now() - 1000);

  await assertFails(unauthDb.collection(`users/${ALICE_UID}/chats`).get());
  await assertFails(
    unauthDb.collection(`users/${ALICE_UID}/chats`).doc("chat_1").set({
      userId: ALICE_UID,
      title: "Tenant Rights",
      lastMessage: "Sec 391",
      pinned: true,
      language: "EN",
      createdAt: ts,
      updatedAt: ts,
    })
  );
  await assertFails(unauthDb.collection(`users/${ALICE_UID}/documents`).get());
  await assertFails(unauthDb.collection(`users/${ALICE_UID}/corpus`).get());
});

test("Authenticated owner: ChatSession & ChatMessage create, list, partial update, and parent gate check", async () => {
  const aliceDb = testEnv.authenticatedContext(ALICE_UID).firestore();
  const created = new Date(Date.now() - 10000);
  const updated = new Date(Date.now() - 1000);

  // 1. Orphan message creation before parent chat exists must fail (Parent Gate)
  await assertFails(
    aliceDb
      .collection(`users/${ALICE_UID}/chats/chat_1/messages`)
      .doc("msg_orphan")
      .set({
        userId: ALICE_UID,
        chatId: "chat_1",
        sender: "USER",
        content: "Orphan message",
        citations: [],
        hasCanvasDoc: false,
        canvasDocId: "",
        flagged: false,
        createdAt: created,
      })
  );

  // 2. Create parent ChatSession (mirroring Dart/Flutter repository payload, no 'id' field)
  await assertSucceeds(
    aliceDb.collection(`users/${ALICE_UID}/chats`).doc("chat_1").set({
      userId: ALICE_UID,
      title: "Tenant Rights & Security Deposit",
      lastMessage: "What are the statutory guidelines?",
      pinned: true,
      language: "EN",
      createdAt: created,
      updatedAt: created,
    })
  );

  // 3. Create ChatMessage under existing ChatSession succeeds
  await assertSucceeds(
    aliceDb
      .collection(`users/${ALICE_UID}/chats/chat_1/messages`)
      .doc("msg_1")
      .set({
        userId: ALICE_UID,
        chatId: "chat_1",
        sender: "ASSISTANT",
        content: "Under Chapter 9 of the Muluki Civil Code 2074 (Section 391)...",
        citations: ["Muluki Dewani Sec. 391", "Tenancy Rules 2075"],
        hasCanvasDoc: true,
        canvasDocId: "doc_lease_1",
        flagged: false,
        createdAt: created,
      })
  );

  // 4. Partial update on ChatSession (pin toggle)
  await assertSucceeds(
    aliceDb.collection(`users/${ALICE_UID}/chats`).doc("chat_1").update({
      pinned: false,
      updatedAt: updated,
    })
  );

  // 5. Partial update on ChatMessage (flag response)
  await assertSucceeds(
    aliceDb
      .collection(`users/${ALICE_UID}/chats/chat_1/messages`)
      .doc("msg_1")
      .update({
        flagged: true,
      })
  );

  // 6. List queries aligned with Dart/Flutter repository
  await assertSucceeds(aliceDb.collection(`users/${ALICE_UID}/chats`).get());
  await assertSucceeds(
    aliceDb.collection(`users/${ALICE_UID}/chats/chat_1/messages`).get()
  );

  // 7. Reject shadow update with ghost field or explicit 'id' key
  await assertFails(
    aliceDb.collection(`users/${ALICE_UID}/chats`).doc("chat_1").update({
      pinned: true,
      ghostField: "hacked",
      updatedAt: updated,
    })
  );
  await assertFails(
    aliceDb.collection(`users/${ALICE_UID}/chats`).doc("chat_2").set({
      id: "chat_2",
      userId: ALICE_UID,
      title: "Invalid ID key",
      lastMessage: "",
      pinned: false,
      language: "EN",
      createdAt: created,
      updatedAt: created,
    })
  );
});

test("Authenticated owner: LegalDocument, CorpusDocument, ManagedUser, FlaggedAudit, and SystemConfig CRUD", async () => {
  const aliceDb = testEnv.authenticatedContext(ALICE_UID).firestore();
  const created = new Date(Date.now() - 10000);
  const updated = new Date(Date.now() - 1000);

  // LegalDocument create & update
  await assertSucceeds(
    aliceDb.collection(`users/${ALICE_UID}/documents`).doc("doc_lease_1").set({
      userId: ALICE_UID,
      title: "Residential Lease Agreement",
      nepaliTitle: "घर बहाल सम्झौता",
      statuteBadge: "Muluki Civil Code 2074 Compliant",
      landlordName: "Ram Krishna Shrestha",
      tenantName: "Sunita Maharjan",
      propertyAddress: "Second Floor Flat (3 BHK), Ward No. 4, Baluwatar, Kathmandu",
      monthlyRentNpr: 35000,
      securityDepositNpr: 70000,
      durationText: "Valid for 2 continuous years from 2081/01/01 B.S.",
      utilitiesText: "Electricity, water, internet settled by Tenant.",
      disputeText: "Referred to local judicial committee mediation under Sec. 398.",
      createdAt: created,
      updatedAt: created,
    })
  );
  await assertSucceeds(
    aliceDb.collection(`users/${ALICE_UID}/documents`).doc("doc_lease_1").update({
      monthlyRentNpr: 45000,
      securityDepositNpr: 90000,
      updatedAt: updated,
    })
  );

  // CorpusDocument create & update
  await assertSucceeds(
    aliceDb.collection(`users/${ALICE_UID}/corpus`).doc("corpus_1").set({
      userId: ALICE_UID,
      fileName: "Muluki Dewani Samhita 2074.pdf",
      category: "CODES",
      subtitle: "Civil Code • 4,120 chunks • 1.8 MB • Updated 2 days ago",
      chunksCount: 4120,
      fileSizeLabel: "1.8 MB",
      status: "INDEXED",
      createdAt: created,
      updatedAt: created,
    })
  );
  await assertSucceeds(
    aliceDb.collection(`users/${ALICE_UID}/corpus`).doc("corpus_1").update({
      status: "INDEXED",
      subtitle: "Civil Code • 4,120 chunks • 1.8 MB • Just synced",
      updatedAt: updated,
    })
  );

  // ManagedUser create & update
  await assertSucceeds(
    aliceDb.collection(`users/${ALICE_UID}/managed_users`).doc("u_1").set({
      userId: ALICE_UID,
      fullName: "Ram Krishna Shrestha",
      email: "ram.shrestha@example.com",
      phone: "+977 9841234567",
      accountStatus: "ACTIVE",
      joinedLabel: "Joined: 12 Jan 2025",
      queriesCount: 184,
      moderationNote: "",
      createdAt: created,
      updatedAt: created,
    })
  );
  await assertSucceeds(
    aliceDb.collection(`users/${ALICE_UID}/managed_users`).doc("u_1").update({
      accountStatus: "ADMIN",
      updatedAt: updated,
    })
  );

  // FlaggedAudit create & update
  await assertSucceeds(
    aliceDb.collection(`users/${ALICE_UID}/flagged_audits`).doc("flag_1").set({
      userId: ALICE_UID,
      userLabel: "User #8429 • Today, 11:42 AM",
      flagType: "Hallucination",
      severityLabel: "High Severity",
      userQuery: "What is the penalty for default under Contract Act 2056?",
      aiResponse: "Mandatory 5-year imprisonment under Section 82.",
      alertTitle: "Inaccurate Citation Detected",
      alertDetail: "Contract Act 2056 Section 82 was repealed.",
      ragSource: "Contract Act 2056 § 82",
      resolved: false,
      createdAt: created,
      updatedAt: created,
    })
  );
  await assertSucceeds(
    aliceDb.collection(`users/${ALICE_UID}/flagged_audits`).doc("flag_1").update({
      resolved: true,
      updatedAt: updated,
    })
  );

  // SystemConfig create & update
  await assertSucceeds(
    aliceDb.collection(`users/${ALICE_UID}/settings`).doc("main_config").set({
      userId: ALICE_UID,
      systemPrompt: "You are Wakil, an AI legal intelligence assistant specialized in Nepal Law.",
      foundationModel: "Gemini 3.8 Flash (Nepal-tuned)",
      temperature: 0.2,
      maxOutputTokens: 2048,
      preferredLanguage: "EN",
      disclaimerAccepted: true,
      createdAt: created,
      updatedAt: created,
    })
  );
  await assertSucceeds(
    aliceDb.collection(`users/${ALICE_UID}/settings`).doc("main_config").update({
      temperature: 0.35,
      preferredLanguage: "NP",
      updatedAt: updated,
    })
  );
});

test("Cross-user isolation: Bob cannot read, list, update, or delete Alice's records", async () => {
  const created = new Date(Date.now() - 10000);
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context
      .firestore()
      .collection(`users/${ALICE_UID}/chats`)
      .doc("alice_chat")
      .set({
        userId: ALICE_UID,
        title: "Confidential Legal Inquiry",
        lastMessage: "Private details",
        pinned: true,
        language: "EN",
        createdAt: created,
        updatedAt: created,
      });
  });

  const bobDb = testEnv.authenticatedContext(BOB_UID).firestore();
  await assertFails(
    bobDb.collection(`users/${ALICE_UID}/chats`).doc("alice_chat").get()
  );
  await assertFails(bobDb.collection(`users/${ALICE_UID}/chats`).get());
  await assertFails(
    bobDb
      .collection(`users/${ALICE_UID}/chats`)
      .doc("alice_chat")
      .update({ pinned: false, updatedAt: new Date(Date.now() - 1000) })
  );
  await assertFails(
    bobDb.collection(`users/${ALICE_UID}/chats`).doc("alice_chat").delete()
  );
});
