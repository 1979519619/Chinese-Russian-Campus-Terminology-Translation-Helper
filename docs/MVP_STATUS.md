# Minimum MVP development status

Status: **IN PROGRESS**

## Repository baseline

- Upstream: `https://github.com/LibreTranslate/LibreTranslate.git`
- Upstream baseline commit: `4aca61b`
- Project origin: `https://github.com/1979519619/Chinese-Russian-Campus-Terminology-Translation-Helper.git`
- Development branch: `feature/minimum-mvp`

No pull request or GitHub issue is created automatically. The project owner must review and submit any external contribution manually and disclose AI assistance.

## Implemented in the first development slice

- Dependency-free glossary validation and loading.
- Forty demo records covering twenty bidirectional Chinese–Russian campus terms.
- Exact literal matching with deterministic status, length, priority and id precedence.
- Russian word-boundary protection.
- Unique placeholder protection and strict restoration checks.
- Public hit metadata containing term, target, category, source and status.
- Thirty dependency-free unit tests.
- Optional `/translate` glossary parameters with default-off compatibility and cache isolation.
- Strict placeholder restoration with safe fallback, response warnings and metadata-only logging.
- A read-only glossary endpoint containing provenance and review status.
- A web switch, matched-term details and a 40-entry read-only glossary browser.
- Real Argos checks for Chinese-to-Russian and Russian-to-Chinese term enforcement.
- Reproducible real-model evaluation: 40/40 accepted terms, 100% designated-term adoption, three baseline/enhanced comparisons and an ordinary-text regression check.
- Glossary-layer benchmark over 2,000 iterations; latest local P95: 0.0349 ms. This is not an end-to-end latency claim.

All seed translations are marked `demo`. They are examples for engineering validation, not official school translations.

## Reproduce the current core tests

From the repository root:

```powershell
python libretranslate\tests\test_campus_glossary.py -v
```

Expected current result: `Ran 30 tests ... OK`.

## Reproduce the local model-backed server

Set the runtime environment to the ASCII-only model location on `F:` and run LibreTranslate with `zh,en,ru` on a free local port. The tested development port is `5001`; the user's normal instance may continue using `5000`.

## Still required before the whole Exit Gate passes

- Reproduce the documented setup on another clean environment.
- Complete submission materials and owner review.
