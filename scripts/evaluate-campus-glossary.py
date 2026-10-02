"""Evaluate the campus glossary against a running local LibreTranslate API."""

from __future__ import annotations

import argparse
import json
import statistics
import time
import urllib.request
from pathlib import Path

from libretranslate.campus_glossary import load_default_glossary, protect_text, restore_text


def post_json(url: str, payload: dict[str, object]) -> dict[str, object]:
    request = urllib.request.Request(
        url,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers={"Content-Type": "application/json; charset=utf-8"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


def percentile_95(values: list[float]) -> float:
    ordered = sorted(values)
    index = max(0, int(len(ordered) * 0.95 + 0.999999) - 1)
    return ordered[index]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default="http://127.0.0.1:5002")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    entries = load_default_glossary()
    adoption_results = []
    request_durations_ms = []
    for entry in entries:
        source_language, target_language = entry.language_pair
        started = time.perf_counter()
        response = post_json(
            f"{args.base_url.rstrip('/')}/translate",
            {
                "q": entry.source,
                "source": source_language,
                "target": target_language,
                "format": "text",
                "use_glossary": True,
                "glossary_profile": "campus_zh_ru",
            },
        )
        duration_ms = (time.perf_counter() - started) * 1000
        request_durations_ms.append(duration_ms)
        translated = str(response.get("translatedText", ""))
        matched = response.get("matchedTerms", [])
        passed = entry.target in translated and any(
            hit.get("id") == entry.id for hit in matched if isinstance(hit, dict)
        )
        adoption_results.append(
            {
                "id": entry.id,
                "source": entry.source,
                "expected": entry.target,
                "translated": translated,
                "passed": passed,
            }
        )

    comparisons = []
    comparison_inputs = [
        ("zh", "ru", "我正在学习数据库和数据结构。"),
        ("zh", "ru", "请查看课程表和期末考试安排。"),
        ("ru", "zh", "база данных и машинное обучение"),
    ]
    for source, target, text in comparison_inputs:
        common = {"q": text, "source": source, "target": target, "format": "text"}
        baseline = post_json(f"{args.base_url.rstrip('/')}/translate", common)
        enhanced = post_json(
            f"{args.base_url.rstrip('/')}/translate",
            {**common, "use_glossary": True, "glossary_profile": "campus_zh_ru"},
        )
        comparisons.append(
            {
                "sourceLanguage": source,
                "targetLanguage": target,
                "input": text,
                "baseline": baseline.get("translatedText"),
                "enhanced": enhanced.get("translatedText"),
                "matchedTerms": enhanced.get("matchedTerms", []),
            }
        )

    ordinary_request = {
        "q": "今天天气很好。",
        "source": "zh",
        "target": "ru",
        "format": "text",
    }
    ordinary_baseline = post_json(
        f"{args.base_url.rstrip('/')}/translate", ordinary_request
    )
    ordinary_enhanced = post_json(
        f"{args.base_url.rstrip('/')}/translate",
        {**ordinary_request, "use_glossary": True, "glossary_profile": "campus_zh_ru"},
    )
    ordinary_regression = {
        "input": ordinary_request["q"],
        "baseline": ordinary_baseline.get("translatedText"),
        "enhanced": ordinary_enhanced.get("translatedText"),
        "matchedTerms": ordinary_enhanced.get("matchedTerms", []),
        "identical": ordinary_baseline.get("translatedText")
        == ordinary_enhanced.get("translatedText"),
    }

    layer_durations_ms = []
    benchmark_text = "我正在学习数据库、数据结构、机器学习和软件工程。"
    for _ in range(2000):
        started = time.perf_counter()
        protected = protect_text(benchmark_text, entries, "zh", "ru")
        restore_text(protected.text, protected)
        layer_durations_ms.append((time.perf_counter() - started) * 1000)

    passed_count = sum(1 for result in adoption_results if result["passed"])
    report = {
        "profile": "campus_zh_ru",
        "termCount": len(entries),
        "passedCount": passed_count,
        "adoptionRatePercent": round(passed_count / len(entries) * 100, 2),
        "apiRequestMedianMs": round(statistics.median(request_durations_ms), 3),
        "apiRequestP95Ms": round(percentile_95(request_durations_ms), 3),
        "glossaryLayerMedianMs": round(statistics.median(layer_durations_ms), 6),
        "glossaryLayerP95Ms": round(percentile_95(layer_durations_ms), 6),
        "adoptionResults": adoption_results,
        "comparisons": comparisons,
        "ordinaryTextRegression": ordinary_regression,
    }

    rendered = json.dumps(report, ensure_ascii=False, indent=2)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)
    return 0 if passed_count == len(entries) and ordinary_regression["identical"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
