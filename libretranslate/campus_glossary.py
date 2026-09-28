"""Campus glossary matching and placeholder protection for the MVP.

This module intentionally has no Flask or Argos dependency so its rules can be
tested before language models are installed.  It does not claim that seed terms
are official translations; provenance and review status travel with every hit.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Callable, Iterable, Sequence


ALLOWED_STATUSES = {"verified", "reviewed", "demo"}
STATUS_RANK = {"verified": 3, "reviewed": 2, "demo": 1}
DIRECTION_LANGUAGES = {
    "zh-Hans_to_ru": ("zh", "ru"),
    "ru_to_zh-Hans": ("ru", "zh"),
}
LANGUAGE_ALIASES = {
    "zh": "zh",
    "zh-hans": "zh",
    "zh-cn": "zh",
    "ru": "ru",
}
REQUIRED_FIELDS = {
    "id",
    "source",
    "target",
    "direction",
    "category",
    "source_ref",
    "status",
    "priority",
    "updated_at",
}


class GlossaryValidationError(ValueError):
    """Raised when glossary data does not satisfy the versioned schema."""


class GlossaryRestoreError(RuntimeError):
    """Raised when a translation engine damages or duplicates a placeholder."""


@dataclass(frozen=True)
class TermEntry:
    id: str
    source: str
    target: str
    direction: str
    category: str
    source_ref: str
    status: str
    priority: int
    updated_at: str
    aliases: tuple[str, ...] = ()

    @property
    def language_pair(self) -> tuple[str, str]:
        return DIRECTION_LANGUAGES[self.direction]


@dataclass(frozen=True)
class TermMatch:
    start: int
    end: int
    matched_text: str
    entry: TermEntry
    token: str = ""

    def public_dict(self) -> dict[str, object]:
        return {
            "id": self.entry.id,
            "source": self.matched_text,
            "target": self.entry.target,
            "category": self.entry.category,
            "sourceRef": self.entry.source_ref,
            "status": self.entry.status,
        }


@dataclass(frozen=True)
class ProtectedText:
    text: str
    matches: tuple[TermMatch, ...]


def normalize_language(language: str) -> str:
    if not isinstance(language, str):
        return language
    return LANGUAGE_ALIASES.get(language.lower(), language.lower())


def _require_string(record: dict[str, object], field: str, index: int) -> str:
    value = record.get(field)
    if not isinstance(value, str) or not value.strip():
        raise GlossaryValidationError(f"record {index}: {field} must be a non-empty string")
    return value.strip()


def validate_records(records: object) -> tuple[TermEntry, ...]:
    if not isinstance(records, list):
        raise GlossaryValidationError("glossary root must be a JSON array")

    entries: list[TermEntry] = []
    seen_ids: set[str] = set()
    for index, record in enumerate(records):
        if not isinstance(record, dict):
            raise GlossaryValidationError(f"record {index}: expected an object")
        missing = REQUIRED_FIELDS - set(record)
        if missing:
            raise GlossaryValidationError(
                f"record {index}: missing fields {', '.join(sorted(missing))}"
            )

        entry_id = _require_string(record, "id", index)
        if entry_id in seen_ids:
            raise GlossaryValidationError(f"record {index}: duplicate id {entry_id}")
        seen_ids.add(entry_id)

        direction = _require_string(record, "direction", index)
        if direction not in DIRECTION_LANGUAGES:
            raise GlossaryValidationError(f"record {index}: unsupported direction {direction}")

        status = _require_string(record, "status", index)
        if status not in ALLOWED_STATUSES:
            raise GlossaryValidationError(f"record {index}: unsupported status {status}")

        priority = record.get("priority")
        if isinstance(priority, bool) or not isinstance(priority, int):
            raise GlossaryValidationError(f"record {index}: priority must be an integer")

        updated_at = _require_string(record, "updated_at", index)
        try:
            date.fromisoformat(updated_at)
        except ValueError as exc:
            raise GlossaryValidationError(
                f"record {index}: updated_at must use ISO YYYY-MM-DD"
            ) from exc

        aliases_value = record.get("aliases", [])
        if not isinstance(aliases_value, list) or not all(
            isinstance(alias, str) and alias.strip() for alias in aliases_value
        ):
            raise GlossaryValidationError(f"record {index}: aliases must be non-empty strings")

        source = _require_string(record, "source", index)
        aliases = tuple(alias.strip() for alias in aliases_value)
        if source in aliases or len(set(aliases)) != len(aliases):
            raise GlossaryValidationError(f"record {index}: aliases must be unique")

        entries.append(
            TermEntry(
                id=entry_id,
                source=source,
                target=_require_string(record, "target", index),
                direction=direction,
                category=_require_string(record, "category", index),
                source_ref=_require_string(record, "source_ref", index),
                status=status,
                priority=priority,
                updated_at=updated_at,
                aliases=aliases,
            )
        )
    return tuple(entries)


def load_glossary(path: str | Path) -> tuple[TermEntry, ...]:
    glossary_path = Path(path)
    with glossary_path.open("r", encoding="utf-8") as handle:
        return validate_records(json.load(handle))


def default_glossary_path() -> Path:
    return Path(__file__).with_name("glossaries") / "campus_zh_ru.json"


def load_default_glossary() -> tuple[TermEntry, ...]:
    return load_glossary(default_glossary_path())


def _is_word_character(char: str) -> bool:
    return char == "_" or char.isalnum()


def _boundary_ok(text: str, start: int, end: int, source_language: str) -> bool:
    if source_language != "ru":
        return True
    before_ok = start == 0 or not _is_word_character(text[start - 1])
    after_ok = end == len(text) or not _is_word_character(text[end])
    return before_ok and after_ok


def _iter_candidates(
    text: str,
    entries: Sequence[TermEntry],
    source_language: str,
    target_language: str,
) -> Iterable[TermMatch]:
    for entry in entries:
        if entry.language_pair != (source_language, target_language):
            continue
        for literal in (entry.source, *entry.aliases):
            cursor = 0
            while True:
                start = text.find(literal, cursor)
                if start < 0:
                    break
                end = start + len(literal)
                if _boundary_ok(text, start, end, source_language):
                    yield TermMatch(start, end, literal, entry)
                cursor = start + 1


def find_matches(
    text: str,
    entries: Sequence[TermEntry],
    source_language: str,
    target_language: str,
) -> tuple[TermMatch, ...]:
    """Return deterministic, non-overlapping matches using the MVP precedence."""

    if not isinstance(text, str):
        raise TypeError("text must be a string")
    source_language = normalize_language(source_language)
    target_language = normalize_language(target_language)
    candidates = list(_iter_candidates(text, entries, source_language, target_language))
    candidates.sort(
        key=lambda match: (
            -STATUS_RANK[match.entry.status],
            -(match.end - match.start),
            -match.entry.priority,
            match.start,
            match.entry.id,
        )
    )

    selected: list[TermMatch] = []
    occupied: list[tuple[int, int]] = []
    for candidate in candidates:
        if any(candidate.start < end and start < candidate.end for start, end in occupied):
            continue
        selected.append(candidate)
        occupied.append((candidate.start, candidate.end))
    selected.sort(key=lambda match: (match.start, match.end, match.entry.id))
    return tuple(selected)


def protect_text(
    text: str,
    entries: Sequence[TermEntry],
    source_language: str,
    target_language: str,
) -> ProtectedText:
    matches = find_matches(text, entries, source_language, target_language)
    if not matches:
        return ProtectedText(text=text, matches=())

    parts: list[str] = []
    protected_matches: list[TermMatch] = []
    cursor = 0
    for index, match in enumerate(matches):
        # Numeric bracketed tokens survive the current zh->en->ru and
        # ru->en->zh Argos paths, including a token used as the entire input.
        # Alphabetic and private-use markers are rewritten by these models.
        token = f"[0-{index}]"
        if token in text:
            raise GlossaryRestoreError("input already contains a reserved glossary token")
        parts.append(text[cursor : match.start])
        parts.append(token)
        protected_matches.append(
            TermMatch(
                start=match.start,
                end=match.end,
                matched_text=match.matched_text,
                entry=match.entry,
                token=token,
            )
        )
        cursor = match.end
    parts.append(text[cursor:])
    return ProtectedText(text="".join(parts), matches=tuple(protected_matches))


def restore_text(translated_text: str, protected: ProtectedText) -> str:
    restored = translated_text
    for match in protected.matches:
        token_count = restored.count(match.token)
        if token_count != 1:
            raise GlossaryRestoreError(
                f"placeholder for {match.entry.id} occurred {token_count} times"
            )
        restored = restored.replace(match.token, match.entry.target, 1)
    return restored


def translate_with_glossary(
    text: str,
    entries: Sequence[TermEntry],
    source_language: str,
    target_language: str,
    translate: Callable[[str], str],
) -> tuple[str, tuple[dict[str, object], ...]]:
    """Protect terms, call a translator, restore terms, and return public hits."""

    protected = protect_text(text, entries, source_language, target_language)
    if not protected.matches:
        return translate(text), ()
    translated = translate(protected.text)
    restored = restore_text(translated, protected)
    return restored, tuple(match.public_dict() for match in protected.matches)
