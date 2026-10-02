# G7 clean Ubuntu VM verification

This is the lower-storage G7 route. It reuses a clean Ubuntu x86_64 VM and does not copy the developer computer's virtual environment, models, caches or local configuration.

## Preconditions

- The VM is Ubuntu x86_64 with at least 2 GiB free in the home filesystem.
- Python 3.10, 3.11 or 3.12 and its `venv` module are available.
- Git is available to clone the bundle.
- The first setup run has internet access; the offline repeat does not.

Record these commands before installing project dependencies:

```bash
lsb_release -a
uname -m
python3 --version
git --version
df -h "$HOME"
```

## Transfer and clone

Transfer only the host-generated `campus-mvp-ubuntu.bundle` file into the VM. Do not transfer runtime folders or `.campus-mvp.local.json`.

```bash
mkdir -p "$HOME/campus-mvp-g7"
cd "$HOME/campus-mvp-g7"
git clone "$HOME/Downloads/campus-mvp-ubuntu.bundle" campus-mvp
cd campus-mvp
git log -1 --oneline
```

Adjust the bundle path if it was copied somewhere other than `~/Downloads`.

## Connected first-time setup

```bash
chmod +x scripts/*campus-mvp*.sh
./scripts/setup-campus-mvp.sh --validate-only
./scripts/setup-campus-mvp.sh
./scripts/verify-campus-mvp.sh
```

The required success markers are `SETUP_PREFLIGHT_PASS`, `SETUP_PASS`, `MODEL_SET_PASS` and `VERIFY_PASS`.

If virtual-environment creation reports a missing `venv` module, install only the package named by the script, then rerun setup. For example:

```bash
sudo apt update
sudo apt install -y python3-venv
```

## Interactive start

```bash
./scripts/start-campus-mvp-linux.sh
```

Confirm that the browser opens `http://127.0.0.1:5000`, then test one Chinese-to-Russian campus term and one Russian-to-Chinese term. Return to Terminal and press `Ctrl+C` to stop the service.

## Offline repeat

1. Shut down the service.
2. Disconnect the VM network adapter in VMware.
3. Run `./scripts/verify-campus-mvp.sh` again.
4. Confirm `VERIFY_PASS` and inspect the newest JSON under `artifacts/verification`.
5. Reconnect the network only after the result is recorded.

## Pass criteria

- Setup starts from the Git Bundle without copied runtime state.
- Dependency and exact model checks pass.
- Core tests report 30/30 and model-backed terminology reports 40/40.
- Ordinary-text regression and privacy-log sentinel checks pass.
- Interactive translation works in both directions.
- The disconnected-network repeat passes.

Keep screenshots and the two verification summaries in the external versioned acceptance-evidence folder. G7 remains `IN PROGRESS` until these steps are completed in the VM.
