# LibreTranslate

[Try it online!](https://libretranslate.com) | [API Docs](https://docs.libretranslate.com) | [Community Forum](https://community.libretranslate.com/) | [Bluesky](https://bsky.app/profile/libretranslate.com)

[![Python versions](https://img.shields.io/pypi/pyversions/libretranslate)](https://pypi.org/project/libretranslate) [![Run tests](https://github.com/LibreTranslate/LibreTranslate/workflows/Run%20tests/badge.svg)](https://github.com/LibreTranslate/LibreTranslate/actions?query=workflow%3A%22Run+tests%22) [![Build and Publish Docker Image](https://github.com/LibreTranslate/LibreTranslate/actions/workflows/publish-docker.yml/badge.svg)](https://github.com/LibreTranslate/LibreTranslate/actions/workflows/publish-docker.yml) [![Publish package](https://github.com/LibreTranslate/LibreTranslate/actions/workflows/publish-package.yml/badge.svg)](https://github.com/LibreTranslate/LibreTranslate/actions/workflows/publish-package.yml) [![Awesome Humane Tech](https://raw.githubusercontent.com/humanetech-community/awesome-humane-tech/main/humane-tech-badge.svg?sanitize=true)](https://codeberg.org/teaserbot-labs/delightful-humane-design)

Free and Open Source Machine Translation API, entirely self-hosted. Unlike other APIs, it doesn't rely on proprietary software such as Google or Azure to perform translations. Instead, its translation engine is powered by the open source [Argos Translate](https://github.com/argosopentech/argos-translate) library.

## Chinese-Russian Campus Terminology Translation Helper MVP

This repository adds an optional, local-first Chinese-Russian campus glossary to LibreTranslate. The MVP keeps ordinary translation unchanged by default. When `use_glossary` is enabled for a supported plain-text language pair, exact glossary matches are protected during translation, restored to the designated term and returned as `matchedTerms` with category, source and review status.

The initial 40 records are all marked `demo`. They are engineering samples and must not be described as official school translations. The web interface repeats this notice and provides read-only browsing only.

Project repository: <https://github.com/1979519619/Chinese-Russian-Campus-Terminology-Translation-Helper>

### First-time Windows setup

Requirements: 64-bit Python 3.12, PowerShell 5.1 or later, an internet connection for the first installation, and at least 2 GiB free on the runtime drive. The locked environment currently occupies about 0.85 GiB. Models, the virtual environment and caches are local runtime data and are intentionally excluded from Git.

From the repository root, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup-campus-mvp.ps1
```

The setup performs a storage preflight before writing. It defaults to `F:\LT-Campus-MVP\runtime` when drive F is available, otherwise to an ASCII-only path on the system drive. An ASCII-only runtime path is required because SentencePiece is unreliable with non-ASCII model paths on Windows. Override the location with `-RuntimeRoot` when necessary.

### Everyday start

Double-click `scripts\start-campus-mvp.cmd`, or run this from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-campus-mvp.ps1
```

The double-click launcher opens <http://127.0.0.1:5000> after the local service becomes healthy. Keep its PowerShell window open while using the assistant; press `Ctrl+C` to stop it. Use `-Port 5001` when port 5000 is already occupied.

### Automatic verification

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-campus-mvp.ps1
```

The verifier checks dependencies and the exact four-model set, runs all 30 core tests, launches an isolated service on port 5002, evaluates all 40 glossary records, verifies ordinary-text behavior, and confirms that a unique request-text sentinel did not appear in server logs. Small reports are written to the ignored `artifacts\verification` directory.

### Clean Windows VM reproduction before publishing

The project can be tested before it is pushed to GitHub by transferring a Git Bundle to a clean Windows VM:

```powershell
git bundle create .\campus-mvp.bundle feature/minimum-mvp
```

Copy `campus-mvp.bundle` to the VM, then run:

```powershell
git clone .\campus-mvp.bundle campus-mvp
Set-Location .\campus-mvp
powershell -ExecutionPolicy Bypass -File .\scripts\setup-campus-mvp.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\verify-campus-mvp.ps1
```

For the offline acceptance check, finish setup once while connected, disconnect the VM network, and run the verifier again. Do not copy the host virtual environment, model directory, pip cache or `.campus-mvp.local.json` into the VM. G7 is complete only after this clean-environment run passes; preparing the scripts on the development computer is not sufficient evidence by itself.

### Clean Ubuntu VM reproduction (lower-storage route)

An existing Ubuntu x86_64 VM can be used instead of creating a second Windows VM. The Linux setup accepts Python 3.10, 3.11 or 3.12 and keeps its complete runtime under `~/CampusMVP/runtime` by default.

After cloning the Git Bundle in the clean VM:

```bash
chmod +x scripts/*campus-mvp*.sh
./scripts/setup-campus-mvp.sh --validate-only
./scripts/setup-campus-mvp.sh
./scripts/verify-campus-mvp.sh
```

Start the local page with:

```bash
./scripts/start-campus-mvp-linux.sh
```

The setup performs a 2 GiB free-space gate before writing, creates an isolated virtual environment, installs the locked dependencies and exact four-model set, and runs the core tests. The verifier uses port 5002 temporarily and stops only its own process. For G7, repeat the verifier once with the VM network disconnected. See `docs/G7_CLEAN_UBUNTU_VM_VERIFICATION.md` for the evidence checklist. Linux support remains unverified until that clean-VM procedure succeeds.

### Modification and AI disclosure

MVP-specific changes are limited to the glossary data and matching module, optional `/translate` parameters, safe placeholder fallback, a read-only glossary endpoint, the web switch and match display, tests, documentation and the Windows launcher. AI assistance was used for planning, implementation drafts, debugging and test orchestration. The project owner remains responsible for reviewing terminology, source claims, licensing, test results and the final submission. No pull request or issue is created automatically.

![Translation](https://github.com/user-attachments/assets/457696b5-dbff-40ab-a18e-7bfb152c5121)

## Getting Started

- [Quickstart](https://docs.libretranslate.com/)
- [Usage Instructions](https://docs.libretranslate.com/guides/api_usage/)
- [Community Resources](https://docs.libretranslate.com/community/resources/)

## Credits

This work is largely possible thanks to [Argos Translate](https://github.com/argosopentech/argos-translate), which powers the translation engine.

## License

[GNU Affero General Public License v3](https://www.gnu.org/licenses/agpl-3.0.en.html)

## Trademark

See [Trademark Guidelines](https://github.com/LibreTranslate/LibreTranslate/blob/main/TRADEMARK.md)

