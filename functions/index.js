const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const DATABASE_ID = "mixtape-db";

// Notify the recipient when a new message lands in a conversation.
// Conversation IDs are "<uid1>_<uid2>" (sorted), so the recipient is
// whichever uid isn't the sender. Fires for writes from the app and,
// later, the share extension alike.
exports.notifyOnMixtape = onDocumentCreated(
  {
    document: "conversations/{conversationId}/messages/{messageId}",
    database: DATABASE_ID,
    region: "europe-west2",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const msg = snapshot.data();

    const { conversationId } = event.params;
    const [uid1, uid2] = conversationId.split("_");
    const recipientUid = msg.senderUid === uid1 ? uid2 : uid1;
    if (!recipientUid || recipientUid === msg.senderUid) {
      console.log(`Could not determine recipient for ${conversationId}`);
      return;
    }

    const db = getFirestore(DATABASE_ID);
    const [recipientDoc, senderDoc] = await Promise.all([
      db.doc(`users/${recipientUid}`).get(),
      db.doc(`users/${msg.senderUid}`).get(),
    ]);

    const token = recipientDoc.get("fcmToken");
    if (!token) {
      console.log(`No FCM token for ${recipientUid}, skipping notification`);
      return;
    }

    const senderName =
      senderDoc.get("displayName") ||
      (senderDoc.get("email") || "A friend").split("@")[0];
    const body = msg.metadata
      ? `${msg.metadata.title} — ${msg.metadata.artist}`
      : "Open Mixtape to listen";

    try {
      await getMessaging().send({
        token,
        notification: {
          title: `${senderName} sent you a mixtape 🎵`,
          body,
        },
        data: { conversationId },
        apns: {
          payload: {
            aps: { sound: "default" },
          },
        },
      });
      console.log(`Notified ${recipientUid} about ${event.params.messageId}`);
    } catch (error) {
      // Token no longer valid (app deleted, etc.) — remove it so we stop trying
      if (error.code === "messaging/registration-token-not-registered") {
        await db
          .doc(`users/${recipientUid}`)
          .update({ fcmToken: FieldValue.delete() });
        console.log(`Removed dead FCM token for ${recipientUid}`);
      } else {
        throw error;
      }
    }
  }
);
