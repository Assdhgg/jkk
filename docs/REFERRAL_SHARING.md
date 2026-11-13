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

<!-- /coderabbit-ai-generated:v1 --> The migration starts without a link. An editor administrator opens **App releases**, enters a public HTTPS APK URL under **Referral app download link**, then selects **Save link**. The same field edits the link; **Delete link** removes it. Viewers can read but cannot change it. Server authorization requires editor access and administrator MFA.

New user apps fetch the current administrator link when sharing a referral. After deletion, sharing reports that the link is unavailable until an editor adds another. A failed request shows a retry message. The link should work without signing in and must contain no credentials. Verify the signed APK and test the link separately. This setting does not upload an APK, publish an app release, or trigger mandatory updates.

This replaces automatic referral selection of the latest published release and any build-time fallback. Older installed app versions retain their earlier behavior until updated. Editing or deleting the link does not remove previously shared messages or delete hosted APK files.

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->
