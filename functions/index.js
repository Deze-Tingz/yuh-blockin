/**
 * Yuh Blockin' Cloud Functions
 * Backend logic for alert escalation and notifications
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Send alert notification with escalation
 * Called by the mobile app when escalating alerts
 */
exports.sendAlertNotification = functions.https.onCall(async (data, context) => {
  try {
    // Check if user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to send alerts'
      );
    }

    const { alertId, escalationStep, urgency, targetUid, customMessage } = data;

    // Validate input
    if (!alertId || !targetUid || escalationStep === undefined) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required parameters'
      );
    }

    // Get target user's FCM tokens
    const userDoc = await db.collection('users').doc(targetUid).get();

    if (!userDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Target user not found'
      );
    }

    const userData = userDoc.data();
    const fcmTokens = userData.fcmTokens || [];

    if (fcmTokens.length === 0) {
      console.warn(`No FCM tokens found for user ${targetUid}`);
      return { success: false, reason: 'No FCM tokens' };
    }

    // Get escalation message
    const escalationMessage = getEscalationMessage(urgency, escalationStep, customMessage);
    const priority = getNotificationPriority(urgency, escalationStep);

    // Create notification payload
    const notification = {
      title: escalationMessage.title,
      body: escalationMessage.body,
      android: {
        priority: priority,
        notification: {
          channelId: 'parking_alerts',
          priority: priority,
          defaultSound: true,
          defaultVibrateTimings: true,
          color: getNotificationColor(urgency),
          icon: 'ic_notification',
          tag: alertId, // Ensures notifications replace each other
        },
        data: {
          alertId: alertId,
          escalationStep: escalationStep.toString(),
          urgency: urgency,
          type: 'parking_alert',
          click_action: 'ALERT_RESPONSE',
        }
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: escalationMessage.title,
              body: escalationMessage.body,
            },
            sound: 'default',
            badge: 1,
            category: 'PARKING_ALERT',
            'thread-id': alertId,
          }
        },
        headers: {
          'apns-priority': priority === 'high' ? '10' : '5',
        }
      },
      data: {
        alertId: alertId,
        escalationStep: escalationStep.toString(),
        urgency: urgency,
        type: 'parking_alert',
      }
    };

    // Send to all user's devices
    const results = await Promise.allSettled(
      fcmTokens.map(token => messaging.send({
        token: token,
        ...notification
      }))
    );

    // Process results and remove invalid tokens
    const validTokens = [];
    const invalidTokens = [];

    results.forEach((result, index) => {
      if (result.status === 'fulfilled') {
        validTokens.push(fcmTokens[index]);
      } else {
        const error = result.reason;
        console.error(`Failed to send to token ${fcmTokens[index]}:`, error);

        // Check for invalid token errors
        if (error.code === 'messaging/invalid-registration-token' ||
            error.code === 'messaging/registration-token-not-registered') {
          invalidTokens.push(fcmTokens[index]);
        }
      }
    });

    // Update user's FCM tokens if any are invalid
    if (invalidTokens.length > 0) {
      await db.collection('users').doc(targetUid).update({
        fcmTokens: validTokens
      });
    }

    // Log notification activity
    await db.collection('notification_logs').add({
      alertId: alertId,
      targetUid: targetUid,
      escalationStep: escalationStep,
      urgency: urgency,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      tokensTargeted: fcmTokens.length,
      tokensSuccessful: validTokens.length,
      tokensInvalid: invalidTokens.length,
      message: escalationMessage
    });

    return {
      success: true,
      tokensTargeted: fcmTokens.length,
      tokensSuccessful: validTokens.length,
      tokensInvalid: invalidTokens.length
    };

  } catch (error) {
    console.error('Error sending alert notification:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to send notification: ' + error.message
    );
  }
});

/**
 * Handle alert acknowledgment
 * Called when user responds to an alert
 */
exports.acknowledgeAlert = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    const { alertId, responseType } = data;
    const userUid = context.auth.uid;

    // Update alert status
    await db.collection('alerts').doc(alertId).update({
      status: 'acknowledged',
      acknowledgedAt: admin.firestore.FieldValue.serverTimestamp(),
      acknowledgedBy: userUid,
      responseType: responseType,
    });

    // Send acknowledgment notification to reporter
    const alertDoc = await db.collection('alerts').doc(alertId).get();
    if (alertDoc.exists) {
      const alertData = alertDoc.data();

      await sendAcknowledgmentNotification(
        alertData.reporterUid,
        alertId,
        responseType
      );
    }

    return { success: true };

  } catch (error) {
    console.error('Error acknowledging alert:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to acknowledge alert: ' + error.message
    );
  }
});

/**
 * Clean up old alerts and logs
 * Runs daily to remove old data
 */
exports.cleanupOldData = functions.pubsub.schedule('0 2 * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const thirtyDaysAgo = new admin.firestore.Timestamp(
      now.seconds - (30 * 24 * 60 * 60),
      now.nanoseconds
    );

    const batch = db.batch();
    let deletedCount = 0;

    // Clean up old alerts
    const oldAlertsQuery = await db.collection('alerts')
      .where('sentAt', '<', thirtyDaysAgo)
      .limit(500) // Process in batches
      .get();

    oldAlertsQuery.docs.forEach(doc => {
      batch.delete(doc.ref);
      deletedCount++;
    });

    // Clean up old notification logs
    const oldLogsQuery = await db.collection('notification_logs')
      .where('sentAt', '<', thirtyDaysAgo)
      .limit(500)
      .get();

    oldLogsQuery.docs.forEach(doc => {
      batch.delete(doc.ref);
      deletedCount++;
    });

    if (deletedCount > 0) {
      await batch.commit();
      console.log(`Cleaned up ${deletedCount} old documents`);
    }

    return null;
  });

/**
 * Update user's FCM token
 * Called when app starts or token refreshes
 */
exports.updateFCMToken = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    const { token } = data;
    const userUid = context.auth.uid;

    if (!token) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'FCM token is required'
      );
    }

    // Get user's current tokens
    const userDoc = await db.collection('users').doc(userUid).get();
    let currentTokens = [];

    if (userDoc.exists) {
      currentTokens = userDoc.data().fcmTokens || [];
    }

    // Add new token if not already present
    if (!currentTokens.includes(token)) {
      currentTokens.push(token);

      // Keep only the most recent 5 tokens per user
      if (currentTokens.length > 5) {
        currentTokens = currentTokens.slice(-5);
      }

      await db.collection('users').doc(userUid).update({
        fcmTokens: currentTokens,
        lastTokenUpdate: admin.firestore.FieldValue.serverTimestamp()
      });
    }

    return { success: true, tokenCount: currentTokens.length };

  } catch (error) {
    console.error('Error updating FCM token:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to update FCM token: ' + error.message
    );
  }
});

// Helper Functions

function getEscalationMessage(urgency, step, customMessage) {
  const urgencyMessages = {
    low: [
      {
        title: 'Gentle Reminder - Yuh Blockin\'',
        body: customMessage || 'Yuh car blocking someone, easy nuh! Please check when convenient.'
      },
      {
        title: 'Follow Up - Still Blocked',
        body: 'Still blocking, bredrin - when yuh free to move?'
      },
      {
        title: 'Final Reminder',
        body: 'Respek - please move when convenient. Thanks!'
      }
    ],
    normal: [
      {
        title: 'Parking Alert - Yuh Blockin\'!',
        body: customMessage || 'Yuh car blocking someone - please check and move!'
      },
      {
        title: 'Urgent - Still Blocking',
        body: 'Still blocked - need yuh to move now, please!'
      },
      {
        title: 'Very Urgent - Move Now',
        body: 'Yuh blocking traffic - move immediately!'
      }
    ],
    high: [
      {
        title: 'URGENT - YUH BLOCKIN\'!',
        body: customMessage || 'YUH BLOCKIN\' - Move immediately!'
      },
      {
        title: 'VERY URGENT - MOVE NOW!',
        body: 'MOVE YUH CAR RIGHT NOW!'
      },
      {
        title: 'CRITICAL - EMERGENCY BLOCKING!',
        body: 'EMERGENCY BLOCKING - MOVE NOW!'
      }
    ],
    emergency: [
      {
        title: 'EMERGENCY - BLOCKING ACCESS!',
        body: 'BLOCKING EMERGENCY ACCESS - MOVE IMMEDIATELY!'
      },
      {
        title: 'CRITICAL EMERGENCY!',
        body: 'MOVE IMMEDIATELY - EMERGENCY SERVICES NEEDED!'
      },
      {
        title: 'AUTHORITIES NOTIFIED',
        body: 'Emergency services have been notified!'
      }
    ]
  };

  const messages = urgencyMessages[urgency] || urgencyMessages.normal;
  const messageIndex = Math.min(step, messages.length - 1);

  return messages[messageIndex];
}

function getNotificationPriority(urgency, step) {
  if (urgency === 'emergency' || urgency === 'high') {
    return 'high';
  }
  if (urgency === 'normal' && step > 0) {
    return 'high';
  }
  return 'normal';
}

function getNotificationColor(urgency) {
  const colors = {
    low: '#4CAF50',    // Palm green
    normal: '#2196F3', // Ocean blue
    high: '#FF9800',   // Mango orange
    emergency: '#F44336' // Coral red
  };

  return colors[urgency] || colors.normal;
}

async function sendAcknowledgmentNotification(reporterUid, alertId, responseType) {
  try {
    const userDoc = await db.collection('users').doc(reporterUid).get();

    if (!userDoc.exists) {
      console.warn(`Reporter user ${reporterUid} not found`);
      return;
    }

    const userData = userDoc.data();
    const fcmTokens = userData.fcmTokens || [];

    if (fcmTokens.length === 0) {
      console.warn(`No FCM tokens for reporter ${reporterUid}`);
      return;
    }

    const responseMessages = {
      'on_my_way': {
        title: 'Response Received!',
        body: 'Car owner says: "On mi way!" - ETA 5-10 minutes'
      },
      'moving_now': {
        title: 'Car Moving Now!',
        body: 'Owner is moving the car right now!'
      },
      'cant_move': {
        title: 'Owner Responds',
        body: 'Owner says they can\'t move right now. Please be patient.'
      }
    };

    const message = responseMessages[responseType] || responseMessages['on_my_way'];

    const notification = {
      title: message.title,
      body: message.body,
      android: {
        priority: 'normal',
        notification: {
          channelId: 'alert_responses',
          color: '#4CAF50',
          icon: 'ic_notification',
          tag: `response_${alertId}`,
        }
      },
      data: {
        alertId: alertId,
        type: 'alert_response',
        responseType: responseType
      }
    };

    // Send to all reporter's devices
    await Promise.allSettled(
      fcmTokens.map(token => messaging.send({
        token: token,
        ...notification
      }))
    );

  } catch (error) {
    console.error('Error sending acknowledgment notification:', error);
  }
}