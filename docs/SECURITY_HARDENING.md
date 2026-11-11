<!-- coderabbit-ai-generated:v1 -->

# Security hardening rollout

This change implements the 2026-11-11 audit repairs. Release version: 1.1.7, build15. The user authorized mandatory MFA, protected token storage and server APK validation. This changes the earlier optional-MFA/upload contract.

## Client changes

Android Supabase session persistence uses flutter_secure_storage11.2.0 (Keystore-protected AES-GCM storage), including PKCE proofs. Existing plaintext sessions are copied into protected storage before their SharedPreferences copy is removed; an existing protected session wins. Storage errors do not fall back to plaintext. Old in-progress plaintext PKCE sign-ins must restart. Existing backups remain disabled. Test device verification of key invalidation, migration and refresh is still required.

User startup accepts only HTTPS project URLs and public publishable/anon keys. The same restriction already applies to admin project setup. Standard certificate validation remains enabled. Certificate pinning was not introduced: it needs a managed pin rotation/recovery policy and Android recommends against it by default.

Admin sign-in now enrolls and verifies a TOTP authenticator when no verified factor exists. Cancelled enrollment is removed. The setup secret is shown locally for the administrator to add to an authenticator; it must not be logged, sent to chat or included in reports. Existing verified TOTP/phone factors use the existing challenge flow. Auth session loss, ten minutes without keyboard/pointer activity or a hidden/paused app locks the workspace and removes pushed detail routes. Membership is rechecked every minute; server RPCs independently enforce access. Public project configuration is still saved per user, not treated as a secret.

## Activate mandatory MFA safely

1. Obtain the new Windows admin build. The existing Windows workflow now also runs for this task branch; inspect the Actions result before distributing its ZIP. Keep the whole Windows release directory together.
2. Sign in using the new app and complete authenticator enrollment. Preserve owner access to the Supabase project for recovery. The agent cannot enroll a personal authenticator for the owner.
3. Confirm the administrator has a verified factor and can complete login. Then apply the new `require_admin_mfa` migration through Supabase. Do not apply it before enrollment/new client availability: old clients without setup support will lose admin business API access.
4. Verify AAL1/no-factor admin calls are denied and a verified AAL2 editor can operate. Membership-only `admin_is_admin` remains callable after password login so the client can reach enrollment; it does not authorize business operations.

The migration requires BOTH a verified factor and signed JWT AAL2 for every admin business call. Existing enrolled-factor enforcement remains live until this staged rollout is completed. No MFA enrollment policy or database test bootstrap is to be installed directly into production.

## APK validator service

A Supabase Edge Function cannot run the Android SDK apksigner process. `services/apk-validator` supplies a small WSGI service/container that uses apksigner and aapt. Deploy it behind HTTPS with bounded concurrency, 512MiB+ memory and at least512MiB temporary disk. Port8080 must not be directly public without TLS termination. Limit request bodies to16KiB and enforce an upstream deadline no greater than240seconds. Do not enable request-body/Authorization/access-URL logging. Run the container without privileges and with resource limits.

Configure on the service:

- `VALIDATOR_SECRET`: a newly generated random secret of at least32characters, held only in server secret stores.
- `APK_SIGNER_SHA256`: the trusted production certificate SHA256, exactly64lowercase hex characters. Obtain it from the original signing certificate or a trusted installed production APK; do not substitute the debug signer or trust the first uploaded file. No private keystore/password is needed by the validator.
- `R2_DOWNLOAD_HOST`: the exact account host `<account-id>.r2.cloudflarestorage.com`.
- `R2_BUCKET`: `freelan-space-apk`.
- `APKSIGNER` and `AAPT`: supplied by the container; host execution can override their paths.

The service authenticates the Edge Function using a timing-safe shared-secret check, downloads only a bounded presigned staging object on the configured R2 host/bucket without redirects and with If-Match, computes actual SHA256/size, verifies the APK signature against the trusted certificate, and verifies package `space.freelan.app` and version metadata. It rejects renamed executables, invalid signatures, unexpected/multiple signers and metadata mismatches. Signer rotation requires an explicit trusted configuration update. Temporary files are removed after each request.

Configure Supabase server secrets `APK_VALIDATOR_URL` (HTTPS `/verify` endpoint) and `APK_VALIDATOR_SECRET` (same shared secret). Deploy updated app-release-upload only after verifying the service end to end. The updated function fails closed if these are missing. It copies the verified staging object using the SAME original ETag, preventing validation/copy substitution, then rechecks editor access. Existing releases remain immutable. New publishing will be unavailable until this service is configured; never bypass it with a client-supplied checksum or validation flag.

## Current activation status

Client fixes, migration, service and Edge Function changes are prepared and locally validated. Mandatory MFA migration and validator-dependent Edge deployment are intentionally pending the verified owner enrollment/validator prerequisites to preserve current admin access and publishing. Production fingerprint and a durable HTTPS validator hosting endpoint are not available in this task. These are outstanding deployment requirements, not completed live repairs.

Android debug compilation is a validation artifact, not a distributable signed update. Production APK generation still requires the original signing keystore through the owner's normal build process. Windows runtime, actual Keystore behavior and real-device TLS/session migration require target-device verification.
