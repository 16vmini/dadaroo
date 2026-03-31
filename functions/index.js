const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { logger } = require("firebase-functions");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

/**
 * Watches the notificationRequests collection and sends push notifications.
 * Supports both topic-based (family group) and direct token-based notifications.
 */
exports.sendNotification = onDocumentCreated(
  "notificationRequests/{requestId}",
  async (event) => {
    const data = event.data.data();
    if (!data || data.processed) {
      logger.info("Skipping: no data or already processed");
      return;
    }

    logger.info("Processing notification request", {
      type: data.type,
      title: data.title,
      familyGroupId: data.familyGroupId || null,
      targetUid: data.targetUid || null,
    });

    try {
      if (data.familyGroupId) {
        // Strategy 1: Send via topic
        const topicMessage = {
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

        try {
          const topicResult = await messaging.send(topicMessage);
          logger.info("Topic notification sent", { result: topicResult });
        } catch (topicErr) {
          logger.warn("Topic send failed, falling back to direct tokens", {
            error: topicErr.message,
          });
        }

        // Strategy 2: Also send directly to all family member tokens as fallback
        const groupDoc = await db
          .collection("familyGroups")
          .where("id", "==", data.familyGroupId)
          .limit(1)
          .get();

        let memberIds = [];
        if (!groupDoc.empty) {
          memberIds = groupDoc.docs[0].data().memberIds || [];
        } else {
          // Try fetching by doc ID
          const directDoc = await db
            .collection("familyGroups")
            .doc(data.familyGroupId)
            .get();
          if (directDoc.exists) {
            memberIds = directDoc.data().memberIds || [];
          }
        }

        if (memberIds.length > 0) {
          const tokens = [];
          for (const uid of memberIds) {
            const userDoc = await db.collection("users").doc(uid).get();
            const token = userDoc.data()?.fcmToken;
            if (token) tokens.push(token);
          }

          logger.info(`Found ${tokens.length} FCM tokens for ${memberIds.length} members`);

          for (const token of tokens) {
            try {
              await messaging.send({
                token,
                notification: { title: data.title, body: data.body },
                data: { type: data.type || "general", ...(data.data || {}) },
                apns: {
                  payload: { aps: { sound: "default", badge: 1 } },
                },
                android: {
                  priority: "high",
                  notification: { sound: "default", channelId: "delivery_updates" },
                },
              });
              logger.info("Direct token notification sent", { token: token.substring(0, 10) + "..." });
            } catch (tokenErr) {
              logger.warn("Failed to send to token", {
                token: token.substring(0, 10) + "...",
                error: tokenErr.message,
              });
            }
          }
        }
      } else if (data.targetUid) {
        const userDoc = await db.collection("users").doc(data.targetUid).get();
        const token = userDoc.data()?.fcmToken;

        if (token) {
          const result = await messaging.send({
            token,
            notification: { title: data.title, body: data.body },
            data: { type: data.type || "general" },
            apns: {
              payload: { aps: { sound: "default", badge: 1 } },
            },
            android: {
              priority: "high",
              notification: { sound: "default", channelId: "delivery_updates" },
            },
          });
          logger.info("Direct notification sent", { result });
        } else {
          logger.warn("No FCM token found for user", { uid: data.targetUid });
        }
      }

      await event.data.ref.update({ processed: true });
      logger.info("Notification request processed successfully");
    } catch (error) {
      logger.error("Error sending notification", { error: error.message, stack: error.stack });
      await event.data.ref.update({
        processed: true,
        error: error.message,
      });
    }
  }
);
