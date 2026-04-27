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

## GUI Option (Recommended for technicians)
Build installer GUI EXE:

```powershell
powershell -ExecutionPolicy Bypass -File deploy\build_installer_gui.ps1
```

Run:

`deploy\artifacts\gui\WatchEmployee-Installer.exe`

The GUI will auto-elevate, run preflight checks, and provide one-click Firefox + Chrome policy actions with timestamped logs in `deploy\logs`.

Chrome GUI workflow:
1. Default shared Chrome settings are auto-loaded from `deploy/release.config.json`.
2. Click `Install Chrome Policy` directly for normal workstation installs.
3. Only if values must change: click `Edit Chrome Settings`, update fields, then `Save Chrome Settings`.
4. Verify in `chrome://policy`, then restart Chrome.

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

Publish Chrome update assets into Spring Boot static hosting path:

```powershell
powershell -ExecutionPolicy Bypass -File deploy\publish_chrome_update_assets.ps1
```

This copies:
- `deploy/artifacts/chrome/updates.xml`
- latest `deploy/artifacts/chrome/watch-employee-chrome-v*.crx`

to:
- `src/main/resources/static/extensions/chrome/`

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
