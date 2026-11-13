<!-- coderabbit-ai-generated:v1 -->

# Referral download link

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:3a70c5cf93046f2f1d335a30928e94bad09cfba4531a902758bdfb1ba5f6e985 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:62df6ad4f7da853045061418e02bd1c9fe5c7ff9a70f5d3b05788c201cb28578 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:008bc15bddcb9f0fdf804436aaff16149ac6a03569114bfcc309ae006f37fe9c -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:644bb5dbc3138ac9f5c411543f400912589efdec22d0ba76b77e20e5deeb34aa -->

Migrations `20261113023807_referral_download_link.sql` and `20261113024352_referral_link_invoker.sql` are applied to project `stpxbshwdiupigymakfy`; apply them in order after preceding migrations on other projects. The public RPC uses invoker permissions and delegates to an editor- and MFA-guarded function in a non-exposed schema. Distribute updated administrator and user apps.

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 --> <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:2443270d6cbaa2a9509765b487e0a030c53b843f34111ef3dc6b59368666f584 -->

An editor administrator can add or change a public HTTPS APK URL under **App releases → Referral app download link → Save link**, or remove it using **Delete link**. Viewers can read but cannot change it; server authorization requires editor access and MFA. The link must work without signing in and must contain no credentials.

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:f0d067071c3ffcc483e2fbf93ecfaaaafad7bd8e7bd000a53c14ca1e5f83258d -->

Migration `20261113040028_publish_referral_download.sql` has been applied to project `stpxbshwdiupigymakfy`; apply it after the preceding migrations on other projects. Once the updated `app-release-upload` function is deployed with JWT verification enabled, a successful R2 publication replaces the current referral link in the same transaction as the release.

<!-- /coderabbit-ai-generated:v1 --> The URL includes a safe version name and build number, such as `freelan-space-v1.2.2-20.apk`. Each version keeps its own immutable object. R2 destination conditions reject an existing key; reconcile release history before removing any orphan from a failed upload. Direct R2 edits bypass validation and must not overwrite published objects.

Administrators may manually change or delete the link afterward. Deletion disables sharing until another link is added or another release is published. Older app versions retain their earlier behavior, and existing releases and shared messages are not changed. The legacy Supabase Storage publication RPC does not update the referral link; use the current R2 administrator publishing flow.

Before deploying the updated function, the production APK validator described in `SECURITY_HARDENING.md` must be configured and verified. The previously deployed function lacks this validator; deploying the updated function without it would block publishing. Verify the real hosted upload, public link and device installation after deployment.

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->
