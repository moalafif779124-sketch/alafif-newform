/**
 * Firebase Cloud Functions for Alafif Newform
 *
 * Sends push notifications (FCM) to customers when admin updates order status.
 *
 * Trigger: Firestore `orders/{orderId}` onWrite
 * Reads user's FCM tokens from `users/{userId}` document
 */

const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

// =================== إشعارات تحديث الطلبات ===================

exports.sendOrderNotification = onDocumentWritten(
  {
    document: 'orders/{orderId}',
    region: 'us-central1',
  },
  async (event) => {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();

    // تجاهل إنشاء الطلب (نريد التحديثات فقط)
    if (!beforeData || !afterData) return;

    const beforeStatus = beforeData.status || '';
    const afterStatus = afterData.status || '';

    // إذا لم تتغير الحالة، تجاهل
    if (beforeStatus === afterStatus) return;

    console.log(`📦 Order ${event.params.orderId}: ${beforeStatus} → ${afterStatus}`);

    // ترجمة الحالة إلى عنوان عربي
    const titles = {
      confirmed: 'تم تأكيد الطلب ✓',
      processing: 'طلبك قيد التجهيز',
      shipped: 'تم شحن طلبك 🚚',
      delivered: 'تم توصيل طلبك ✅',
      cancelled: 'تم إلغاء الطلب',
    };

    const bodies = {
      confirmed: (num) => `تم تأكيد الطلب رقم ${num} وسيتم تجهيزه قريباً`,
      processing: (num) => `طلبك رقم ${num} قيد التجهيز الآن`,
      shipped: (num) => `طلبك رقم ${num} في طريقه إليك 🚚`,
      delivered: (num) => `تم توصيل الطلب رقم ${num} بنجاح ✅`,
      cancelled: (num) => `تم إلغاء الطلب رقم ${num}`,
    };

    const title = titles[afterStatus] || 'تحديث الطلب';
    const body = bodies[afterStatus]
      ? bodies[afterStatus](afterData.orderNumber || '')
      : `تم تحديث حالة الطلب رقم ${afterData.orderNumber || ''}`;

    // الحصول على userId من الطلب
    const userId = afterData.userId || afterData.user_id;
    if (!userId) {
      console.log('⚠️ No userId in order data');
      return;
    }

    // جلب FCM tokens من وثيقة المستخدم
    let fcmTokens = [];
    try {
      const userDoc = await getFirestore().collection('users').doc(userId).get();
      if (userDoc.exists) {
        fcmTokens = userDoc.data()?.fcmTokens || [];
      }
    } catch (err) {
      console.error('⚠️ Failed to fetch user FCM tokens:', err);
    }

    if (fcmTokens.length === 0) {
      console.log('⚠️ No FCM tokens found for user', userId);
      return;
    }

    console.log(`📱 Sending to ${fcmTokens.length} device(s) for user ${userId}`);

    // إرسال إشعار لكل token
    const results = await Promise.allSettled(
      fcmTokens.map(async (token) => {
        const message = {
          token,
          notification: {
            title,
            body,
          },
          data: {
            type: 'order_update',
            orderId: event.params.orderId,
            status: afterStatus,
            orderNumber: afterData.orderNumber || '',
          },
          android: {
            priority: 'high',
            notification: {
              channelId: 'order_updates',
              icon: 'ic_launcher',
              color: '#1B5E20',
              sound: 'default',
            },
          },
        };

        try {
          await getMessaging().send(message);
          console.log(`✅ Sent to token: ${token.substring(0, 10)}...`);
          return { token, success: true };
        } catch (error) {
          // إذا كان token منتهي الصلاحية، يحذفه
          if (error.code === 'messaging/registration-token-not-registered' ||
              error.code === 'messaging/invalid-registration-token') {
            console.log(`🗑️ Removing stale token: ${token.substring(0, 10)}...`);
            // لا نحذف هنا — Cloud Function لا يمتلك صلاحية الكتابة للمستخدم
            // سنترك ذلك لتطبيق العميل عند استلام الخطأ
          }
          console.error(`❌ Failed to send to token: ${error.message}`);
          return { token, success: false, error: error.message };
        }
      })
    );

    const sent = results.filter((r) => r.status === 'fulfilled' && r.value.success).length;
    const failed = results.filter((r) => r.status === 'fulfilled' && !r.value.success).length;
    const rejected = results.filter((r) => r.status === 'rejected').length;

    console.log(`📊 Results: ${sent} sent, ${failed} failed, ${rejected} rejected`);
  }
);
