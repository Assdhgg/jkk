<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:934c545457bfb12a35896430a40eb7ccb646bc5ee3a30293dbb1deeed8b56d03 -->

# Freelan Space: Visual Studio ഉപയോഗിച്ച് Android, Windows build ചെയ്യാം

<!-- /coderabbit-ai-generated:v1 -->

ഈ guide Windows 10/11 64-bit PC-യ്ക്കുള്ളതാണ്. **Visual Studio** Windows desktop build-ന് ആവശ്യമാണ്. താഴെയുള്ള commands Visual Studio-യുടെ **View → Terminal**-ലെ PowerShell-ൽ പ്രവർത്തിപ്പിക്കാം. Android SDK ഒരുക്കാൻ Android Studioയും വേണം. Visual Studio Code ഒരു വേറിട്ട editor ആണ്; അത് മാത്രം Windows C++ build tools നൽകില്ല.

## ആദ്യം പരിശോധിച്ച നില

2026-11-08-ന് താഴെപ്പറയുന്ന പരിശോധനകൾ നടത്തി:

- GitHub Actions-ൽ Windows administrator app-ന്റെ `flutter analyze`, `flutter test`, Windows release build, ZIP packaging എന്നിവ വിജയിച്ചു. [ആ build](https://github.com/Assdhgg/jkk/actions/runs/42456224527) പരിശോധിച്ച source tree ഈ guide എഴുതാൻ ഉപയോഗിച്ച source tree-യുമായി ഒത്തതാണ്.
- Android release APK ഒരു **temporary test signing key** ഉപയോഗിച്ച് build ചെയ്ത് signature പരിശോധിച്ചു; debug APK build-വും വിജയിച്ചു. Test key വിതരണം ചെയ്യാനുള്ള key അല്ല.
- നിങ്ങളുടെ release keystore, Supabase project configuration, migration നില, യഥാർത്ഥ Android ഫോൺ, Windows PC എന്നിവ ഇവിടെ ലഭ്യമല്ല. അതിനാൽ നിങ്ങളുടെ production APK install ചെയ്യുന്നതും Supabase connection-ഉം ഇവിടെ സ്ഥിരീകരിച്ചിട്ടില്ല.
- `20261107030000_profile_pin_referrals.sql` പ്രയോഗിച്ചശേഷം പഴയ app-ൽ submission review പ്രവർത്തിക്കില്ല. Database migration-ുകളും പുതിയ app-ുകളും ഒരുമിച്ച് rollout ചെയ്യുക.

## 1. ആവശ്യമായ software

1. [Git for Windows](https://git-scm.com/download/win) install ചെയ്യുക. Installation കഴിഞ്ഞ് PowerShell-ൽ `git --version` പരിശോധിക്കുക.
2. [Visual Studio](https://visualstudio.microsoft.com/downloads/) install ചെയ്യുക. **Visual Studio Installer**-ൽ **Desktop development with C++** workload തിരഞ്ഞെടുക്കുക; അതിലെ default C++ tools, Windows SDK എന്നിവ install ചെയ്തിരിക്കണം. നിലവിൽ Visual Studio ഉണ്ടെങ്കിൽ Installer → **Modify** വഴി workload ചേർക്കാം.
3. [Android Studio](https://developer.android.com/studio) install ചെയ്യുക. Open ചെയ്ത ശേഷം **More Actions → SDK Manager** (അല്ലെങ്കിൽ Settings → Android SDK) തുറന്ന് SDK location ശ്രദ്ധിക്കുക. സാധാരണ സ്ഥലം `C:\Users\<WindowsUser>\AppData\Local\Android\Sdk` ആണ്.
4. Android SDK Manager-ൽ **Android 16 / API 36** platform, **Android SDK Build-Tools 36.0.0**, **Android SDK Platform-Tools**, **Android SDK Command-line Tools (latest)** install ചെയ്യുക. **Show Package Details** വഴി **NDK (Side by side) 28.2.13676358** തിരഞ്ഞെടുക്കുക. ആവശ്യപ്പെട്ടാൽ Android platform 35, CMake 3.22.1 എന്നിവയും install ചെയ്യുക.
5. JDK 21 install ചെയ്യുക; ഉദാഹരണത്തിന് [Eclipse Temurin 21](https://adoptium.net/temurin/releases/). `java -version`-ൽ 21.x കാണണം. Flutter മറ്റൊരു Java തിരഞ്ഞെടുക്കുന്നുണ്ടെങ്കിൽ, താഴെയുള്ള path നിങ്ങളുടെ യഥാർത്ഥ JDK folder ആക്കി മാറ്റി പ്രവർത്തിപ്പിക്കുക:

   ```powershell
   flutter config --jdk-dir="C:\Program Files\Eclipse Adoptium\jdk-21..."
   ```

   ഈ command **Flutter install ചെയ്തതിന് ശേഷം** പ്രവർത്തിപ്പിക്കുക. `flutter doctor -v` ഏത് Java ആണ് ഉപയോഗിക്കുന്നതെന്ന് കാണിക്കും.
6. [Flutter SDK archive](https://docs.flutter.dev/install/archive)-ൽ നിന്ന് **Flutter 3.47.9, Windows stable** download ചെയ്ത് `C:\src\flutter`-ൽ extract ചെയ്യുക. SDK നേരിട്ട് `C:\src\flutter\bin\flutter.bat` എന്ന path-ൽ ആയിരിക്കണം; അധിക `flutter\flutter` folder ഉണ്ടാകരുത്. പകരം Git ഉപയോഗിച്ച്:

   ```powershell
   git clone --branch 3.47.9 --depth 1 https://github.com/flutter/flutter.git C:\src\flutter
   ```

   Windows **Environment Variables → User variables → Path → Edit → New** വഴി `C:\src\flutter\bin` ചേർക്കുക. Terminal/Visual Studio അടച്ച് വീണ്ടും തുറക്കുക. Program Files പോലുള്ള protected folder-ൽ Flutter SDK വെക്കരുത്.

## 2. Project തുറന്ന് tools പരിശോധിക്കുക

PowerShell-ൽ project download ചെയ്യുക. ഈ branch-ലാണ് ഈ guide-ഉം നിലവിലെ മാറ്റങ്ങളും ഉള്ളത്:

```powershell
git clone --branch coderabbit/profile-coins-campaign-updates/222619c7 https://github.com/Assdhgg/jkk.git jkk
cd jkk
flutter --version
java -version
flutter doctor -v
flutter doctor --android-licenses
flutter pub get --enforce-lockfile
flutter analyze
flutter test
```

`flutter --version`-ൽ 3.47.9 ഉം Dart 3.13.7 ഉം പരിശോധിക്കുക. License prompts വന്നാൽ വായിച്ച് സ്വീകരിക്കാൻ `y` നൽകുക. `flutter doctor -v`-ൽ **Android toolchain**, **Visual Studio - develop Windows apps**, **Windows Version** എന്നിവയിലെ പ്രശ്നങ്ങൾ പരിഹരിക്കുക. Android SDK location വ്യത്യസ്തമാണെങ്കിൽ `flutter config --android-sdk="C:\path\to\Android\Sdk"` ഉപയോഗിച്ച് ശരിയായ folder തിരഞ്ഞെടുക്കുക.

Visual Studio-യിൽ **File → Open → Folder** വഴി `jkk` folder തുറക്കുക; **View → Terminal** തുറന്ന് project root-ലാണ് (`pubspec.yaml` ഉള്ള folder) എന്ന് ഉറപ്പാക്കുക. താഴെയുള്ള commands അതേ terminal-ൽ പ്രവർത്തിപ്പിക്കുക. Visual Studio solution-ലെ Build button ഉപയോഗിക്കുന്നതിനു പകരം ഈ Flutter commands ഉപയോഗിക്കുക.

## 3. Supabase project തയ്യാറാക്കുക

Android app-നും Windows admin app-നും ഒരേ Supabase project ഉപയോഗിക്കുക. Project Settings → API-യിൽ നിന്ന് **Project URL** ഉം **publishable key** (അല്ലെങ്കിൽ legacy **anon key**) ഉം എടുക്കുക. ഇവ client-ൽ ഉപയോഗിക്കുന്ന public values ആണ്. **Service-role/secret key, database password എന്നിവ app-ലോ Git-ലോ ഇടരുത്.**

പുതിയ Supabase project-ൽ Email/Password sign-in, **Confirm email**, email delivery/SMTP എന്നിവ configure ചെയ്യുക. Authentication → Email Templates → Confirm signup-ൽ verification token ഉൾപ്പെടുത്തുക; app signup-ൽ 6-digit email OTP ആണ് ഉപയോഗിക്കുന്നത്. URL Configuration-ൽ `io.supabase.growthcircle://login-callback/` അനുവദിക്കുക. കൂടുതൽ വിശദാംശങ്ങൾക്ക് root [README](../README.md#supabase-setup) കാണുക.

Supabase SQL Editor-ൽ `supabase/migrations/`-ലെ SQL files താഴെ കാണുന്ന ക്രമത്തിൽ പ്രയോഗിക്കുക:

1. `20261107000000_growth_circle.sql`
2. `20261107010000_owner_review.sql`
3. `20261107020000_admin_access.sql`
4. `20261107030000_profile_pin_referrals.sql`
5. `20261107040000_admin_action_controls.sql`
6. `20261107050000_admin_campaigns.sql`
<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:447632e64b4e814629213d1b1e2727d4c6f2a7447a09b99e442f3adf6a52ee17 -->

7. `20261107060000_admin_submission_review.sql`
<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:019eecc0633cc58dc7a1226682d738cf147684cad89c5c1fdfe2f6905c734230 -->

8. `20261107070000_instagram_lookup_rate.sql`
<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:5f8b51c05f806e2b1652efb559e07daf12681ec42ad762670b229ac749db847d -->

9. `20261107080000_notifications.sql`
<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:668f87cea98a9d8199d97e84571e6a6b3b3cefc0b194a32d2ee0de4b2d17142a -->

10. `20261107090000_coin_settings_referrals_pin_otp.sql`
11. `20261107100000_security_hardening.sql`

Security migration verified email ഉള്ള accounts-ന് മാത്രം app data/coin access നൽകും. PIN set/reset-ൽ current email-ഉം OTP proof-ഉം പരിശോധിക്കും; linked phone accounts-ന് PIN മാറ്റാൻ account support വേണം. പഴയ PIN release തുടരും. Screenshots static JPEG/PNG, 512 KiB-ൽ താഴെ, ഓരോ dimension-ഉം പരമാവധി 4096 pixels ആയിരിക്കണം. Updated user/admin builds നൽകുക. Live project access ഇവിടെ ഇല്ലാത്തതിനാൽ migration apply ചെയ്തിട്ടില്ല. വിശദാംശങ്ങൾ [security notes](../README.md#security-hardening)-ൽ ഉണ്ട്.

<!-- /coderabbit-ai-generated:v1 -->

പുതിയ migration-നൊപ്പം user/admin builds നൽകുക. Admin dashboard-ലെ **Coin settings** വഴി registration/action/referral rewards മാറ്റാം. പഴയ campaigns-ന്റെ payout/refund നിരക്ക് മാറില്ല. പുതിയ default referral reward 100 coins; 5/10/15 invites-ന് extra 100/200/300 coins. മുമ്പത്തെ referrals-ന് backfill ഇല്ല.

PIN set/reset-ന് Supabase **Authentication → Email Templates → Magic Link** template-ൽ `{{ .Token }}` നൽകി six-digit email OTP ലഭ്യമാക്കണം; signup template മാത്രം മാറ്റിയാൽ മതിയാകില്ല. Production SMTP/sending limits configure ചെയ്യുക. Profile → Coin release PIN → Change / reset PIN → Send email OTP → code + പുതിയ PIN നൽകി Save ചെയ്യുക. വിശദാംശങ്ങളും rollout നിബന്ധനകളും [README](../README.md#coin-settings-referral-rewards-and-email-otp-pin)-ൽ ഉണ്ട്. SQL commit/push ചെയ്തതുകൊണ്ട് live Supabase migration apply ആകില്ല.

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->

Instagram username lookup-ന് Meta Business Discovery credentials Supabase Edge Function-ൽ configure ചെയ്യുകയും `instagram-lookup` function deploy ചെയ്യുകയും വേണം. ഇത് full username ഉള്ള Business/Creator accounts മാത്രം പരിശോധിക്കും. Personal accounts-ന് manual add ഉപയോഗിക്കാം. വിശദമായ setup-ന് [Instagram username lookup](../README.md#instagram-username-lookup) കാണുക.

<!-- /coderabbit-ai-generated:v1 -->

ഇതിനകം ഉപയോഗിക്കുന്ന project ആണെങ്കിൽ മുൻപ് പ്രയോഗിച്ച migrations വീണ്ടും run ചെയ്യരുത്. Project-ന്റെ migration history പരിശോധിച്ച് പ്രയോഗിക്കാത്ത അടുത്ത migration മുതൽ മാത്രം തുടരുക. SQL Editor വഴി കൈകൊണ്ട് പ്രയോഗിച്ചാൽ അത് നിങ്ങളുടെ migration record-ൽ സൂക്ഷിക്കുക. Campaign, claim, wallet, ledger, action-control, admin-review presence updates-ന് Supabase Realtime publication/configuration പ്രവർത്തിക്കുന്നുണ്ടെന്ന് പരിശോധിക്കുക.

Windows admin-നായി app-ൽ ഒരു confirmed account സൃഷ്ടിച്ച ശേഷം project owner ആയി SQL Editor-ൽ താഴെയുള്ള email നിങ്ങളുടെ admin account email ആക്കി മാറ്റി run ചെയ്യുക:

```sql
insert into public.admin_members (user_id)
select id from auth.users
where lower(email) = lower('ADMIN_EMAIL_HERE')
  and email_confirmed_at is not null
on conflict (user_id) do nothing;
```

ഈ SQL confirmed account-ന് മാത്രം admin access നൽകും. App ഉപയോഗിച്ച് admin account provision ചെയ്യാനാവില്ല.

## 4. Android release APK-യ്ക്ക് signing key

ഇതിനകം ഉപയോക്താക്കൾക്ക് നൽകിയ signed app update ചെയ്യുകയാണെങ്കിൽ **അതേ keystore, alias, passwords** ഉപയോഗിക്കുക. മറ്റൊരു key ഉപയോഗിച്ച APK പഴയ installation-ന് update ആയി install ആവില്ല. Key നഷ്ടപ്പെട്ടാൽ പുതിയ key പഴയ key-യുടെ പകരമല്ല.

പഴയ signing key ഉപയോഗിക്കേണ്ടതില്ലാത്ത പുതിയ app-ന് മാത്രം ഒരു keystore സൃഷ്ടിക്കുക:

```powershell
$Keystore = Join-Path $env:USERPROFILE "growth-circle-release.jks"
keytool -genkeypair -v -keystore $Keystore -alias growth-circle -keyalg RSA -keysize 2048 -validity 10000
```

Prompts-ൽ ചോദിക്കുന്ന passwords സുരക്ഷിതമായി സൂക്ഷിക്കുക. Keystore-ഉം passwords-ഉം backup ചെയ്യുക; GitHub-ൽ upload ചെയ്യരുത്. Existing keystore ആണെങ്കിൽ മുകളിലെ create command run ചെയ്യരുത്; അതിന്റെ യഥാർത്ഥ alias ഉപയോഗിക്കുക.

Project root-ൽ നിന്ന് `notepad .\android\key.properties` പ്രവർത്തിപ്പിച്ച് file-ൽ നിങ്ങളുടെ values നൽകുക:

```properties
storeFile=C:/Users/YOUR_WINDOWS_USER/growth-circle-release.jks
storePassword=YOUR_KEYSTORE_PASSWORD
keyAlias=growth-circle
keyPassword=YOUR_KEY_PASSWORD
```

`storeFile` യഥാർത്ഥ **absolute path** ആക്കുക. Windows path-ൽ `/` ഉപയോഗിക്കുക; backslash ഉപയോഗിച്ചാൽ Java properties escaping ആവശ്യമാണ്. `keyAlias`, `keyPassword` എന്നിവ നിങ്ങളുടെ keystore-ന്റെ യഥാർത്ഥ വിവരങ്ങളാകണം. File `android/key.properties.txt` ആകരുത്. ഈ file-ഉം `*.jks`-ഉം `.gitignore`-ൽ ഉണ്ട്; commit ചെയ്യരുത്. Missing/incomplete signing വിവരങ്ങൾ ഉണ്ടെങ്കിൽ release build error കാണിക്കും.

## 5. Android APK build, verify, install

Project root terminal-ൽ public project values നൽകുക. `BuildNumber` app-ന്റെ Android version code ആണ്: ആദ്യ build-ന് 7 ഉപയോഗിക്കാം; **നിലവിലുള്ള app update ചെയ്യുമ്പോൾ ഫോണിലുള്ള version code-നേക്കാൾ കൂടുതലായ ഒരു integer നൽകണം**. പഴയ split APK-കൾക്ക് വ്യത്യസ്ത version code ഉണ്ടായിരിക്കാം.

```powershell
$ProjectUrl = "https://YOUR_PROJECT.supabase.co"
$PublicKey = "YOUR_PUBLISHABLE_OR_ANON_KEY"
$BuildNumber = 7
flutter build apk --release "--build-number=$BuildNumber" "--dart-define=SUPABASE_URL=$ProjectUrl" "--dart-define=SUPABASE_PUBLISHABLE_KEY=$PublicKey"
```

ശരിയായ URL/key ഇല്ലാതെ build ചെയ്താൽ app setup screen കാണിക്കും. വിജയിച്ചാൽ APK:

```text
build\app\outputs\flutter-apk\app-release.apk
```

മുകളിലെ command ഒരു universal APK ആണ് നിർമ്മിക്കുന്നത്; file size കൂടുതൽ ആയിരിക്കും. [Flutter Android deployment guide](https://docs.flutter.dev/deployment/android) പ്രകാരം ABI-specific builds വേണമെങ്കിൽ `--split-per-abi` ഉപയോഗിക്കാം, എന്നാൽ ഓരോ APK-ക്കും വ്യത്യസ്ത version code/architecture ഉണ്ടാകാം. Phone-ന് പൊരുത്തപ്പെടുന്ന APK മാത്രമേ ഉപയോഗിക്കാവൂ.

Android SDK default location ആണെങ്കിൽ signature പരിശോധിക്കാൻ:

```powershell
$BuildTools = Join-Path $env:LOCALAPPDATA "Android\Sdk\build-tools\36.0.0"
& "$BuildTools\apksigner.bat" verify --verbose --print-certs ".\build\app\outputs\flutter-apk\app-release.apk"
& "$BuildTools\aapt.exe" dump badging ".\build\app\outputs\flutter-apk\app-release.apk"
```

SDK വേറെ സ്ഥലത്താണെങ്കിൽ `$BuildTools` മാറ്റുക. `Verifies` കാണണം. പഴയ APK ഉണ്ടെങ്കിൽ അതിലും `apksigner verify --verbose --print-certs "C:\path\old.apk"` പ്രവർത്തിപ്പിച്ച് certificate SHA-256 fingerprint താരതമ്യം ചെയ്യുക. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:cc9d98b78a39ce4b088e3a93802f1f119cc3791eee26a9358ec130fb753026a2 -->

AAPT output-ൽ package `space.freelan.app`, version code, minimum SDK, native architectures എന്നിവ കാണാം. ഈ package പഴയ app-നെ update ചെയ്യില്ല; ആദ്യ APK പുതിയ app ആയി install ചെയ്ത് വീണ്ടും login ചെയ്യണം. Firebase Console-ൽ ഈ package രജിസ്റ്റർ ചെയ്ത് പുതിയ `google-services.json` `android/app/`-ൽ വയ്ക്കണം.

<!-- /coderabbit-ai-generated:v1 -->

Phone-ൽ Developer options → USB debugging enable ചെയ്ത് USB വഴി connect ചെയ്താൽ:

```powershell
$Adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
& $Adb devices
<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:99971ce62631fff673e8474aae0cd0bf76090bd2c0fb78103880e4e0e20720ae -->

& $Adb shell dumpsys package space.freelan.app | Select-String "versionCode"

<!-- /coderabbit-ai-generated:v1 -->
& $Adb install -r ".\build\app\outputs\flutter-apk\app-release.apk"
```

Phone-ൽ USB authorization അനുവദിക്കുക. പഴയ app ഇല്ലെങ്കിൽ `dumpsys`-ൽ version ഉണ്ടാകില്ല. `INSTALL_FAILED_UPDATE_INCOMPATIBLE` വന്നാൽ signing key, `INSTALL_FAILED_VERSION_DOWNGRADE` വന്നാൽ build number പരിശോധിക്കുക. പഴയ app uninstall ചെയ്യുന്നതിന് മുമ്പ് അതിലെ local data നഷ്ടപ്പെടാമെന്ന് ശ്രദ്ധിക്കുക.

## 6. Windows administrator app build

Visual Studio C++ workload install ചെയ്ത Windows PC-യിൽ, project root-ൽ:

```powershell
flutter build windows --release -t lib/admin_main.dart
```

വിജയിച്ചാൽ app ഇവിടെ ലഭിക്കും:

```text
build\windows\x64\runner\Release\growth_circle_admin.exe
```

ഇത് Windows **EXE** ആണ്; APK Android-നുള്ളതാണ്. `Release` folder-ലെ EXE മാത്രം copy ചെയ്യരുത്: അതിനോടൊപ്പം ഉള്ള DLL-കളും `data` folder-ഉം ഉൾപ്പെടെ മുഴുവൻ folder share ചെയ്യുക. ZIP ഉണ്ടാക്കാൻ:

```powershell
<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:4a6289eabc5726cd678045f356ff10f8ed4ebda558d86bf3f6de8ef8ded830fd -->

Compress-Archive -Path .\build\windows\x64\runner\Release\* -DestinationPath .\freelan-space-admin-windows.zip -Force

<!-- /coderabbit-ai-generated:v1 -->
```

ZIP extract ചെയ്ത് `growth_circle_admin.exe` തുറക്കുക. ആദ്യ screen-ൽ അതേ Supabase **project URL** ഉം **publishable/anon key** ഉം നൽകുക; തുടർന്ന് മുമ്പ് provision ചെയ്ത admin email/password ഉപയോഗിച്ച് sign in ചെയ്യുക. Windows build-ന് Android keystore വേണ്ടതില്ല. Admin app-ൽ user access, action controls, campaign list, pending submission inspection ലഭ്യമാണ്.

## 7. പ്രശ്നപരിഹാരം

- **`flutter` അല്ലെങ്കിൽ `git` കണ്ടെത്തുന്നില്ല:** Path ശരിയാക്കി Visual Studio/terminal വീണ്ടും തുറക്കുക; `flutter --version`, `git --version` പരിശോധിക്കുക.
- **Visual Studio toolchain missing:** Visual Studio Installer-ൽ **Desktop development with C++** workload, Windows SDK install ചെയ്ത ശേഷം `flutter doctor -v` വീണ്ടും run ചെയ്യുക.
- **Android license/SDK error:** Android Studio SDK Manager-ൽ packages install ചെയ്ത് `flutter doctor --android-licenses` run ചെയ്യുക. `flutter doctor -v` കാണിക്കുന്ന SDK/JDK paths പരിശോധിക്കുക.
- **`Release signing is required` / incomplete configuration:** `android/key.properties`, അതിലെ നാല് values, keystore path എന്നിവ പരിശോധിക്കുക. Wrong password/alias ആണെങ്കിൽ signing build പരാജയപ്പെടും.
- **`App not installed` / invalid package:** APK അപൂർണ്ണമായി transfer ചെയ്തിട്ടില്ലെന്ന് ഉറപ്പാക്കി `apksigner`, AAPT output, phone architecture/API level, പഴയ app-ന്റെ signing certificate, version code എന്നിവ താരതമ്യം ചെയ്യുക. യഥാർത്ഥ APK പരിശോധിക്കാതെ ഒറ്റ കാരണം ഉറപ്പിക്കാനാവില്ല.
- **App setup screen:** Android build-ൽ ശരിയായ `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` ഉൾപ്പെടുത്തി വീണ്ടും build ചെയ്യുക.
- **Admin sign-in denied:** confirmed account-ന് `admin_members` entry ഉണ്ടോ, എല്ലാ migrations-ഉം ശരിയായ project-ൽ പ്രയോഗിച്ചോ പരിശോധിക്കുക.

## ഔദ്യോഗിക സഹായം

- [Flutter SDK install and archive](https://docs.flutter.dev/install/archive)
- [Flutter Windows desktop setup](https://docs.flutter.dev/platform-integration/windows/setup)
- [Flutter Android setup](https://docs.flutter.dev/platform-integration/android/setup)
- [Flutter Android release and signing](https://docs.flutter.dev/deployment/android)
- [Install Visual Studio workloads](https://learn.microsoft.com/en-us/visualstudio/install/install-visual-studio)
