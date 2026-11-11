<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:d1c601a0b028ddf88a654732d0293953b90a795676a9e95f751ca01d851eca8e -->

# Administrator notifications

Editors can open **Send notification**, search by name, email or public User ID and select one user, or choose **All users**. Enter a title (1–80 characters) and message (1–500 characters), confirm the recipient and send. The count is the number of in-app recipient records created, not a guarantee of device delivery. All means confirmed, unblocked accounts at the time of sending. Users without push enabled still see the message in the app; registered devices with push enabled receive jobs through the existing worker. Offline devices and provider failures can delay or prevent delivery.

Admin-authored title and message are displayed in the user's app and in push notifications, including on the lock screen. This extends the earlier generic-only push content contract. Editors and existing MFA checks are enforced on the server; viewers and ordinary users cannot send. Requests are recorded once per editor/request ID. Retrying unchanged content on the same screen reuses the ID if the response was lost. After leaving the screen, verify activity before sending again. Existing worker retry/lease behavior may still produce duplicate device delivery.

## Rollout

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:45fbca495fbc685cc2c79f4b38e05948a69b386f8d8e9a6b48529b02d23e1c75 -->

Apply `supabase/migrations/20261111120532_admin_notifications.sql` after all earlier migrations. Its version matches the migration applied to the linked project.

<!-- /coderabbit-ai-generated:v1 --> It adds custom content, keeps the existing claim function and adds a service-only v2 claim function. Then deploy `push-delivery` with JWT verification enabled and the existing worker secrets/schedule. Distribute both updated Windows admin and Android user builds before sending messages. Older user apps do not display custom in-app message content, though phone notifications can show it. Never create an additional scheduler.

Run Flutter analyzer/tests, Node worker tests and the disposable PostgreSQL integration. On a physical Android device, sign in, enable notifications, send one message and one broadcast, and verify the title, content, in-app read state and behavior with push disabled. Local checks cannot establish Firebase delivery or actual device behavior.

## Immediate background delivery

The notification statement trigger wakes the private push worker through pg_net after queued rows are committed. One bulk notification insertion makes one wakeup, including admin broadcasts; replaying an idempotent send does not create duplicate notifications or wakeups. Vault supplies the existing URL, anon JWT and worker secret, with no client access to those values. The existing once-per-minute Cron schedule remains a retry fallback. Worker batches contain up to 100 jobs; a full batch schedules the next worker invocation through EdgeRuntime.waitUntil. Delivery is attempted promptly; network, FCM/Android permissions, connectivity and OS restrictions still control arrival time. Queue success or a worker HTTP 200 is not evidence that a device displayed the notification.

The worker sends a visible notification payload with HIGH Android priority and channel freelan_updates. The Android app creates that channel at high importance. HTTP v1 token targeting supports the app's cached FCM tokens as well as FIDs during the provider transition; do not pass legacy registration tokens in the fid field. The token field/Flutter compatibility APIs are intentionally retained while older devices migrate. Real background/terminated-state device delivery must be checked separately after installing a production-signed build and opting in. No automated test sends a message to an actual user.


<!-- /coderabbit-ai-generated:v1 -->