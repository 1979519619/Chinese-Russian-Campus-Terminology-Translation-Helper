# G7 clean Windows VM verification

G7 remains `IN PROGRESS` until this procedure passes in a Windows VM that has not received the developer computer's virtual environment, models or caches.

## Host preparation

From the repository root on the developer computer:

```powershell
git bundle create .\campus-mvp.bundle feature/minimum-mvp
git bundle verify .\campus-mvp.bundle
```

Copy only `campus-mvp.bundle` to the VM. Do not copy `.campus-mvp.local.json`, `runtime`, `.venv`, `artifacts`, pip caches or Argos model directories.

## Connected first-time setup

Install 64-bit Python 3.12 in the VM, then run:

```powershell
git clone .\campus-mvp.bundle campus-mvp
Set-Location .\campus-mvp
powershell -ExecutionPolicy Bypass -File .\scripts\setup-campus-mvp.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\verify-campus-mvp.ps1
```

Record the setup preflight JSON, `SETUP_PASS`, `VERIFY_PASS`, Python version, Windows version, commit id, runtime path and physical drive free space.

## Offline repeat

After the connected verification passes:

1. Shut down the local service if it is running.
2. Disconnect the VM network adapter.
3. Run `powershell -ExecutionPolicy Bypass -File .\scripts\verify-campus-mvp.ps1` again.
4. Confirm `VERIFY_PASS` and open the generated summary under `artifacts\verification`.
5. Double-click `scripts\start-campus-mvp.cmd`, verify that the browser opens the local page, translate one Chinese term to Russian and one Russian term to Chinese, then press `Ctrl+C` in the launcher window.

## Pass criteria

- The first-time setup succeeds without files copied from the developer runtime.
- All dependency and exact model checks pass.
- Core tests report 30/30 and model-backed adoption reports 40/40.
- Ordinary-text regression and privacy-log sentinel checks pass.
- The offline repeat passes with the VM network disconnected.
- The double-click launcher opens and stops cleanly.

Keep the generated verification JSON and screenshots in the external versioned acceptance-evidence folder. Do not commit model files, caches, logs containing machine paths or the local configuration file.
