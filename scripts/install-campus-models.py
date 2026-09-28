"""Install or verify the exact Argos model set used by the campus MVP."""

from __future__ import annotations

import argparse
from collections.abc import Iterable

from argostranslate import package
from minisbd import download_models


REQUIRED_MODELS = {
    ("zh", "en"): "1.9",
    ("en", "zh"): "1.9",
    ("ru", "en"): "1.9",
    ("en", "ru"): "1.9",
}
REQUIRED_LANGUAGES = ["zh", "en", "ru"]


def model_key(model: object) -> tuple[str, str]:
    return (str(model.from_code), str(model.to_code))


def verify_installed(installed: Iterable[object]) -> list[str]:
    versions = {model_key(model): str(model.package_version) for model in installed}
    problems = []
    for pair, expected_version in REQUIRED_MODELS.items():
        actual_version = versions.get(pair)
        if actual_version != expected_version:
            problems.append(
                f"{pair[0]}->{pair[1]} expected {expected_version}, found {actual_version or 'missing'}"
            )
    return problems


def install_required_models() -> None:
    installed = package.get_installed_packages()
    versions = {model_key(model): str(model.package_version) for model in installed}
    if all(versions.get(pair) == version for pair, version in REQUIRED_MODELS.items()):
        print("Required Argos translation models are already installed.")
    else:
        package.update_package_index()
        available = package.get_available_packages()
        candidates = {
            (model_key(model), str(model.package_version)): model for model in available
        }
        for pair, expected_version in REQUIRED_MODELS.items():
            actual_version = versions.get(pair)
            if actual_version == expected_version:
                print(f"Keeping {pair[0]}->{pair[1]} {expected_version}")
                continue
            if actual_version is not None:
                raise RuntimeError(
                    f"Unexpected installed model {pair[0]}->{pair[1]} {actual_version}; "
                    f"expected {expected_version}. Use a clean runtime directory."
                )
            candidate = candidates.get((pair, expected_version))
            if candidate is None:
                raise RuntimeError(
                    f"Required model is unavailable in the package index: "
                    f"{pair[0]}->{pair[1]} {expected_version}"
                )
            print(f"Downloading and installing {pair[0]}->{pair[1]} {expected_version}")
            package.install_from_path(candidate.download())

    print("Ensuring MiniSBD models for zh, en and ru")
    download_models(REQUIRED_LANGUAGES, print)
    problems = verify_installed(package.get_installed_packages())
    if problems:
        raise RuntimeError("Model verification failed: " + "; ".join(problems))
    print("MODEL_SET_PASS")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check-only", action="store_true")
    args = parser.parse_args()

    if args.check_only:
        problems = verify_installed(package.get_installed_packages())
        if problems:
            print("MODEL_SET_FAIL: " + "; ".join(problems))
            return 1
        print("MODEL_SET_PASS")
        return 0

    install_required_models()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
