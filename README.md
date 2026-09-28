# LibreTranslate

[Try it online!](https://libretranslate.com) | [API Docs](https://docs.libretranslate.com) | [Community Forum](https://community.libretranslate.com/) | [Bluesky](https://bsky.app/profile/libretranslate.com)

[![Python versions](https://img.shields.io/pypi/pyversions/libretranslate)](https://pypi.org/project/libretranslate) [![Run tests](https://github.com/LibreTranslate/LibreTranslate/workflows/Run%20tests/badge.svg)](https://github.com/LibreTranslate/LibreTranslate/actions?query=workflow%3A%22Run+tests%22) [![Build and Publish Docker Image](https://github.com/LibreTranslate/LibreTranslate/actions/workflows/publish-docker.yml/badge.svg)](https://github.com/LibreTranslate/LibreTranslate/actions/workflows/publish-docker.yml) [![Publish package](https://github.com/LibreTranslate/LibreTranslate/actions/workflows/publish-package.yml/badge.svg)](https://github.com/LibreTranslate/LibreTranslate/actions/workflows/publish-package.yml) [![Awesome Humane Tech](https://raw.githubusercontent.com/humanetech-community/awesome-humane-tech/main/humane-tech-badge.svg?sanitize=true)](https://codeberg.org/teaserbot-labs/delightful-humane-design)

Free and Open Source Machine Translation API, entirely self-hosted. Unlike other APIs, it doesn't rely on proprietary software such as Google or Azure to perform translations. Instead, its translation engine is powered by the open source [Argos Translate](https://github.com/argosopentech/argos-translate) library.

## Chinese-Russian Campus Terminology Translation Helper MVP

This repository adds an optional, local-first Chinese-Russian campus glossary to LibreTranslate. The MVP keeps ordinary translation unchanged by default. When `use_glossary` is enabled for a supported plain-text language pair, exact glossary matches are protected during translation, restored to the designated term and returned as `matchedTerms` with category, source and review status.

The initial 40 records are all marked `demo`. They are engineering samples and must not be described as official school translations. The web interface repeats this notice and provides read-only browsing only.

Project repository: <https://github.com/1979519619/Chinese-Russian-Campus-Terminology-Translation-Helper>

### Local Windows start

The tested runtime keeps models and cache under `F:\LT-Campus-MVP\runtime` to avoid non-ASCII native model paths. From the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-campus-mvp.ps1
```

Open <http://127.0.0.1:5000>. Use `-Port 5001` when port 5000 is already occupied.

### Tests

```powershell
..\runtime\.venv\Scripts\python.exe .\libretranslate\tests\test_campus_glossary.py -v
```

The current core suite contains 30 tests. Model-backed API and page evidence is recorded outside the repository in the versioned acceptance-evidence folder.

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

