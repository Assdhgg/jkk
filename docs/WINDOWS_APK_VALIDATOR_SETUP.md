<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:5630fcde8587fbf2466a16f84235d443a1977cd1f80cad84171437be96337e46 -->

# Windows APK validator + Cloudflare Tunnel — പൂർണ്ണ setup guide

ഈ guide **Windows 11 x64 + Windows PowerShell 5.1 + Docker Desktop Linux containers** ഉപയോഗിച്ച് ആദ്യം മുതൽ validator ഒരുക്കുന്നതിനാണ്. മുൻപ് ചെയ്ത commands, variables, പഴയ tunnel ID, `secret.dpapi` എന്നിവ ഉണ്ടെന്ന് കരുതുന്നില്ല. Validator reset ചെയ്താലും Cloudflare DNS/tunnel, R2 bucket, Supabase migrations/secrets എന്നിവ server-ൽ ശേഷിച്ചിരിക്കാം; അവ പരിശോധിച്ച് മാത്രമേ മാറ്റാവൂ.

**ഫലം:** Supabase Edge Function → `https://validator.freelan.space/verify` → Cloudflare Tunnel → Windows `127.0.0.1:8081` → nginx → Docker network-ലെ APK validator `8080`.

APK validator APK-യുടെ SHA-256, size, production signature, package `space.freelan.app`, version code/name എന്നിവ പരിശോധിക്കും. Private signing keystore validator-ലേക്ക് കൊടുക്കേണ്ടതില്ല.

**ഈ guide GitHub-ൽ push ചെയ്തതുകൊണ്ട് setup/deployment നടക്കില്ല.** താഴെയുള്ള Windows steps നിങ്ങൾ ചെയ്യണം. അവസാനം പറയുന്ന real APK test വിജയിച്ച ശേഷമാണ് validator ആശ്രയിക്കുന്ന Edge Function deploy ചെയ്യേണ്ടത്.

## ഉള്ളടക്കം

1. [ആവശ്യമായവയും ചെലവും](#1-ആവശ്യമായവയും-ചെലവും)
2. [PowerShell തുറക്കുക; reset ശേഷമുള്ള അവസ്ഥ പരിശോധിക്കുക](#2-powershell-തുറക്കുക-reset-ശേഷമുള്ള-അവസ്ഥ-പരിശോധിക്കുക)
3. [WSL 2, Docker Desktop, Git](#3-wsl-2-docker-desktop-git)
4. [ശരിയായ repository download ചെയ്യുക; image build ചെയ്യുക](#4-ശരിയായ-repository-download-ചെയ്യുക-image-build-ചെയ്യുക)
5. [വിശ്വസനീയമായ release APK-യുടെ signer കണ്ടെത്തുക](#5-വിശ്വസനീയമായ-release-apk-യുടെ-signer-കണ്ടെത്തുക)
6. [R2 വിവരങ്ങൾ ഉറപ്പാക്കുക](#6-r2-വിവരങ്ങൾ-ഉറപ്പാക്കുക)
7. [Private settings, പുതിയ secret](#7-private-settings-പുതിയ-secret)
8. [Validator container തുടങ്ങുക](#8-validator-container-തുടങ്ങുക)
9. [nginx proxy build ചെയ്ത് തുടങ്ങുക](#9-nginx-proxy-build-ചെയ്ത്-തുടങ്ങുക)
10. [Cloudflare login, tunnel, DNS, configuration](#10-cloudflare-login-tunnel-dns-configuration)
11. [Tunnel തുടങ്ങുക; public HTTPS പരിശോധിക്കുക](#11-tunnel-തുടങ്ങുക-public-https-പരിശോധിക്കുക)
12. [Supabase secrets നൽകുക](#12-supabase-secrets-നൽകുക)
13. [യഥാർഥ APK + R2 ഉപയോഗിച്ചുള്ള പരിശോധന](#13-യഥാർഥ-apk--r2-ഉപയോഗിച്ചുള്ള-പരിശോധന)
14. [Migration പരിശോധിക്കുക; Edge Function deploy ചെയ്യുക](#14-migration-പരിശോധിക്കുക-edge-function-deploy-ചെയ്യുക)
15. [യഥാർഥ publishing, referral sharing പരിശോധിക്കുക](#15-യഥാർഥ-publishing-referral-sharing-പരിശോധിക്കുക)
16. [Restart, login സമയത്തെ startup, stop](#16-restart-login-സമയത്തെ-startup-stop)
17. [പ്രശ്നപരിഹാരം](#17-പ്രശ്നപരിഹാരം)
18. [Backup, secret rotation, final checklist](#18-backup-secret-rotation-final-checklist)

## 1. ആവശ്യമായവയും ചെലവും

- പിന്തുണയുള്ള Windows 11 x64, BIOS/UEFI virtualization enabled, WSL 2. Docker-ന്റെ നിലവിലെ [Windows requirements](https://docs.docker.com/desktop/setup/install/windows-install/) പരിശോധിക്കുക. ഈ guide ARM/32-bit Windows commands അല്ല.
- Docker Desktop-നും validator-നും മതിയായ RAM/disk: Docker-ന് കുറഞ്ഞത് 4 GB RAM അനുവദിക്കുന്നത് പ്രായോഗികമാണ്; Windows-ന് ആവശ്യമായ RAM വേറെയും വേണം. Validator-ന് ഈ guide 2 GB RAM, 768 MiB temporary space അനുവദിക്കുന്നു. APK limit 200 MiB ആണ്.
- Internet, Cloudflare account, Cloudflare-ൽ **Active** ആയ `freelan.space` domain, ആ zone മാറ്റാനുള്ള permission.
- നിലവിലുള്ള R2 bucket `freelan-space-apk`, അതിന്റെ account ID, bucket-നു മാത്രമുള്ള Object Read & Write credentials, public APK download domain.
- Supabase project-ന്റെ Owner/Administrator dashboard access; app-ൽ editor administrator + MFA access. ഈ project reference: `stpxbshwdiupigymakfy`.
- സ്വന്തമായി നിയന്ത്രിക്കുന്ന **release keystore ഉപയോഗിച്ച് build ചെയ്ത, വിശ്വസനീയമായ universal APK**. Keystore/password backup വേണം. Validator ഉപയോഗിക്കുന്ന PC-ൽ Flutter/JDK വേണമെന്നില്ല; APK നേരത്തെ build ചെയ്തതാകാം.
- Windows-ൽ ഒരേ user account ഉപയോഗിക്കുക. DPAPI encrypted secret മറ്റൊരു PC/user-ലേക്ക് സാധാരണ copy ചെയ്ത് decrypt ചെയ്യാനാകില്ല.

Validator-ന് പ്രത്യേക paid server/card വേണ്ട: നിങ്ങളുടെ PC-ലാണ് അത് പ്രവർത്തിക്കുന്നത്. നിലവിലുള്ള domain, internet/electricity, R2/Supabase usage, Docker Desktop license eligibility എന്നിവയുടെ ചെലവും നിബന്ധനകളും വേറെയാണ്. R2 പുതിയതായി activate ചെയ്യാൻ billing setup ചോദിക്കാം; അതിനെ ഈ guide ഒഴിവാക്കുന്നില്ല. [Docker Desktop license](https://docs.docker.com/subscription/desktop-license/), [R2 pricing](https://developers.cloudflare.com/r2/pricing/) കാണുക.

**Publishing സമയത്ത് PC awake, internet connected, Docker Desktop running, tunnel running ആയിരിക്കണം.** Downloads ഇതിനകം R2-ൽ ഉള്ളതിനാൽ published APK download ചെയ്യാൻ ഈ PC ആവശ്യമില്ല. PC off ആണെങ്കിൽ പുതിയ publishing പരാജയപ്പെടും.

## 2. PowerShell തുറക്കുക; reset ശേഷമുള്ള അവസ്ഥ പരിശോധിക്കുക

1. **Start** അമർത്തുക → `Windows PowerShell` type ചെയ്യുക → തുറക്കുക. WSL install ചെയ്യുമ്പോൾ മാത്രം **Run as administrator** വേണം; സാധാരണ commands നിങ്ങളുടെ Windows user-ന്റെ PowerShell-ലാണ്.
2. Code block-ലെ commands മാത്രം copy ചെയ്യുക. `PS C:\...>`, `>>`, error output, Markdown-ലെ ``` എന്നിവ copy ചെയ്യരുത്. `[redacted]` ഉള്ള command ഉപയോഗിക്കരുത്.
3. ഒരു മുഴുവൻ block paste ചെയ്ത് Enter അമർത്തുക. `>>`-ൽ കുടുങ്ങിയാൽ **Ctrl+C** അമർത്തി സാധാരണ `PS ...>` prompt കിട്ടിയ ശേഷം മുഴുവൻ block വീണ്ടും paste ചെയ്യുക.
4. Command error വന്നാൽ അടുത്ത step ചെയ്യാതെ [പ്രശ്നപരിഹാരം](#17-പ്രശ്നപരിഹാരം) കാണുക. Screenshot-ൽ secrets കാണിക്കരുത്.

Docker മുമ്പ് install ചെയ്തിട്ടുണ്ടെങ്കിൽ അത് തുറന്ന് engine ready ആയശേഷം:

```powershell
docker ps -a --filter 'name=freelan-apk-validator' --format '{{.Names}} {{.Status}}'
docker ps -a --filter 'name=freelan-validator-proxy' --format '{{.Names}} {{.Status}}'
```

Output ശൂന്യമാണെങ്കിൽ ആ containers ഇല്ല. Fresh setup-നു മുമ്പ് പഴയ **ഈ രണ്ടു named containers മാത്രം** നീക്കേണ്ടതുണ്ടെങ്കിൽ, അവ ഉപയോഗിച്ചുള്ള publishing ഒന്നും നടക്കുന്നില്ലെന്ന് ഉറപ്പാക്കി ഓരോ existing container-നും അനുയോജ്യമായ command ഓടിക്കുക:

```powershell
docker rm -f freelan-validator-proxy
docker rm -f freelan-apk-validator
```

`No such container` വന്നാൽ അത് നേരത്തേ ഇല്ലാതായതാണ്. എല്ലാ Docker containers/volumes-ഉം delete ചെയ്യുന്ന reset/prune commands വേണ്ട. പഴയ tunnel PowerShell window running ആണെങ്കിൽ Ctrl+C കൊണ്ട് നിർത്തുക. മുമ്പ് Windows service ആയി install ചെയ്തിട്ടുണ്ടെങ്കിൽ `Get-Service cloudflared -ErrorAction SilentlyContinue` കൊണ്ട് പരിശോധിച്ച് ആ service-നും ഇതേ validator-നുമായി ബന്ധമുണ്ടെന്ന് ഉറപ്പാക്കിയശേഷം മാത്രം administrator PowerShell-ൽ `Stop-Service cloudflared` ചെയ്യുക; unrelated service മാറ്റരുത്.

**Release keystore, R2 `releases/`, Supabase release history/migrations, മറ്റുള്ള DNS records എന്നിവ reset ചെയ്യരുത്.** Local validator reset-നു database reset ആവശ്യമില്ല. പുതിയ secret ഉണ്ടാക്കിയാൽ Supabase-ലും അതേ പുതിയ secret മാറ്റേണ്ടിവരും.

## 3. WSL 2, Docker Desktop, Git

### 3.1 WSL

Administrator PowerShell-ൽ:

```powershell
wsl --status
wsl --version
```

WSL install ചെയ്തിട്ടില്ലെങ്കിൽ:

```powershell
wsl --install
```

ആവശ്യപ്പെട്ടാൽ restart ചെയ്യുക. Ubuntu setup ചോദിച്ചാൽ local Linux username/password സൃഷ്ടിക്കുക. തുടർന്ന് administrator PowerShell-ൽ:

```powershell
wsl --update
wsl --set-default-version 2
wsl --list --verbose
```

Distro-യുടെ VERSION `1` ആണെങ്കിൽ list-ൽ കാണുന്ന exact distro name ഉപയോഗിച്ച് `wsl --set-version Ubuntu 2` ചെയ്യുക. Virtualization error വന്നാൽ BIOS/UEFI-യിൽ virtualization enable ചെയ്ത് restart ചെയ്യുക. [Microsoft WSL install guide](https://learn.microsoft.com/en-us/windows/wsl/install) കാണുക.

### 3.2 Docker Desktop

1. [Official Docker Desktop Windows installer](https://docs.docker.com/desktop/setup/install/windows-install/) download ചെയ്ത് install ചെയ്യുക; WSL 2 backend തിരഞ്ഞെടുക്കുക.
2. ആവശ്യപ്പെട്ട restart പൂർത്തിയാക്കി Docker Desktop തുറക്കുക. License terms പരിശോധിച്ച് accept ചെയ്യുക. Local images build/run ചെയ്യാൻ Docker Hub account നിർബന്ധമല്ല; sign-in ആവശ്യപ്പെടുന്ന optional screen skip ചെയ്യാം.
3. **Settings → General → Use the WSL 2 based engine** enable ചെയ്യുക. **Start Docker Desktop when you sign in** enable ചെയ്യാം. Linux containers mode ആയിരിക്കണം; Docker menu-ൽ “Switch to Linux containers” കാണുന്നുവെങ്കിൽ അത് തിരഞ്ഞെടുക്കുക.
4. Engine ready ആയശേഷം പുതിയ സാധാരണ PowerShell-ൽ:

```powershell
docker version
docker info --format '{{.OSType}}'
docker run --rm hello-world
```

Server version കാണണം, OS `linux` ആയിരിക്കണം, hello-world വിജയിക്കണം. `docker version`-ൽ client മാത്രം വന്നാൽ engine ready അല്ല.

### 3.3 Git

[Git for Windows](https://git-scm.com/downloads/win) install ചെയ്യുക; installer-ൽ Git command line/PATH option enable ചെയ്യുക. PowerShell അടച്ച് വീണ്ടും തുറന്ന്:

```powershell
git --version
curl.exe --version
```

ഈ guide-ൽ `curl.exe` എന്നാണ്; PowerShell-ന്റെ `curl` alias അല്ല.

## 4. ശരിയായ repository download ചെയ്യുക; image build ചെയ്യുക

Fresh clone-നായി:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\source" | Out-Null
git clone --branch coderabbit/referral-share-download-link/4eac8d7b --single-branch https://github.com/opiu91/jkk.git "$env:USERPROFILE\source\freelan-validator"
```

Folder നേരത്തേ ഉണ്ടെങ്കിൽ clone ആവർത്തിക്കരുത്. അതിലെ `git status` പരിശോധിക്കുക; local changes ഇല്ലെങ്കിൽ മാത്രം ഈ task branch checkout ചെയ്ത് `git pull --ff-only` ചെയ്യുക. മറ്റൊരു project folder delete ചെയ്ത് ഇടം ഉണ്ടാക്കരുത്. GitHub authentication ചോദിച്ചാൽ Git Credential Manager/browser flow ഉപയോഗിക്കുക; token URL/command-ൽ ഇടരുത്.

```powershell
Set-Location "$env:USERPROFILE\source\freelan-validator"
git branch --show-current
Test-Path .\services\apk-validator\Dockerfile
docker build -t freelan-apk-validator .\services\apk-validator
```

Branch `coderabbit/referral-share-download-link/4eac8d7b`, Test-Path `True`, build successful ആയിരിക്കണം. Build Java, Python, `apksigner`, `aapt`, Gunicorn എന്നിവ image-ൽ install ചെയ്യും. Windows-ൽ Python/Android SDK install ചെയ്യേണ്ടതില്ല. ഈ image source: [Dockerfile](../services/apk-validator/Dockerfile), [validator.py](../services/apk-validator/validator.py).

## 5. വിശ്വസനീയമായ release APK-യുടെ signer കണ്ടെത്തുക

APK ഇല്ലെങ്കിൽ ആദ്യം [Android release signing/build instructions](../README.md#android-release-signing), [Malayalam build guide](VISUAL_STUDIO_BUILD_GUIDE.md) അനുസരിച്ച് **release keystore** configure ചെയ്ത് universal `app-release.apk` build ചെയ്യുക. Keystore/password Git-ൽ ഇടരുത്. Android package `space.freelan.app` ആയിരിക്കണം.

നിങ്ങൾ ഇതിനുമുമ്പ് സ്ഥിരീകരിച്ചത്: users ഇതുവരെ app install ചെയ്തിട്ടില്ല; പുതിയ release signing key ഉപയോഗിക്കാം. അതിനാൽ സ്വന്തമായി build ചെയ്ത പുതിയ production APK-യുടെ signer തിരഞ്ഞെടുക്കാം. **ഇനി വരുന്ന എല്ലാ updates-നും ആ keystore തന്നെ സൂക്ഷിച്ച് ഉപയോഗിക്കുക.** മറ്റൊരു signer ഉള്ള installed app-നെ ഈ key update ചെയ്യില്ല; debug signer-ഉം പരിചയമില്ലാത്ത uploaded APK-യും trust ചെയ്യരുത്. നിലവിലുള്ള published R2 files overwrite ചെയ്യരുത്.

താഴത്തെ ഓരോ command-ലും APK ഉള്ള **folder** ചോദിക്കുമ്പോൾ ഉദാഹരണം `C:\Users\VICTUS\Downloads\my-project\build\app\outputs\flutter-apk` നൽകുക; quotes ചുറ്റേണ്ട. ആ folder-ൽ file name `app-release.apk` ആയിരിക്കണം.

```powershell
& {
  $ErrorActionPreference = 'Stop'
  $folder = (Read-Host 'Folder containing trusted app-release.apk').Trim().Trim('"')
  if (-not (Test-Path -LiteralPath (Join-Path $folder 'app-release.apk') -PathType Leaf)) { throw 'APK not found' }
  docker run --rm --network none --mount "type=bind,source=$folder,target=/apk,readonly" --entrypoint /usr/bin/apksigner freelan-apk-validator verify --verbose --print-certs /apk/app-release.apk
  if ($LASTEXITCODE -ne 0) { throw 'APK signature check failed' }
  docker run --rm --network none --mount "type=bind,source=$folder,target=/apk,readonly" --entrypoint /usr/bin/aapt freelan-apk-validator dump badging /apk/app-release.apk
  if ($LASTEXITCODE -ne 0) { throw 'APK metadata check failed' }
}
```

Expected:

- `Verifies`, `Number of signers: 1`.
- `Signer #1 certificate SHA-256 digest:` എന്ന വരിയിലെ **64 hex characters** സൂക്ഷിക്കുക. Certificate SHA-256 ആണ് വേണ്ടത്; APK file SHA-256, SHA-1, public key digest എന്നിവയല്ല.
- `package: name='space.freelan.app' versionCode='...' versionName='...'` ശരിയായിരിക്കണം. ഈ exact version code/name ആണ് publishing-ൽ നൽകേണ്ടത്.
- `v1: false`, `v3: false` മാത്രം error അല്ല; overall verification വിജയിക്കണം. Verification fail ചെയ്ത APK തുടർന്നുപയോഗിക്കരുത്.

## 6. R2 വിവരങ്ങൾ ഉറപ്പാക്കുക

Cloudflare Dashboard-ൽ ശരിയായ account → **R2 Object Storage**:

1. **Account ID** copy ചെയ്യുക: 32 hexadecimal characters; tunnel UUID അല്ല, zone ID അല്ല. R2 S3 endpoint `<account-id>.r2.cloudflarestorage.com`-ലുള്ള ID ആണ് വേണ്ടത്.
2. `freelan-space-apk` bucket നിലവിലുണ്ടെന്ന് പരിശോധിക്കുക. ഇല്ലെങ്കിൽ Standard bucket ആ പേരിൽ സൃഷ്ടിക്കുക.
3. Bucket **Settings → Custom Domains**-ൽ നിലവിലുള്ള APK download hostname active ആണെന്ന് ഉറപ്പാക്കുക; ഇല്ലെങ്കിൽ zone-ലുള്ള ഒരു dedicated hostname connect ചെയ്യുക. ഉദാഹരണം `https://updates.freelan.space`; നിലവിൽ ഉപയോഗിക്കുന്ന മറ്റൊരു domain ഉണ്ടെങ്കിൽ അതു തന്നെ ഉപയോഗിക്കുക. **`validator.freelan.space` bucket download hostname ആക്കരുത്.**
4. Bucket lifecycle-ൽ **prefix `staging/` മാത്രം** ഒരു ദിവസത്തിനു ശേഷം delete ചെയ്യുന്ന rule സൃഷ്ടിക്കുക. `releases/` expire/delete ചെയ്യുന്ന rule പാടില്ല.
5. **Manage R2 API tokens → Create API token → Object Read & Write**, ഈ bucket മാത്രം തിരഞ്ഞെടുക്കുക. Existing Edge Function-ന്റെ valid credentials നിലനിൽക്കുന്നുവെങ്കിൽ മാറ്റേണ്ടതില്ല. Section 13 test-നായി വേറെ temporary, bucket-scoped token സൃഷ്ടിക്കാം; അതിന് നിലവിലെ Edge secrets മാറ്റേണ്ടതില്ല.
6. Access Key ID/Secret Access Key private password manager-ൽ സൂക്ഷിക്കുക; secret key creation കഴിഞ്ഞാൽ വീണ്ടും കാണാനാവണമെന്നില്ല. Chat/screenshot/Git-ൽ ഇടരുത്.

Bucket public APK download അനുവദിക്കുന്നതും public writes അനുവദിക്കാത്തതും ഉറപ്പാക്കുക. Account dashboard access/R2 write token ഉള്ളവർ release objects നേരിട്ട് മാറ്റാൻ കഴിയും; അവ നിയന്ത്രിക്കുക. കൂടുതൽ: [R2 public buckets](https://developers.cloudflare.com/r2/buckets/public-buckets/), [R2 tokens](https://developers.cloudflare.com/r2/api/tokens/).

## 7. Private settings, പുതിയ secret

സാധാരണ PowerShell-ൽ **മുഴുവൻ block** ഓടിക്കുക. ഇത് protected local folder സൃഷ്ടിച്ച് CSPRNG ഉപയോഗിച്ച് 64-character secret generate ചെയ്ത് **Windows DPAPI encrypted രൂപത്തിൽ മാത്രം** file-ൽ സൂക്ഷിക്കും. Secret terminal-ൽ print ചെയ്യില്ല. ചോദിക്കുമ്പോൾ section 5-ലെ trusted certificate SHA-256, section 6-ലെ R2 account ID നൽകുക.

```powershell
& {
  $ErrorActionPreference = 'Stop'
  $folder = Join-Path $env:LOCALAPPDATA 'FreelanValidator'
  New-Item -ItemType Directory -Force -Path $folder | Out-Null
  $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  icacls.exe $folder /inheritance:r /grant:r "*${sid}:(OI)(CI)F" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Private folder permissions failed' }
  $secretFile = Join-Path $folder 'secret.dpapi'
  $settingsFile = Join-Path $folder 'validator.env'
  if ((Test-Path $secretFile) -or (Test-Path $settingsFile)) { throw 'Settings already exist; use the recovery section instead of overwriting' }
  $account = (Read-Host 'R2 account ID (32 hex characters)').Trim().ToLowerInvariant()
  $signer = (Read-Host 'Trusted certificate SHA-256 (64 hex, no colons)').Trim().ToLowerInvariant()
  if ($account -notmatch '^[a-f0-9]{32}$') { throw 'Invalid R2 account ID' }
  if ($signer -notmatch '^[a-f0-9]{64}$') { throw 'Invalid certificate fingerprint' }
  $bytes = New-Object byte[] 32
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
  $plain = [BitConverter]::ToString($bytes).Replace('-', '').ToLowerInvariant()
  $secure = ConvertTo-SecureString -String $plain -AsPlainText -Force
  ConvertFrom-SecureString -SecureString $secure | Set-Content -LiteralPath $secretFile -Encoding Ascii
  @("APK_SIGNER_SHA256=$signer", "R2_DOWNLOAD_HOST=$account.r2.cloudflarestorage.com", 'R2_BUCKET=freelan-space-apk') | Set-Content -LiteralPath $settingsFile -Encoding Ascii
  $plain = $null
  [Array]::Clear($bytes, 0, $bytes.Length)
  $secure.Dispose()
  Write-Host 'Settings ready'
}
```

Expected: `Settings ready`. Files:

| File | ഉള്ളടക്കം |
| --- | --- |
| `%LOCALAPPDATA%\FreelanValidator\secret.dpapi` | ഈ Windows user-ന് decrypt ചെയ്യാവുന്ന encrypted secret |
| `%LOCALAPPDATA%\FreelanValidator\validator.env` | signer fingerprint, R2 host, bucket; plaintext shared secret ഇല്ല |

ഇവ repository-ക്ക് പുറത്താണ്. DPAPI file-ന്റെ ഉള്ളടക്കം Supabase secret ആയി paste ചെയ്യരുത്; section 12 plaintext terminal-ൽ കാണിക്കാതെ clipboard-ലേക്ക് copy ചെയ്യും. Docker container environment-ൽ secret സൂക്ഷിക്കപ്പെടും; Docker administrator-ക്ക് അത് വായിക്കാൻ കഴിയും. `docker inspect`-ന്റെ മുഴുവൻ output share ചെയ്യരുത്.

## 8. Validator container തുടങ്ങുക

Docker network ഉണ്ടോ എന്ന് പരിശോധിക്കുക:

```powershell
docker network ls --filter 'name=^freelan-validator-net$' --format '{{.Name}}'
```

Output ഇല്ലെങ്കിൽ മാത്രം:

```powershell
docker network create freelan-validator-net
```

താഴെയുള്ള block ഓരോ തവണയും DPAPI file-ൽ നിന്ന് secret വായിക്കുന്നു; പഴയ PowerShell variables ആവശ്യമില്ല. Named container മുമ്പേ ഉണ്ടെങ്കിൽ section 17 കാണുക; duplicate run ചെയ്യരുത്.

```powershell
& {
  $ErrorActionPreference = 'Stop'
  $folder = Join-Path $env:LOCALAPPDATA 'FreelanValidator'
  $secure = ConvertTo-SecureString -String ((Get-Content -Raw -LiteralPath (Join-Path $folder 'secret.dpapi')).Trim())
  if ($secure.Length -ne 64) { throw 'Invalid saved secret' }
  $name = 'VALIDATOR_' + 'SECRET'
  $envPath = 'Env:' + $name
  if (Test-Path $envPath) { throw 'Validator environment already set; open a fresh PowerShell' }
  $pointer = [IntPtr]::Zero
  try {
    $pointer = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    Set-Item -Path $envPath -Value ([System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer))
    docker run -d --name freelan-apk-validator --restart unless-stopped --network freelan-validator-net --read-only --tmpfs '/tmp:rw,nosuid,nodev,size=768m,mode=1777' --memory=2g --cpus=2 --pids-limit=128 --cap-drop=ALL --security-opt=no-new-privileges --env-file "$folder\validator.env" --env $name freelan-apk-validator
    if ($LASTEXITCODE -ne 0) { throw 'Validator container start failed' }
  } finally {
    if ($pointer -ne [IntPtr]::Zero) { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
    Remove-Item -Path $envPath -ErrorAction SilentlyContinue
    $secure.Dispose()
  }
}
```

Container ID വന്നത് മാത്രം readiness അല്ല. തുടർന്ന്:

```powershell
docker ps --filter 'name=^/freelan-apk-validator$' --format '{{.Names}} {{.Status}}'
docker exec freelan-apk-validator id -u
docker exec freelan-apk-validator python -c "import http.client; c=http.client.HTTPConnection('127.0.0.1',8080,timeout=5); c.request('POST','/verify','{}'); print('Status:',c.getresponse().status)"
docker exec freelan-apk-validator python -c "import http.client,os; c=http.client.HTTPConnection('127.0.0.1',8080,timeout=5); c.request('POST','/verify','{}',{'Authorization':'Bearer '+os.environ['VALIDATOR_SECRET'],'Content-Type':'application/json'}); print('Status:',c.getresponse().status)"
```

Expected: container `Up ...`, UID `1000`, first POST **401**, second POST **422**. 401 = missing auth rejected; 422 = correct auth accepted, invalid `{}` metadata rejected. ഇവ യഥാർഥ APK verification അല്ല. Validator-ന് host port mapping ഇല്ല; നേരിട്ട് internet-ൽ expose ചെയ്യരുത്.

## 9. nginx proxy build ചെയ്ത് തുടങ്ങുക

ഇത് 16 KiB body limit, പരമാവധി 2 concurrent requests, bounded timeouts എന്നിവ നൽകുന്നു. Build folder private secret folder-ൽ നിന്ന് വേറെയാണ്.

### 9.1 Configuration files സൃഷ്ടിക്കുക

Single-quoted here-string `@' ... '@` അതേപടി copy ചെയ്യുക; closing `'@` പുതിയ വരിയിൽ ഇടതുവശത്ത് വേണം. `$server_name`, `$validator_backend` nginx variables ആണ്; PowerShell expand ചെയ്യരുത്.

```powershell
& {
  $ErrorActionPreference = 'Stop'
  $folder = Join-Path $env:LOCALAPPDATA 'FreelanValidatorProxy'
  New-Item -ItemType Directory -Force -Path $folder | Out-Null
  @'
worker_processes 1;
pid /tmp/nginx.pid;
events { worker_connections 64; }
http {
  access_log off;
  error_log /dev/stderr error;
  server_tokens off;
  client_max_body_size 16k;
  client_body_timeout 15s;
  send_timeout 30s;
  client_body_temp_path /tmp/client_temp;
  proxy_temp_path /tmp/proxy_temp;
  fastcgi_temp_path /tmp/fastcgi_temp;
  uwsgi_temp_path /tmp/uwsgi_temp;
  scgi_temp_path /tmp/scgi_temp;
  resolver 127.0.0.11 valid=10s ipv6=off;
  limit_conn_zone $server_name zone=validator_limit:1m;
  server {
    listen 8080;
    server_name validator.freelan.space;
    limit_conn validator_limit 2;
    limit_conn_status 503;
    location = /verify {
      limit_except POST { deny all; }
      set $validator_backend http://freelan-apk-validator:8080;
      proxy_pass $validator_backend;
      proxy_connect_timeout 5s;
      proxy_send_timeout 30s;
      proxy_read_timeout 115s;
    }
    location / { return 404; }
  }
}
'@ | Set-Content -LiteralPath (Join-Path $folder 'nginx.conf') -Encoding Ascii
  @('FROM nginxinc/nginx-unprivileged:1.28-alpine', 'USER root', 'COPY nginx.conf /etc/nginx/nginx.conf', 'RUN chmod 644 /etc/nginx/nginx.conf', 'USER 101') | Set-Content -LiteralPath (Join-Path $folder 'Dockerfile') -Encoding Ascii
  Write-Host 'Proxy files ready'
}
```

### 9.2 Build, syntax test

```powershell
docker build -t freelan-validator-proxy "$env:LOCALAPPDATA\FreelanValidatorProxy"
docker run --rm --network freelan-validator-net --read-only --tmpfs '/tmp:rw,nosuid,nodev,size=32m,mode=1777' --cap-drop=ALL --security-opt=no-new-privileges freelan-validator-proxy nginx -t
```

Build വിജയിക്കുകയും `syntax is ok`, `test is successful` വരികയും വേണം. Entry-point-ൽ read-only `default.conf` modify ചെയ്യാനാകില്ലെന്ന informational message വരാം; അവസാന nginx test success ആണ് വേണ്ടത്.

### 9.3 Proxy തുടങ്ങുക

```powershell
docker run -d --name freelan-validator-proxy --restart unless-stopped --network freelan-validator-net --read-only --tmpfs '/tmp:rw,nosuid,nodev,size=32m,mode=1777' --memory=128m --cpus=0.5 --pids-limit=64 --cap-drop=ALL --security-opt=no-new-privileges -p 127.0.0.1:8081:8080 freelan-validator-proxy
docker ps --filter 'name=^/freelan-validator-proxy$' --format '{{.Names}} {{.Status}}'
docker exec freelan-validator-proxy id -u
```

Expected `Up ...`, UID `101`. Port **127.0.0.1:8081 മാത്രം** bind ചെയ്യണം; `-p 8081:8080`, router port forwarding, Windows firewall public inbound rule എന്നിവ ഉപയോഗിക്കരുത്.

### 9.4 Local HTTP tests

```powershell
curl.exe --max-time 10 -s -o NUL -w 'Status: %{http_code}\n' -X POST http://127.0.0.1:8081/verify
curl.exe --max-time 10 -s -o NUL -w 'Status: %{http_code}\n' http://127.0.0.1:8081/
docker exec freelan-apk-validator python -c "import http.client; c=http.client.HTTPConnection('freelan-validator-proxy',8080,timeout=10); c.request('POST','/verify',b'x'*16385); print('Status:',c.getresponse().status)"
```

Expected, അതേ ക്രമത്തിൽ: **401**, **404**, **413**. `000`, 502, 503 എന്നിവ success അല്ല. Browser address bar-ൽ `/verify` തുറക്കുന്നത് GET ആണ്; അതുകൊണ്ട് POST verification test ആകുന്നില്ല.

## 10. Cloudflare login, tunnel, DNS, configuration

Official workflow: [Create a locally managed tunnel](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/local-management/create-local-tunnel/), [configuration and ingress](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/local-management/configuration-file/).

### 10.1 cloudflared install

[Official downloads](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/downloads/) → Windows **amd64/x86-64** → `cloudflared-windows-amd64.exe` download ചെയ്യുക. File name മാറിയാൽ ആദ്യം `cloudflared-windows-amd64.exe` എന്ന് rename ചെയ്ത് Downloads-ൽ വയ്ക്കുക. തുടർന്ന്:

```powershell
New-Item -ItemType Directory -Force "$env:LOCALAPPDATA\FreelanTools" | Out-Null
Copy-Item -LiteralPath "$env:USERPROFILE\Downloads\cloudflared-windows-amd64.exe" -Destination "$env:LOCALAPPDATA\FreelanTools\cloudflared.exe"
& "$env:LOCALAPPDATA\FreelanTools\cloudflared.exe" --version
```

ഇനി executable സ്ഥിരമായ folder-ലാണ്; Downloads-ലെ file move/delete ചെയ്താലും setup നിലനിൽക്കും.

### 10.2 Login

```powershell
& "$env:LOCALAPPDATA\FreelanTools\cloudflared.exe" tunnel login
```

Browser-ൽ Cloudflare login → `freelan.space` തിരഞ്ഞെടുക്കുക → **Authorize**. PowerShell-ൽ successfully logged in / certificate saved വരണം. `%USERPROFILE%\.cloudflared\cert.pem` private ആണ്. Existing valid cert already exists എന്ന് പറഞ്ഞാൽ അത് overwrite/delete ചെയ്യാതെ താഴത്തെ list command ഉപയോഗിച്ച് പ്രവർത്തിക്കുന്നുവോ പരിശോധിക്കുക.

### 10.3 Reset ശേഷം പഴയ tunnel ഉണ്ടോ?

```powershell
& "$env:LOCALAPPDATA\FreelanTools\cloudflared.exe" tunnel list
Get-ChildItem "$env:USERPROFILE\.cloudflared" -Filter '*.json' -ErrorAction SilentlyContinue | Select-Object Name
```

- പഴയ validator tunnel **ഉം അതിന്റെ `<UUID>.json` file-ഉം** ഉണ്ടെങ്കിൽ അവ തന്നെ ഉപയോഗിക്കാം; create വീണ്ടും വേണ്ട.
- Tunnel ഒന്നുമില്ലെങ്കിൽ:

```powershell
& "$env:LOCALAPPDATA\FreelanTools\cloudflared.exe" tunnel create freelan-validator
```

- പഴയ `freelan-validator` Cloudflare-ൽ ഉണ്ടെങ്കിലും local credentials JSON നഷ്ടമായെങ്കിൽ അതേ name ഉപയോഗിച്ച് create വിജയിക്കില്ല. JSON-ന്റെ private backup ഉണ്ടെങ്കിൽ original location-ലേക്ക് restore ചെയ്യാം. ഇല്ലെങ്കിൽ **പുതിയ unique name** ഉപയോഗിക്കുക, ഉദാഹരണം:

```powershell
& "$env:LOCALAPPDATA\FreelanTools\cloudflared.exe" tunnel create freelan-validator-windows
```

ആ name-ഉം exists ആണെങ്കിൽ മറ്റൊരു unique suffix തിരഞ്ഞെടുക്കുക. Create output-ലെ **പുതിയ tunnel UUID** രേഖപ്പെടുത്തുക. ഈ guide-ലെ commands UUID prompt-ൽ അത് ചോദിക്കും; പഴയ screenshots-ലെ UUID hardcode ചെയ്യരുത്. JSON file മറ്റൊരാളുമായി share ചെയ്യരുത്. Unrelated tunnels delete ചെയ്യരുത്.

### 10.4 YAML file സ്വയം സൃഷ്ടിക്കുക

```powershell
& {
  $ErrorActionPreference = 'Stop'
  $id = (Read-Host 'Tunnel UUID to use').Trim().ToLowerInvariant()
  if ($id -notmatch '^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$') { throw 'Invalid tunnel UUID' }
  $credentials = Join-Path "$env:USERPROFILE\.cloudflared" "$id.json"
  if (-not (Test-Path -LiteralPath $credentials -PathType Leaf)) { throw 'Tunnel credentials JSON missing' }
  $credentials = $credentials.Replace('\', '/')
  @("tunnel: $id", "credentials-file: '$credentials'", 'ingress:', '  - hostname: validator.freelan.space', '    service: http://127.0.0.1:8081', '  - service: http_status:404') | Set-Content -LiteralPath "$env:USERPROFILE\.cloudflared\freelan-validator.yml" -Encoding Ascii
  Write-Host 'Tunnel config saved'
}
```

```powershell
& "$env:LOCALAPPDATA\FreelanTools\cloudflared.exe" tunnel --config "$env:USERPROFILE\.cloudflared\freelan-validator.yml" ingress validate
& "$env:LOCALAPPDATA\FreelanTools\cloudflared.exe" tunnel --config "$env:USERPROFILE\.cloudflared\freelan-validator.yml" ingress rule https://validator.freelan.space/verify
```

Expected **OK**, request `validator.freelan.space` rule-ലേക്ക് match ചെയ്യണം; catch-all 404-ലേക്ക് അല്ല.

### 10.5 DNS route

```powershell
& {
  $id = (Read-Host 'Same tunnel UUID').Trim()
  & "$env:LOCALAPPDATA\FreelanTools\cloudflared.exe" tunnel route dns $id validator.freelan.space
  if ($LASTEXITCODE -ne 0) { throw 'Check the existing validator DNS record as described below' }
}
```

“Added CNAME” അല്ലെങ്കിൽ already correct route വരണം. **Existing record conflict** വന്നാൽ Cloudflare Dashboard → `freelan.space` → **DNS → Records**-ൽ `validator` എന്ന exact record മാത്രം പരിശോധിക്കുക:

- Already selected UUID-യുടെ `<UUID>.cfargotunnel.com` ആണെങ്കിൽ മാറ്റം വേണ്ട.
- Reset-ന് മുമ്പുള്ള പഴയ validator UUID ആണെങ്കിൽ, അത് ഇനി ഉപയോഗിക്കുന്നില്ലെന്ന് ഉറപ്പാക്കി **ആ `validator` record മാത്രം** പുതിയ `<UUID>.cfargotunnel.com` target ഉള്ള **CNAME**, Proxy status **Proxied**, TTL Auto ആയി update ചെയ്യുക.
- അതേ hostname-ൽ conflicting A/AAAA/CNAME ഉണ്ടെങ്കിൽ അതിന്റെ ഉപയോഗം ഉറപ്പാക്കി ആ record മാത്രം പരിഹരിക്കുക. Root domain/download domain/email DNS records തൊടരുത്.

DNS record ഉണ്ടെന്നത് tunnel running എന്നർത്ഥമല്ല.

## 11. Tunnel തുടങ്ങുക; public HTTPS പരിശോധിക്കുക

**PowerShell window A**-ൽ:

```powershell
& "$env:LOCALAPPDATA\FreelanTools\cloudflared.exe" tunnel --config "$env:USERPROFILE\.cloudflared\freelan-validator.yml" run
```

`Registered tunnel connection` പോലുള്ള successful connection log വരണം. ഈ window running ആയിട്ട് വെക്കുക; publishing നടക്കുമ്പോൾ അടയ്ക്കരുത്. Router-ൽ inbound ports തുറക്കേണ്ടതില്ല. Outbound firewall restrictions ഉണ്ടെങ്കിൽ [Cloudflare tunnel firewall requirements](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/tunnel-with-firewall/) പരിശോധിക്കുക.

**പുതിയ PowerShell window B** തുറന്ന്:

```powershell
curl.exe --max-time 20 -s -o NUL -w 'Status: %{http_code}\n' -X POST https://validator.freelan.space/verify
curl.exe --max-time 20 -s -o NUL -w 'Status: %{http_code}\n' https://validator.freelan.space/
```

Expected **401**, **404**. HTTPS certificate സാധാരണ verify ചെയ്യണം; `-k` / certificate verification disable ചെയ്യരുത്. `/verify`-ന് Cloudflare Access login page/browser challenge ഉണ്ടാകരുത്: ഈ Edge Function അയക്കുന്നത് validator Bearer secret മാത്രം ആണ്; Access service-token headers അയക്കുന്നില്ല. നിങ്ങളുടെ zone-ൽ ഉള്ള Access/WAF rules ഈ specific API route തടയുന്നുണ്ടെങ്കിൽ അവയുടെ configuration പരിഹരിക്കുക; zone മുഴുവൻ protection off ചെയ്യേണ്ടതില്ല. 401 മാത്രം കിട്ടിയതുകൊണ്ട് full readiness ഉറപ്പായിട്ടില്ല; section 13 നിർബന്ധമാണ്.

## 12. Supabase secrets നൽകുക

[Supabase production secrets](https://supabase.com/docs/guides/functions/secrets) dashboard-ൽ project Owner/Administrator-ന് മാറ്റാം. ശരിയായ [project Edge Function secrets](https://supabase.com/dashboard/project/stpxbshwdiupigymakfy/functions/secrets) തുറക്കുക.

### 12.1 URL

Name `APK_VALIDATOR_URL`, Value:

```text
https://validator.freelan.space/verify
```

Save ചെയ്യുക. ഇത് APK download URL അല്ല.

### 12.2 Shared secret terminal-ൽ കാണിക്കാതെ copy ചെയ്യുക

**Windows Settings → System → Clipboard**-ൽ Clipboard history, Sync across devices താൽക്കാലികമായി off ചെയ്യുക; third-party clipboard history manager ഉണ്ടെങ്കിൽ അതും pause ചെയ്യുക. മുൻപ് secret copy ചെയ്തിട്ടുണ്ടെങ്കിൽ history-യും clear ചെയ്യുക. തുടർന്ന് window B-ൽ:

```powershell
& {
  $ErrorActionPreference = 'Stop'
  $secure = ConvertTo-SecureString -String ((Get-Content -Raw -LiteralPath "$env:LOCALAPPDATA\FreelanValidator\secret.dpapi").Trim())
  if ($secure.Length -ne 64) { throw 'Invalid saved secret' }
  $pointer = [IntPtr]::Zero
  try {
    $pointer = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    Set-Clipboard -Value ([System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer))
    Write-Host 'Secret copied; paste only into Supabase APK_VALIDATOR_SECRET'
  } finally {
    if ($pointer -ne [IntPtr]::Zero) { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
    $secure.Dispose()
  }
}
```

Supabase-ൽ Name **`APK_VALIDATOR_SECRET`**, Value field-ൽ **Ctrl+V** → Save. Screenshot/chat-ൽ paste ചെയ്യരുത്. DPAPI file text, fingerprint, tunnel JSON എന്നിവ ഇതിന്റെ value അല്ല. Paste/save കഴിഞ്ഞാൽ:

```powershell
Set-Clipboard -Value ''
```

### 12.3 Existing R2 secrets പരിശോധിക്കുക

Same project Edge Function secrets-ൽ ഇവ വേണം; നിലവിലുള്ള correct values preserve ചെയ്യുക:

| Secret | Value/source |
| --- | --- |
| `R2_ACCOUNT_ID` | Section 6-ലെ account ID |
| `R2_BUCKET` | `freelan-space-apk` |
| `R2_ACCESS_KEY_ID` | ആ bucket-ന്റെ valid Object Read & Write key |
| `R2_SECRET_ACCESS_KEY` | അതിന്റെ matching secret key |
| `R2_PUBLIC_BASE_URL` | R2 public custom domain, ഉദാ. `https://updates.freelan.space`; path/query/fragment ഇല്ല |
| `APK_VALIDATOR_URL` | `https://validator.freelan.space/verify` |
| `APK_VALIDATOR_SECRET` | Windows validator-ന്റെ അതേ decrypted secret |

Supabase platform `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` supply ചെയ്യും; validator container-ന് service-role key/R2 permanent access key നൽകേണ്ടതില്ല. Client/app-ലേക്ക് ഈ server secrets കൊടുക്കരുത്. ഇപ്പോൾ Edge Function deploy ചെയ്യാതെ അടുത്ത test പൂർത്തിയാക്കുക.

## 13. യഥാർഥ APK + R2 ഉപയോഗിച്ചുള്ള പരിശോധന

ഇതാണ് full validator test: സ്വന്തം signed APK ഒരു പുതിയ random `staging/<UUID>/<UUID>.apk` key-യിലേക്ക് upload ചെയ്ത്, presigned GET URL വഴി **public HTTPS validator**-നെ പരിശോധിക്കും. Release publish ചെയ്യില്ല; database/referral link മാറ്റില്ല; test object അവസാനം delete ചെയ്യാൻ ശ്രമിക്കും. Existing published object-ന്റെ key ഒരിക്കലും ഉപയോഗിക്കില്ല.

ഇതിന് section 6-ലെ bucket-scoped R2 Access Key ID/Secret Access Key വേണം; അവ prompts-ൽ **hidden input** ആയി നൽകുക. R2 credential clipboard-ൽ നിന്ന് paste ചെയ്യുന്നുവെങ്കിൽ section 12-ലെ clipboard precautions പാലിക്കുക; കഴിഞ്ഞാൽ clipboard/history clear ചെയ്യുക. Token നഷ്ടമായെങ്കിൽ Cloudflare-ൽ വേറെ temporary restricted token ഉണ്ടാക്കുക; existing production token revoke ചെയ്യരുത്.

Official [AWS CLI container](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-docker.html) download ചെയ്യുക; AWS account വേണ്ട, ഈ test Cloudflare R2-നെയാണ് വിളിക്കുന്നത്:

```powershell
docker pull public.ecr.aws/aws-cli/aws-cli:latest
docker pull node:24-alpine
```

മുഴുവൻ block window B-ൽ paste ചെയ്യുക. Failure വന്നാൽ **Edge deploy നിർത്തിവച്ച് കാരണം പരിഹരിക്കുക**; generic error മാത്രം print ചെയ്യുന്നത് secret/presigned URL പുറത്തുപോകാതിരിക്കാനാണ്.

```powershell
& {
  $ErrorActionPreference = 'Stop'
  $names = @('AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY')
  foreach ($name in $names) {
    if (Test-Path ('Env:' + $name)) { throw 'AWS environment already set; use a fresh PowerShell' }
  }
  $settings = Get-Content -Raw -LiteralPath "$env:LOCALAPPDATA\FreelanValidator\validator.env" | ConvertFrom-StringData
  $hostName = $settings.R2_DOWNLOAD_HOST
  $bucket = $settings.R2_BUCKET
  if ($hostName -notmatch '^[a-f0-9]{32}\.r2\.cloudflarestorage\.com$' -or $bucket -ne 'freelan-space-apk') { throw 'Invalid R2 settings' }
  $folder = (Read-Host 'Folder containing trusted app-release.apk').Trim().Trim('"')
  $apk = Get-Item -LiteralPath (Join-Path $folder 'app-release.apk')
  if ($apk.Length -lt 4 -or $apk.Length -gt 209715200) { throw 'Invalid APK size' }
  $badging = docker run --rm --network none --mount "type=bind,source=$folder,target=/apk,readonly" --entrypoint /usr/bin/aapt freelan-apk-validator dump badging /apk/app-release.apk
  if ($LASTEXITCODE -ne 0) { throw 'Cannot read APK metadata' }
  $match = [regex]::Match(($badging -join "`n"), "(?m)^package: name='space\.freelan\.app' versionCode='(\d+)' versionName='([^']+)'")
  if (-not $match.Success) { throw 'Wrong APK package or missing version' }
  $key = 'staging/' + [guid]::NewGuid().ToString() + '/' + [guid]::NewGuid().ToString() + '.apk'
  $copyModule = Join-Path $env:USERPROFILE 'source\freelan-validator\supabase\functions\app-release-upload\r2_destination.mjs'
  if (-not (Test-Path -LiteralPath $copyModule -PathType Leaf)) { throw 'Repository R2 copy protection module missing' }
  $config = Join-Path $env:TEMP ('freelan-aws-' + [guid]::NewGuid().ToString() + '.config')
  $uploadAttempted = $false
  $sourceUrl = $null
  $headers = $null
  function Invoke-FreelanR2 {
    param([string[]]$CliArguments)
    $reply = docker run --rm --read-only --tmpfs '/tmp:rw,nosuid,nodev,size=32m,mode=1777' --cap-drop=ALL --security-opt=no-new-privileges --env AWS_ACCESS_KEY_ID --env AWS_SECRET_ACCESS_KEY --env AWS_EC2_METADATA_DISABLED=true --env AWS_REQUEST_CHECKSUM_CALCULATION=WHEN_REQUIRED --env AWS_CONFIG_FILE=/aws/config --mount "type=bind,source=$config,target=/aws/config,readonly" --mount "type=bind,source=$folder,target=/apk,readonly" public.ecr.aws/aws-cli/aws-cli:latest --no-cli-pager --endpoint-url "https://$hostName" --region auto @CliArguments
    if ($LASTEXITCODE -ne 0) { throw 'R2 command failed' }
    return $reply
  }
  try {
    @('[default]', 'region = auto', 's3 =', '    addressing_style = path', '    signature_version = s3v4') | Set-Content -LiteralPath $config -Encoding Ascii
    foreach ($name in $names) {
      $secure = Read-Host "$name (hidden)" -AsSecureString
      $pointer = [IntPtr]::Zero
      try {
        $pointer = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        Set-Item -Path ('Env:' + $name) -Value ([System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer))
      } finally {
        if ($pointer -ne [IntPtr]::Zero) { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
        $secure.Dispose()
      }
    }
    $uploadAttempted = $true
    $etag = (Invoke-FreelanR2 -CliArguments @('s3api', 'put-object', '--bucket', $bucket, '--key', $key, '--body', '/apk/app-release.apk', '--content-type', 'application/vnd.android.package-archive', '--if-none-match', '*', '--query', 'ETag', '--output', 'json')) | ConvertFrom-Json
    $sourceUrl = ((Invoke-FreelanR2 -CliArguments @('s3', 'presign', "s3://$bucket/$key", '--expires-in', '300')) -join '').Trim()
    $uri = [uri]$sourceUrl
    if ($uri.Scheme -ne 'https' -or $uri.Host -ne $hostName -or $uri.AbsolutePath -ne "/$bucket/$key") { throw 'Presigned URL must use the expected path-style endpoint' }
    $secure = ConvertTo-SecureString -String ((Get-Content -Raw -LiteralPath "$env:LOCALAPPDATA\FreelanValidator\secret.dpapi").Trim())
    $pointer = [IntPtr]::Zero
    try {
      $pointer = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
      $headers = @{ Authorization = 'Bearer ' + [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
    } finally {
      if ($pointer -ne [IntPtr]::Zero) { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
      $secure.Dispose()
    }
    $data = @{ url = $sourceUrl; etag = $etag; size = $apk.Length; sha256 = (Get-FileHash -LiteralPath $apk.FullName -Algorithm SHA256).Hash.ToLowerInvariant(); versionCode = [long]$match.Groups[1].Value; versionName = $match.Groups[2].Value }
    $timer = [Diagnostics.Stopwatch]::StartNew()
    try {
      $response = Invoke-WebRequest -UseBasicParsing -Uri 'https://validator.freelan.space/verify' -Method Post -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ($data | ConvertTo-Json -Compress) -TimeoutSec 110
    } catch { throw 'Real APK verification failed; see the 422/timeout troubleshooting section' }
    $timer.Stop()
    $result = $response.Content | ConvertFrom-Json
    if ($response.StatusCode -ne 200 -or $result.sha256 -ne $data.sha256 -or $result.size -ne $data.size -or $result.versionCode -ne $data.versionCode) { throw 'Validator response did not match the APK' }
    Write-Host ('Real APK verification: PASS (HTTP 200, ' + [math]::Round($timer.Elapsed.TotalSeconds, 1) + ' seconds)')
    $data.versionCode = $data.versionCode + 1
    $negativeStatus = 0
    try {
      $null = Invoke-WebRequest -UseBasicParsing -Uri 'https://validator.freelan.space/verify' -Method Post -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ($data | ConvertTo-Json -Compress) -TimeoutSec 110
    } catch {
      if ($_.Exception.Response) { $negativeStatus = [int]$_.Exception.Response.StatusCode }
    }
    if ($negativeStatus -ne 422) { throw 'Mismatched version rejection test failed' }
    Write-Host 'Wrong version rejected: PASS (HTTP 422)'
    $copyProbe = @'
import { S3Client, HeadObjectCommand, CopyObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { randomUUID } from 'node:crypto';
import { preventDestinationOverwrite } from '/probe/r2_destination.mjs';
const s3 = new S3Client({
  region: 'auto', endpoint: 'https://' + process.env.R2_PROBE_HOST,
  forcePathStyle: true, requestChecksumCalculation: 'WHEN_REQUIRED',
});
const Bucket = process.env.R2_PROBE_BUCKET;
const source = process.env.R2_PROBE_SOURCE;
const Key = `staging/${randomUUID()}/${randomUUID()}.apk`;
try {
  const head = await s3.send(new HeadObjectCommand({Bucket, Key: source}));
  const copy = () => s3.send(preventDestinationOverwrite(new CopyObjectCommand({
    Bucket, Key, CopySource: `${Bucket}/${source}`, CopySourceIfMatch: head.ETag,
  })));
  await copy();
  let rejected = false;
  try { await copy(); } catch (error) { rejected = error.$metadata?.httpStatusCode === 412; }
  if (!rejected) throw new Error('Destination overwrite was not rejected');
  const after = await s3.send(new HeadObjectCommand({Bucket, Key}));
  if (after.ETag !== head.ETag || after.ContentLength !== head.ContentLength) throw new Error('Copy metadata mismatch');
  console.log('R2 destination-copy protection: PASS (duplicate rejected HTTP 412)');
} catch {
  console.error('R2 destination-copy protection: FAIL; keep publishing paused');
  process.exitCode = 1;
} finally {
  try { await s3.send(new DeleteObjectCommand({Bucket, Key})); }
  catch { console.error('Copy-probe cleanup failed; remove only this test staging key: ' + Key); process.exitCode = 1; }
  s3.destroy();
}
'@
    $copyProbe | docker run --rm -i --read-only --tmpfs '/tmp:rw,nosuid,nodev,size=128m,mode=1777' --cap-drop=ALL --security-opt=no-new-privileges --env AWS_ACCESS_KEY_ID --env AWS_SECRET_ACCESS_KEY --env AWS_EC2_METADATA_DISABLED=true --env "R2_PROBE_HOST=$hostName" --env "R2_PROBE_BUCKET=$bucket" --env "R2_PROBE_SOURCE=$key" --mount "type=bind,source=$copyModule,target=/probe/r2_destination.mjs,readonly" node:24-alpine sh -c 'cd /tmp && npm install --ignore-scripts --no-package-lock --no-audit --no-fund @aws-sdk/client-s3@3.899.0 && node --input-type=module'
    if ($LASTEXITCODE -ne 0) { throw 'Real R2 destination-copy protection check failed' }
  } finally {
    if ($uploadAttempted) {
      try {
        $null = Invoke-FreelanR2 -CliArguments @('s3api', 'delete-object', '--bucket', $bucket, '--key', $key)
        Write-Host 'Temporary staging object deleted'
      } catch { Write-Warning ('Test staging cleanup failed; delete only this test key or let the staging lifecycle expire it: ' + $key) }
    }
    foreach ($name in $names) { Remove-Item -Path ('Env:' + $name) -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath $config -ErrorAction SilentlyContinue
    $headers = $null
    $sourceUrl = $null
    $data = $null
    $response = $null
  }
}
```

Expected **നാലും** (ഇടയിൽ npm package install output വരാം):

```text
Real APK verification: PASS (HTTP 200, ... seconds)
Wrong version rejected: PASS (HTTP 422)
R2 destination-copy protection: PASS (duplicate rejected HTTP 412)
Temporary staging object deleted
```

ഈ setup-ൽ nginx read timeout **115 seconds**, test timeout **110 seconds** ആണ്. Real APK പരിശോധന ഇതിന് മുമ്പ് തീരണം; Edge Function-ന്റെ 180-second timeout മാത്രം നോക്കിയാൽ പോരാ. Slow download/CPU കാരണം failure വന്നാൽ PC/network/resources പരിഹരിച്ച് വീണ്ടും verify ചെയ്യുക. Body/Authorization/presigned URL logging enable ചെയ്ത് troubleshoot ചെയ്യരുത്. Test-നു മാത്രം സൃഷ്ടിച്ച temporary R2 token revoke ചെയ്യാം; deployed function ഉപയോഗിക്കുന്ന token revoke ചെയ്യരുത്.

**ഈ test Supabase-ൽ save ചെയ്ത secret ശരിയാണെന്ന് സ്വതന്ത്രമായി തെളിയിക്കില്ല**: അത് section 12-ൽ ഇതേ DPAPI secret-ൽ നിന്ന് copy ചെയ്തതായിരിക്കണം. Deployment കഴിഞ്ഞുള്ള app publishing section 15-ൽ അത് പരിശോധിക്കും. ഈ block repo-യിലെ യഥാർഥ `r2_destination.mjs`-ഉം function ഉപയോഗിക്കുന്ന അതേ AWS SDK version-ഉം ഉപയോഗിച്ച്, വേറെ random staging key-യിലേക്ക് copy ചെയ്ത് duplicate copy **412** കൊണ്ട് reject ചെയ്യുന്നതും പരിശോധിക്കുന്നു. npm package download-ന് internet വേണം; script temporary container-ൽ മാത്രമാണ് packages install ചെയ്യുന്നത്. Existing releases overwrite ചെയ്തുള്ള പരീക്ഷണം പാടില്ല.

## 14. Migration പരിശോധിക്കുക; Edge Function deploy ചെയ്യുക

Sections 8–13 വിജയിച്ചതിനു ശേഷം മാത്രം. GitHub push, validator container setup, migration, Edge Function deployment എന്നിവ വ്യത്യസ്ത കാര്യങ്ങളാണ്.

### 14.1 Database migration history

Supabase SQL Editor-ൽ **read-only** ആയി:

```sql
select version, name
from supabase_migrations.schema_migrations
where version in ('20261113023807', '20261113024352', '20261113040028')
order by version;

select to_regprocedure(
  'public.publish_r2_app_release_with_referral(uuid,bigint,text,text,text,bigint,text,text)'
) as publisher;
```

ഈ linked project-ൽ migration `20261113040028` നേരത്തേ applied ആണെന്ന് task-ൽ രേഖപ്പെടുത്തിയിട്ടുണ്ട്. **Local reset അതിനെ undo ചെയ്യില്ല**; query കൊണ്ട് ഉറപ്പാക്കി present ആണെങ്കിൽ വീണ്ടും SQL run ചെയ്യരുത്.

മറ്റൊരു project-ൽ migration missing ആണെങ്കിൽ ആദ്യം നിലവിലെ history, എല്ലാ preceding migrations-ഉം പരിശോധിക്കുക. [Migration file](../supabase/migrations/20261113040028_publish_referral_download.sql) deployment migration workflow വഴി ഒരിക്കൽ apply ചെയ്യുക; owner/maintainer-ന് Supabase **apply_migration** tool ഉണ്ടെങ്കിൽ അതുവഴി history record സഹിതം apply ചെയ്യാം. CLI migrations ഉപയോഗിക്കുന്ന project-ൽ authenticated `npx --yes supabase@3.1.0 link --project-ref YOUR_PROJECT_REF`, `npx --yes supabase@3.1.0 db push --remote=YOUR_PROJECT_REF --dry-run` വഴി pending list പരിശോധിച്ച് authorized migrations മാത്രം `npx --yes supabase@3.1.0 db push --remote=YOUR_PROJECT_REF` ചെയ്യുക. പഴയ remote history-യുമായി mismatch വന്നാൽ reconcile ചെയ്യാതെ force/push ചെയ്യരുത്. `supabase/tests/bootstrap.sql`, test fixtures, MFA mocks എന്നിവ **production-ൽ ഒരിക്കലും apply ചെയ്യരുത്**.

### 14.2 CLI install/login

[Node.js LTS](https://nodejs.org/en/download) Windows installer install ചെയ്ത് പുതിയ PowerShell തുറക്കുക. Supabase CLI-ന് Node **20+** വേണം; [official CLI setup](https://supabase.com/docs/guides/local-development/cli/getting-started) കാണുക. ഇവിടെ `npx` വഴി CLI run ചെയ്യുന്നു; global npm install വേണ്ട. ഈ guide commands പരിശോധിച്ച CLI **3.1.0**-ൽ pin ചെയ്തിരിക്കുന്നു; deploy target flag `--remote` ആണ്.

```powershell
node --version
npx --yes supabase@3.1.0 --version
npx --yes supabase@3.1.0 login
```

Browser flow-ൽ സ്വന്തം Supabase account login ചെയ്യുക. Access token command/chat-ൽ ഇടരുത്. Repo root-ലേക്ക്:

```powershell
Set-Location "$env:USERPROFILE\source\freelan-validator"
git branch --show-current
Test-Path .\supabase\functions\app-release-upload\index.ts
```

Expected branch section 4-ലേതും file `True`-ഉം. Deploy-ന് മുമ്പ് Supabase Dashboard-ൽ currently deployed `app-release-upload`-ന്റെ version, source files, JWT setting എന്നിവ private backup ആയി സൂക്ഷിക്കുക; പഴയ function unexpected ആയി restore ചെയ്ത് validator bypass ചെയ്യുന്നത് recovery ആക്കരുത്.

### 14.3 Function deploy

```powershell
npx --yes supabase@3.1.0 functions deploy app-release-upload --remote=stpxbshwdiupigymakfy --use-api
```

[Official deployment guide](https://supabase.com/docs/guides/functions/deploy) അനുസരിച്ച് deploy success ഉറപ്പാക്കുക. **JWT verification enabled** ആയിരിക്കണം; `--no-verify-jwt` ഉപയോഗിക്കരുത്. Dashboard → `app-release-upload` settings-ൽ **Verify JWT** enabled ആണെന്ന് പരിശോധിക്കുക. ഈ command മറ്റു Edge Functions deploy ചെയ്യില്ല.

Function configure ചെയ്തിട്ടില്ലെങ്കിൽ `prepare` ഉൾപ്പെടെയുള്ള requests fail closed ആകും. Wrong secret, validator downtime, timeout എന്നിവ publishing തടയും. Validation disable ചെയ്ത് പരിഹരിക്കരുത്. Need rollback/recovery വന്നാൽ publishing pause ചെയ്ത് configuration/service repair ചെയ്യുക; പഴയ unsafe function restore ചെയ്യുന്നതിന് പകരം verified validator-enforcing build മാത്രം deploy ചെയ്യുക.

## 15. യഥാർഥ publishing, referral sharing പരിശോധിക്കുക

ഇത് users കാണുന്ന production release സൃഷ്ടിക്കും. Testing-ന് random APK publish ചെയ്യരുത്; അടുത്ത **യഥാർഥമായി distribute ചെയ്യാൻ തയ്യാറായ** version മാത്രം ഉപയോഗിക്കുക.

1. Docker Desktop, രണ്ടു containers, tunnel working ആണെന്ന് വീണ്ടും പരിശോധിക്കുക.
2. Updated Windows admin app തുറന്ന് **അതേ Supabase project** ഉപയോഗിച്ച് editor administrator ആയി login ചെയ്ത് MFA പൂർത്തിയാക്കുക.
3. **App releases**-ൽ current release history refresh ചെയ്യുക. പുതിയ APK-യുടെ actual version code എല്ലാ published builds-നേക്കാൾ കൂടുതലായിരിക്കണം; file-ലെ exact version name/code section 5-ലെ `aapt` output-ൽ നിന്ന് എടുക്കുക. Version metadata മാറ്റി എഴുതിയാൽ signed APK മാറില്ല; ആവശ്യമെങ്കിൽ higher build number ഉപയോഗിച്ച് വീണ്ടും build ചെയ്യുക.
4. Signed universal APK തിരഞ്ഞെടുക്കുക → matching version/name/notes നൽകുക → **Publish** confirmation വായിച്ച് confirm ചെയ്യുക. Windows/tunnel window അടയ്ക്കരുത്.
5. Response lost / `publication_unconfirmed` വന്നാൽ **ആദ്യം history refresh ചെയ്യുക**; success ആയ transaction വീണ്ടും publish ചെയ്യാൻ ശ്രമിക്കരുത്. Database row ഇല്ലാത്ത release object ഉണ്ടായാലും overwrite/delete ചെയ്യുന്നതിന് മുമ്പ് maintainer R2 history reconcile ചെയ്യണം.
6. Success ആയ release-ന്റെ public URL-ൽ version/build ഉള്ള `releases/freelan-space-v<version>-<build>.apk` വരണം. Incognito browser-ൽ login ഇല്ലാതെ download ചെയ്യാനാകണം. പഴയ published object മാറ്റരുത്.
7. Admin-ൽ **Referral app download link** പുതിയ release URL-ലേക്ക് update ആയതായി പരിശോധിക്കുക. Updated Android user app-ൽ profile referral share ചെയ്യുക; code-നൊപ്പം അതേ download URL ഉണ്ടാകണം. മുൻപ് അയച്ച messages സ്വയം മാറില്ല.
8. Android real device-ൽ APK install പരിശോധിക്കുക. Users ഇല്ലാത്തതിനാൽ തെരഞ്ഞെടുത്ത പുതിയ key-യുടെ ആദ്യ APK clean install ചെയ്യുക. തുടർന്ന് അതേ key-യിൽ signed higher build ഉപയോഗിച്ച് future update path പരിശോധിക്കുക. മറ്റൊരു key-യിലെ installed APK-നെ ഈ build update ചെയ്യില്ല.
9. Viewer administrator-ന് publish കഴിയരുത്; editor/MFA guard നിലനിൽക്കണം. Publish failure വന്നാൽ app/function-ന്റെ generic errors ഉപയോഗിച്ച് troubleshooting ചെയ്യുക; secret/token/URL ഉള്ള raw request logs share ചെയ്യരുത്.

R2 destination-copy protection `cf-copy-destination-if-none-match: *` ഉപയോഗിക്കുന്നു; [R2 conditional copy documentation](https://developers.cloudflare.com/r2/api/s3/extensions/#conditional-operations-in-copyobject-for-the-destination-object) കാണുക. ഇത് **existing releases immutable** എന്ന contract ആണ്. Section 13-ലെ disposable staging test `412 PreconditionFailed` പരിശോധിക്കുന്നു; provider/SDK/copy module മാറ്റിയാൽ ആ പരിശോധന വീണ്ടും run ചെയ്യുക; published artifact ഉപയോഗിച്ച് overwrite test ചെയ്യരുത്. [Referral behavior](REFERRAL_SHARING.md), [app updates](APP_UPDATES.md), [security contract](SECURITY_HARDENING.md) കാണുക.

## 16. Restart, login സമയത്തെ startup, stop

### 16.1 PC restart ചെയ്താൽ

1. **അതേ Windows user** ആയി login ചെയ്യുക; Docker Desktop തുറന്ന് engine ready ആക്കുക.
2. `--restart unless-stopped` containers, മുമ്പ് manually stop ചെയ്തിട്ടില്ലെങ്കിൽ Docker daemon start-ൽ സ്വയം തുടങ്ങും. പരിശോധിക്കുക:

```powershell
docker ps -a --filter 'name=freelan-' --format '{{.Names}} {{.Status}}'
```

3. Manually stopped containers തുടങ്ങാൻ:

```powershell
docker start freelan-apk-validator
docker start freelan-validator-proxy
```

4. Section 11-ലെ tunnel command വീണ്ടും PowerShell window A-ൽ run ചെയ്യുക; section 11 HTTPS test ആവർത്തിക്കുക. Secret വീണ്ടും generate ചെയ്യരുത്. `docker start` പഴയ container-ന്റെ environment ഉപയോഗിക്കും; edited env file വീണ്ടും വായിക്കില്ല.

### 16.2 Windows login-ൽ tunnel auto-start (optional)

ആദ്യം manual setup/test വിജയിക്കണം. ഈ മാർഗം **Windows user login കഴിഞ്ഞ് മാത്രം** tunnel തുടങ്ങും; system service അല്ല, visible command window ഉണ്ടാകും. Docker Desktop sign-in startup കൂടി enable ചെയ്യുക. Existing cloudflared service ഉണ്ടെങ്കിൽ startup duplicate ഉണ്ടാക്കരുത്.

```powershell
& {
  $ErrorActionPreference = 'Stop'
  $startup = [Environment]::GetFolderPath('Startup')
  $file = Join-Path $startup 'FreelanValidatorTunnel.cmd'
  if (Test-Path $file) { throw 'Startup entry already exists' }
  @('@echo off', '"%LOCALAPPDATA%\FreelanTools\cloudflared.exe" tunnel --config "%USERPROFILE%\.cloudflared\freelan-validator.yml" run') | Set-Content -LiteralPath $file -Encoding Ascii
  Write-Host 'Tunnel will start after the next Windows login'
}
```

ഇത് secret/token അടങ്ങിയ script അല്ല. ഇപ്പോൾ manual tunnel running ആണെങ്കിൽ ഈ CMD double-click ചെയ്ത് duplicate തുടങ്ങേണ്ടതില്ല. Next login-ൽ Docker ready ആകുന്നതിന് മുമ്പ് tunnel തുടങ്ങിയാൽ കുറച്ചു നേരം 502 വരാം; Docker ready ആയ ശേഷം HTTP tests ചെയ്യുക. Window close ചെയ്താൽ tunnel നിലക്കും. Auto-start remove ചെയ്യാൻ സ്വന്തം `FreelanValidatorTunnel.cmd` മാത്രം Startup folder-ൽ നിന്ന് delete ചെയ്യുക; Windows service setup വേണമെങ്കിൽ [official Windows service instructions](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/local-management/as-a-service/windows/) അനുസരിച്ച് service-account configuration വേറെയായി ചെയ്യണം.

Windows **Settings → System → Power & battery → Screen, sleep & hibernate timeouts**-ൽ publishing സമയത്ത് plugged-in PC sleep ആകാതിരിക്കാൻ ക്രമീകരിക്കുക. Lid close action, Windows Update restart, internet disconnection എന്നിവയും ശ്രദ്ധിക്കുക.

### 16.3 Stop

Publishing ഒന്നും നടക്കുന്നില്ലെന്ന് ഉറപ്പാക്കി tunnel window-ൽ **Ctrl+C**. തുടർന്ന് ആവശ്യമെങ്കിൽ:

```powershell
docker stop freelan-validator-proxy
docker stop freelan-apk-validator
```

ഇത് files/history delete ചെയ്യില്ല. വീണ്ടും തുടങ്ങാൻ section 16.1; manually stopped containers restart policy കൊണ്ടുമാത്രം തുടങ്ങണമെന്നില്ല.

## 17. പ്രശ്നപരിഹാരം

| ലക്ഷണം | പരിശോധിക്കേണ്ടത് / അടുത്ത നടപടി |
| --- | --- |
| `docker` / `git` / `node` not recognized | Installation/PATH കഴിഞ്ഞ് PowerShell വീണ്ടും തുറക്കുക; official installer പൂർത്തിയായോ പരിശോധിക്കുക. |
| Docker daemon / named pipe error | Docker Desktop തുറന്ന് Linux engine ready ആക്കുക; `docker version`-ൽ Server വേണം; WSL/virtualization പരിശോധിക്കുക. |
| Docker build-ന് Dockerfile not found | Section 4-ലെ exact repo root/path ഉപയോഗിക്കുക. `Test-Path` True ആകണം. |
| Container name already in use | `docker ps -a --filter 'name=freelan-'` കൊണ്ട് current state പരിശോധിക്കുക. Config അതേപടി ആണെങ്കിൽ `docker start`; recreate വേണ്ടെങ്കിൽ publishing pause ചെയ്ത് ആ named container മാത്രം `docker rm -f` ചെയ്ത് ശരിയായ start block വീണ്ടും run ചെയ്യുക. |
| `Settings already exist` | Reset partial ആണ്. പഴയ valid DPAPI/settings ഉണ്ടെങ്കിൽ section 8 ഉപയോഗിക്കുക. രണ്ടിൽ ഒന്ന് മാത്രം ഉണ്ടെങ്കിൽ അവ preserve/backup ചെയ്ത് section 18 rotation plan അനുസരിക്കുക; ചിന്തിക്കാതെ overwrite ചെയ്യരുത്. |
| DPAPI decrypt/invalid saved secret | ഒരേ Windows user/PC ആണോ പരിശോധിക്കുക. File corrupt/നഷ്ടമായാൽ matching secret recover ചെയ്യുക അല്ലെങ്കിൽ section 18 പ്രകാരം രണ്ടു വശവും rotate ചെയ്യുക. |
| `[redacted]`, ParserError, unexpected token, `>>` | Ctrl+C, GitHub guide-ലെ complete code block copy ചെയ്യുക; placeholders/redacted text code-ലേക്ക് ചേർക്കരുത്. Variables `$folder` null ആണെങ്കിൽ പഴയ block പകുതിയായി run ചെയ്തതാണ്; whole self-contained block വീണ്ടും തുടങ്ങുക. |
| Container ID കിട്ടി, പക്ഷേ `docker ps`-ൽ ഇല്ല | `docker ps -a` → `docker logs --tail 30 freelan-apk-validator` / `docker logs --tail 30 freelan-validator-proxy`. Config, memory/OOM, resource limits പരിശോധിക്കുക. Secret-bearing inspect/config dumps share ചെയ്യരുത്. |
| Local proxy 502 | Validator Up ആണോ, രണ്ടും `freelan-validator-net`-ൽ ആണോ, port 8080 backend ആണോ; proxy config വീണ്ടും പരിശോധിക്കുക. |
| Public 502, local 401 | Tunnel origin `http://127.0.0.1:8081` ആണോ; proxy published port loopback-ൽ 8081 ആണോ; Docker Desktop ready ആണോ. |
| Cloudflare 1033 / no connector | Tunnel command running ആണോ, Registered connection ഉണ്ടോ, DNS target selected UUID ആണോ, outbound connectivity ഉണ്ടോ. |
| Public 403 / login/challenge HTML | Cloudflare Access/WAF rule API call തടയുന്നുണ്ടാകാം; correct hostname/rule പരിശോധിക്കുക. Validator Bearer auth നീക്കരുത്. |
| Unauthorized probe 401 | Expected. Correct-secret `{}` probe 422 ആകണം. Real request 401 ആണെങ്കിൽ Windows secret/Supabase secret mismatch പരിശോധിക്കുക. |
| Oversized probe 413 | Expected; 16 KiB boundary പ്രാബല്യത്തിലുണ്ട്. Limit കൂട്ടേണ്ടതില്ല; APK JSON body-ൽ അയക്കുന്നതല്ല, R2-യിൽ നിന്നാണ് download. |
| Correct-secret real request 422 | Section 5 signature/trusted signer, exact package/version, SHA/size, R2 account/bucket/path, quoted ETag, presigned URL expiry, outbound R2 download പരിശോധിക്കുക. Clock sync enable ചെയ്യുക. URL/secret log ചെയ്യരുത്. |
| Correct-secret `{}` probe 503 | `VALIDATOR_SECRET` length / signer configuration തെറ്റ്. Settings ശരിയാക്കി validator container recreate ചെയ്യുക; `docker restart` പുതിയ env file വായിക്കില്ല. |
| Timeout / 504 / 524 | Real APK test duration, internet download, Docker RAM/CPU/temp space പരിശോധിക്കുക. This guide requires response <110 seconds; protection bypass ചെയ്ത് publish ചെയ്യരുത്. |
| R2 `AccessDenied` / signature error | Correct account, bucket-scoped read/write token, secret pair, Windows automatic time, path-style endpoint പരിശോധിക്കുക. Server token app/client-ൽ ഇടരുത്. |
| Cloudflare tunnel name/DNS exists | Section 10.3, 10.5 reuse/replacement branch പിന്തുടരുക. Existing tunnel JSON നഷ്ടമായത് name വീണ്ടും create ചെയ്യുന്നതിലൂടെ പരിഹരിക്കാനാകില്ല. |
| Edge `publication_unconfirmed` | Release history ആദ്യം refresh ചെയ്യുക. Secret/config/validator/MFA/R2 conditional copy പരിശോധിക്കുക; result uncertain ആയപ്പോൾ retry/overwrite വേണ്ട. |
| APK updates install fail | Installed APK-യുടെ package/signer, higher build number പരിശോധിക്കുക. പുതിയ signer പഴയ signer-ലെ installed app update ചെയ്യില്ല. |

Safe local status commands:

```powershell
docker ps -a --filter 'name=freelan-' --format '{{.Names}} {{.Status}}'
docker logs --tail 30 freelan-apk-validator
docker logs --tail 30 freelan-validator-proxy
& "$env:LOCALAPPDATA\FreelanTools\cloudflared.exe" tunnel list
```

Logs-ൽ access/body/Authorization/presigned URL logging enable ചെയ്യരുത്. Outside support-ന് share ചെയ്യുന്നതിന് മുമ്പ് secret material ഇല്ലെന്ന് പരിശോധിക്കുക.

## 18. Backup, secret rotation, final checklist

### Backup

- Production release keystore + passwords വേറിട്ട encrypted backup-ൽ സൂക്ഷിക്കുക; validator reset-ന്റെ ഭാഗമായി അത് delete/change ചെയ്യരുത്.
- `%USERPROFILE%\.cloudflared\<UUID>.json`, `cert.pem` എന്നിവ private encrypted backup-ൽ സൂക്ഷിക്കുക. YAML nonsecret ആണെങ്കിലും local file paths അടങ്ങിയിരിക്കും.
- `secret.dpapi` അതേ Windows profile-ന്റെ protection ആശ്രയിക്കുന്നു; അത് മാത്രം മറ്റൊരു PC-ലേക്ക് copy ചെയ്യുന്നത് portable secret backup അല്ല. Shared secret secure password manager-ൽ സൂക്ഷിച്ചിട്ടില്ലെങ്കിൽ recovery-ക്ക് synchronized rotation ആവശ്യമായി വരാം. Terminal-ൽ print ചെയ്യാതെ section 12-ലെ clipboard വഴി private store-ൽ സൂക്ഷിക്കാം.
- R2 restricted credentials password manager-ൽ; `validator.env`, nginx config, tunnel YAML, chosen signer, deployed function revision എന്നിവയുടെ backup സൂക്ഷിക്കുക. Git-ൽ actual secrets commit ചെയ്യരുത്.

### Reset / secret rotation ശരിയായ ക്രമം

1. New publishing pause ചെയ്യുക. R2 downloads/history നിലനിൽക്കും.
2. Old validator/proxy named containers stop/remove ചെയ്യുക; old tunnel process stop ചെയ്യുക. R2/Supabase data delete വേണ്ട.
3. പഴയ `%LOCALAPPDATA%\FreelanValidator` folder task-specific backup name-ലേക്ക് **move/rename** ചെയ്യുക; മറ്റുള്ള AppData folders തൊടരുത്. പുതിയ settings വേണമെങ്കിൽ section 7 വീണ്ടും run ചെയ്യുക. Old/new secret കലരാതിരിക്കാൻ Supabase copy ചെയ്യുന്നത് പുതിയ folder-ൽ നിന്നാണെന്ന് ഉറപ്പാക്കുക.
4. Sections 8–11 പ്രകാരം recreate/start; section 12-ൽ Supabase `APK_VALIDATOR_SECRET` അതേ പുതിയ secret-ലേക്ക് update ചെയ്യുക. Save ചെയ്ത secret മാറ്റിയാൽ container recreate വേണം; process env cleanup ചെയ്തു എന്നതുകൊണ്ട് already running Docker container-ന്റെ secret മാറില്ല.
5. Section 13 real APK test, section 15 അടുത്ത intended release-ന്റെ publishing verification പൂർത്തിയാക്കുക. Success കഴിഞ്ഞ് വേണ്ടാത്ത old secret backups/access revoke ചെയ്യുക. Secret പുറത്തായെങ്കിൽ rotation നിർബന്ധമാണ്.
6. Trusted signer മാറ്റേണ്ടത് explicit release-signing തീരുമാനം ഉണ്ടായാൽ മാത്രം; incoming arbitrary APK match ചെയ്യാൻ fingerprint മാറ്റരുത്. Signing key change installed-user updates തകർക്കാം.

### Final checklist

- [ ] Windows virtualization/WSL 2 ready; Docker Linux engine/hello-world pass.
- [ ] Correct branch/source image build pass; trusted release APK single signer/package/version verified.
- [ ] R2 account/bucket/public domain/scoped credentials correct; lifecycle **staging/** only.
- [ ] Local secret encrypted outside repo; Windows/Supabase share the **same** secret; no raw secrets logged/committed.
- [ ] Validator/proxy non-root, read-only, tmpfs/resource limits enabled; validator has no host port; proxy loopback-only.
- [ ] Container Up checks, unauthenticated 401, authenticated invalid 422, body-limit 413 pass.
- [ ] Cloudflare tunnel credentials/config/DNS match; ingress validation pass; HTTPS public 401/404 pass.
- [ ] Real signed APK through R2/public HTTPS returns 200 with matching metadata in <110s; wrong version rejected 422; staging cleanup complete.
- [ ] Required migrations/history checked; all required Supabase secrets saved; `app-release-upload` deployment successful; JWT enabled.
- [ ] Section 13 has verified R2 destination-copy rejection on disposable unpublished keys; existing release objects preserved.
- [ ] Next intended production release publishes; history, public download, referral URL/share and real Android install checked.
- [ ] PC restart/recovery/startup procedure tested; publishing സമയത്ത് PC/Docker/tunnel on and awake.

### Verification scope of this guide

Commands repository implementation-നോടും official documentation-നോടും ഒത്തുനോക്കിയാണ് തയ്യാറാക്കിയത്. Linux sandbox-ലെ synthetic checks Windows PowerShell 5.1/DPAPI, നിങ്ങളുടെ Docker Desktop, real R2 credentials, Cloudflare DNS/HTTPS, Supabase save/deploy, real-device installation എന്നിവയ്ക്ക് പകരമല്ല. Checklist-ലെ machine/live checks നിങ്ങൾ ആ target-ൽ run ചെയ്ത് expected results ലഭിച്ചാൽ മാത്രമേ setup ready ആയി കണക്കാക്കാവൂ.


<!-- /coderabbit-ai-generated:v1 -->