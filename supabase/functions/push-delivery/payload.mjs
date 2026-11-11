// Firebase HTTP v1 targets an FCM registration token, not an Installation ID.
export function fcmMessage(token, title, body, kind) {
  return {message: {token, notification: {title, body}, data: {kind},
    android: {priority: 'HIGH', notification: {channel_id: 'freelan_updates', sound: 'default'}}}};
}
