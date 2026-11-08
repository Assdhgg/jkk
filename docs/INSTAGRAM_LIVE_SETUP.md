<!-- coderabbit-ai-generated:v1 -->

# Instagram live search setup — Growth Circle

ഈ guide project `stpxbshwdiupigymakfy`-നുള്ളതാണ്. Project URL: `https://stpxbshwdiupigymakfy.supabase.co`.

## നിലവിലെ സ്ഥിതി

App screen, Edge Function source, quota migration എന്നിവ repository-യിൽ തയ്യാറാണ്. GitHub source പരിശോധിച്ചതുകൊണ്ട് hosted database migration നില അറിയാനാവില്ല. Live migration, function deployment, Meta secrets, real-account lookup എന്നിവ ഇവിടെ സ്ഥിരീകരിച്ചിട്ടില്ല. Project URL മാത്രം ഉപയോഗിച്ച് അവ deploy ചെയ്യാൻ സാധിക്കില്ല.

## 1. Supabase migration

1. [Project SQL Editor](https://supabase.com/dashboard/project/stpxbshwdiupigymakfy/sql/new) തുറക്കുക.
2. മുമ്പ് പ്രയോഗിച്ച migrations project-ന്റെ migration record-ൽ പരിശോധിക്കുക. SQL Editor വഴി run ചെയ്തവ Supabase CLI migration history-യിൽ രേഖപ്പെടുത്തിയിരിക്കണമെന്നില്ല.
3. മുൻപുള്ള ഏഴ് migrations പ്രയോഗിച്ചിട്ടുണ്ടെങ്കിൽ, repository-യിലെ `supabase/migrations/20261107070000_instagram_lookup_rate.sql` തുറന്ന് അതിലെ മുഴുവൻ SQL ഈ project-ൽ ഒരിക്കൽ run ചെയ്യുക. പഴയ migrations ബാക്കിയുണ്ടെങ്കിൽ [build guide](VISUAL_STUDIO_BUILD_GUIDE.md#3-supabase-project-തയ്യാറാക്കുക)-ൽ നൽകിയ ക്രമം പിന്തുടരുക. പഴയ migrations വീണ്ടും run ചെയ്യരുത്.
4. താഴെയുള്ള query function ഉണ്ടോ എന്ന അടിസ്ഥാന പരിശോധനയ്ക്ക് ഉപയോഗിക്കാം. ഇത് മുഴുവൻ migration ശരിയായി പ്രയോഗിച്ചതിന്റെ തെളിവല്ല; `null` വന്നാൽ function ഇല്ല.

```sql
select to_regprocedure('public.reserve_instagram_lookup()');
```

## 2. Meta configuration

നിലവിലുള്ള Meta Developer app-ൽ Facebook Login അടിസ്ഥാനമാക്കിയ Instagram Business Discovery access configure ചെയ്യുക. ഇതിന് authorized Instagram Business/Creator account, linked Facebook Page, അതിന്റെ numeric Instagram user ID, applicable Facebook access token എന്നിവ വേണം. Permissions: `instagram_basic`, `instagram_manage_insights`, `pages_read_engagement`; account roles അനുസരിച്ച് കൂടുതൽ permissions അല്ലെങ്കിൽ Meta review ആവശ്യമായേക്കാം. [Meta Business Discovery requirements](https://developers.facebook.com/documentation/instagram-platform/instagram-graph-api/reference/ig-user/business_discovery) പരിശോധിക്കുക.

[Supabase Edge Function secrets](https://supabase.com/dashboard/project/stpxbshwdiupigymakfy/functions/secrets)-ൽ താഴെപ്പറയുന്ന names ഉപയോഗിച്ച് values ചേർക്കുക:

| Secret name | Value |
| --- | --- |
| `META_INSTAGRAM_USER_ID` | Authorized professional account-ന്റെ numeric Instagram ID; username അല്ല |
| `META_INSTAGRAM_ACCESS_TOKEN` | Meta flow വഴി ലഭിച്ച applicable Facebook access token |

Token chat, screenshot, source code, GitHub എന്നിവയിൽ ഇടരുത്. `SUPABASE_URL`, `SUPABASE_ANON_KEY` എന്നിവ hosted Edge Function-ന് Supabase നൽകുന്നു. Token expire/revoke ചെയ്താൽ secret പുതുക്കണം. [Supabase secrets documentation](https://supabase.com/docs/guides/functions/secrets).

## 3. Edge Function deploy

ഈ branch-ലെ പുതിയ code ഉള്ള checkout ഉപയോഗിക്കുക. [Supabase CLI](https://supabase.com/docs/guides/functions/deploy) install ചെയ്ത കമ്പ്യൂട്ടറിൽ repository root-ൽ നിന്ന് run ചെയ്യുക:

```powershell
supabase login
supabase functions deploy instagram-lookup --project-ref stpxbshwdiupigymakfy
```

`supabase login` നിങ്ങളുടെ കമ്പ്യൂട്ടറിൽ മാത്രം പൂർത്തിയാക്കുക; അതിന്റെ token chat-ൽ അയക്കരുത്. JWT verification enabled ആയിരിക്കണം. Dashboard-ൽ `instagram-lookup` function deployed ആണെന്ന് പരിശോധിക്കുക. Deployment വിജയിക്കുന്നത് മാത്രം Meta lookup വിജയിച്ചതിന്റെ തെളിവല്ല.

## 4. App build, live check

[Build guide](VISUAL_STUDIO_BUILD_GUIDE.md) പിന്തുടർന്ന് പുതിയ user APK build ചെയ്യുക. Build-ൽ മുകളിലുള്ള project URL ഉം ഇതേ project-ന്റെ publishable/anon key ഉം ഉപയോഗിക്കുക. പഴയ APK-ൽ പുതിയ search screen ഉണ്ടാകില്ല.

1. Active app user ആയി sign in ചെയ്യുക.
2. Profile → Instagram accounts → Search Instagram username തുറക്കുക.
3. അറിയാവുന്ന Business/Creator account-ന്റെ **മുഴുവൻ username** നൽകുക.
4. കിട്ടിയ result പരിശോധിച്ച് Add account അമർത്തുക; account list-ൽ വന്നോ പരിശോധിക്കുക.
5. Unavailable വന്നാൽ Supabase Function logs, Meta token expiry, permissions, account type എന്നിവ പരിശോധിക്കുക. Logs/screenshots പങ്കിടുമ്പോൾ credentials മറയ്ക്കുക.

ഈ API personal/age-restricted accounts-നോ partial-name suggestions-നോ പിന്തുണ നൽകുന്നില്ല. Manual username entry ലഭ്യമാണ്. Search result account ownership തെളിയിക്കുന്നില്ല. Server active user session പരിശോധിക്കുകയും ഓരോ user-നും മിനിറ്റിൽ 20 lookups അനുവദിക്കുകയും ചെയ്യുന്നു.
