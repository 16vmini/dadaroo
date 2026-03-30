const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

/**
 * Watches the notificationRequests collection and sends push notifications.
 * Supports both topic-based (family group) and direct (individual) notifications.
 */
exports.sendNotification = onDocumentCreated(
  "notificationRequests/{requestId}",
  async (event) => {
    const data = event.data.data();
    if (!data || data.processed) return;

    try {
      if (data.familyGroupId) {
        // Send to all family members via topic
        const message = {
          topic: `family_${data.familyGroupId}`,
          notification: {
            title: data.title,
            body: data.body,
          },
          data: {
            type: data.type || "general",
            ...(data.data || {}),
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
          android: {
            priority: "high",
            notification: {
              sound: "default",
              channelId: "delivery_updates",
            },
          },
        };

        await messaging.send(message);
      } else if (data.targetUid) {
        // Send to a specific user via their FCM token
        const userDoc = await db.collection("users").doc(data.targetUid).get();
        const token = userDoc.data()?.fcmToken;

        if (token) {
          const message = {
            token: token,
            notification: {
              title: data.title,
              body: data.body,
            },
            data: {
              type: data.type || "general",
            },
            apns: {
              payload: {
                aps: {
                  sound: "default",
                  badge: 1,
                },
              },
            },
            android: {
              priority: "high",
              notification: {
                sound: "default",
                channelId: "delivery_updates",
              },
            },
          };

          await messaging.send(message);
        }
      }

      // Mark as processed
      await event.data.ref.update({ processed: true });
    } catch (error) {
      console.error("Error sending notification:", error);
      await event.data.ref.update({
        processed: true,
        error: error.message,
      });
    }
  }
);
