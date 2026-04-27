# Production Rollout (Windows, Chrome + Firefox)

## 1) Single Source of Truth
- Edit `deploy/release.config.json`:
  - `backendUrl`
  - `extensionApiKey`
  - `chrome.extensionId`
  - `chrome.updateUrl`

Run:

```powershell
powershell -ExecutionPolicy Bypass -File deploy\sync_extension_config.ps1
```

## 2) Validation Gate
Run:

```powershell
powershell -ExecutionPolicy Bypass -File deploy\validate_release.ps1
```

Checks include:
- Manifest JSON validity (Chrome + Firefox)
- Backend host consistency with release config
- Firefox CSP `connect-src` alignment
- Forbidden host leftovers (`localhost`, `127.0.0.1`, `10.10.10.10`, old public IP)
- JS syntax checks

## 3) Build Artifacts
Firefox:

```powershell
powershell -ExecutionPolicy Bypass -File deploy\create_xpi.ps1
```

Chrome ZIP:

```powershell
powershell -ExecutionPolicy Bypass -File deploy\create_chrome_zip.ps1
```

Chrome signed CRX + update metadata:

```powershell
powershell -ExecutionPolicy Bypass -File deploy\create_chrome_crx.ps1 -PrivateKeyPath <path-to-key.pem> -CrxBaseUrl <public-base-url-containing-crx>
```

## 4) Enforce Admin-Controlled Install/Uninstall
Firefox force-install/lock (admin only):

```powershell
powershell -ExecutionPolicy Bypass -File deploy\install_policy.ps1
```

Firefox removal (policy removed first, then files; admin only):

```powershell
powershell -ExecutionPolicy Bypass -File deploy\remove_policy.ps1
```

Chrome force-install/lock (admin only):

```powershell
powershell -ExecutionPolicy Bypass -File deploy\install_policy_chrome.ps1
```

Chrome removal (admin only):

```powershell
powershell -ExecutionPolicy Bypass -File deploy\remove_policy_chrome.ps1
```

## 5) Rollback Bundle
Create rollback package:

```powershell
powershell -ExecutionPolicy Bypass -File deploy\create_rollback_bundle.ps1 -PreviousFirefoxXpiPath <path-to-previous-xpi> -PreviousChromeExtensionId <id> -PreviousChromeUpdateUrl <url>
```

## 6) Runtime Verification Checklist
- Setup flow saves `deviceId` and `userEmail`.
- Activity upload works (`/api/activity/batch`) and recovers after backend outage.
- Blocked domains fetch and enforce (`/api/blocked-sites`).
- Credential flow works:
  - list (`/api/credentials`)
  - copy (`/api/credentials/{id}/copy`)
  - save (`POST /api/credentials`)
  - delete (`DELETE /api/credentials/{id}`)
- Browser restart preserves alarm-based upload and rules refresh.
- Windows standard user cannot remove force-installed extension.
- Local administrator can remove using policy removal scripts.
