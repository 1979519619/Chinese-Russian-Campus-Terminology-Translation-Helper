# Chinese-Russian Campus Terminology Translation Helper（中俄校园术语翻译助手）

基于 LibreTranslate 的校园中俄翻译助手：在翻译管线中加入「校园术语增强层」，命中的术语以固定译法输出并展示分类与出处，全部组件本地部署、断网可用。

- 术语库数据：`libretranslate/glossaries/campus_zh_ru.json`（40 条中俄双向记录，字段说明见 `docs/术语库字段说明.md`）
- 开发状态与验收记录：`docs/MVP_STATUS.md`
- 术语出处说明：`docs/术语出处参考.md`
- 一键自动核验：`scripts/verify-campus-mvp.sh`（Windows 为 `scripts/verify-campus-mvp.ps1`），检查内容见 `docs/验证与复现指南.md`
- Web 界面：翻译页提供「校园术语库」开关（默认关闭）、命中术语展示与只读词表浏览

以下为上游 LibreTranslate 的原始说明。

---

# LibreTranslate

[Try it online!](https://libretranslate.com) | [API Docs](https://docs.libretranslate.com) | [Community Forum](https://community.libretranslate.com/) | [Bluesky](https://bsky.app/profile/libretranslate.com)

[![Python versions](https://img.shields.io/pypi/pyversions/libretranslate)](https://pypi.org/project/libretranslate) [![Run tests](https://github.com/LibreTranslate/LibreTranslate/workflows/Run%20tests/badge.svg)](https://github.com/LibreTranslate/LibreTranslate/actions?query=workflow%3A%22Run+tests%22) [![Build and Publish Docker Image](https://github.com/LibreTranslate/LibreTranslate/actions/workflows/publish-docker.yml/badge.svg)](https://github.com/LibreTranslate/LibreTranslate/actions/workflows/publish-docker.yml) [![Publish package](https://github.com/LibreTranslate/LibreTranslate/actions/workflows/publish-package.yml/badge.svg)](https://github.com/LibreTranslate/LibreTranslate/actions/workflows/publish-package.yml) [![Awesome Humane Tech](https://raw.githubusercontent.com/humanetech-community/awesome-humane-tech/main/humane-tech-badge.svg?sanitize=true)](https://codeberg.org/teaserbot-labs/delightful-humane-design)

Free and Open Source Machine Translation API, entirely self-hosted. Unlike other APIs, it doesn't rely on proprietary software such as Google or Azure to perform translations. Instead, its translation engine is powered by the open source [Argos Translate](https://github.com/argosopentech/argos-translate) library.

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

