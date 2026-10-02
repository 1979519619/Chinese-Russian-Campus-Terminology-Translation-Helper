import importlib.util
import sys
import unittest
from pathlib import Path


# Load the dependency-free core without importing LibreTranslate's package
# entrypoint, which intentionally requires the full Argos runtime.
MODULE_PATH = Path(__file__).parents[1] / "campus_glossary.py"
SPEC = importlib.util.spec_from_file_location("campus_glossary_under_test", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)

GlossaryRestoreError = MODULE.GlossaryRestoreError
GlossaryValidationError = MODULE.GlossaryValidationError
ProtectedText = MODULE.ProtectedText
TermEntry = MODULE.TermEntry
find_matches = MODULE.find_matches
load_default_glossary = MODULE.load_default_glossary
normalize_language = MODULE.normalize_language
protect_text = MODULE.protect_text
restore_text = MODULE.restore_text
translate_with_glossary = MODULE.translate_with_glossary
validate_records = MODULE.validate_records


def entry(
    entry_id,
    source,
    target,
    *,
    direction="zh-Hans_to_ru",
    status="demo",
    priority=100,
    aliases=(),
):
    return TermEntry(
        id=entry_id,
        source=source,
        target=target,
        direction=direction,
        category="测试",
        source_ref="test-fixture",
        status=status,
        priority=priority,
        updated_at="2026-09-27",
        aliases=tuple(aliases),
    )


class CampusGlossaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.entries = load_default_glossary()

    def test_01_seed_has_forty_records(self):
        self.assertEqual(len(self.entries), 40)

    def test_02_seed_ids_are_unique(self):
        self.assertEqual(len({item.id for item in self.entries}), 40)

    def test_03_seed_is_demo_only(self):
        self.assertEqual({item.status for item in self.entries}, {"demo"})

    def test_04_normalizes_simplified_chinese_alias(self):
        self.assertEqual(normalize_language("zh-Hans"), "zh")

    def test_05_matches_chinese_to_russian(self):
        matches = find_matches("我正在学习数据库。", self.entries, "zh-Hans", "ru")
        self.assertEqual(matches[0].entry.target, "база данных")

    def test_06_matches_russian_to_chinese(self):
        matches = find_matches("Курс: база данных.", self.entries, "ru", "zh-Hans")
        self.assertEqual(matches[0].entry.target, "数据库")

    def test_07_wrong_direction_does_not_match(self):
        self.assertEqual(find_matches("数据库", self.entries, "ru", "zh"), ())

    def test_08_unmatched_text_is_unchanged_by_protection(self):
        protected = protect_text("今天天气很好", self.entries, "zh", "ru")
        self.assertEqual(protected, ProtectedText("今天天气很好", ()))

    def test_09_protects_and_restores_one_term(self):
        protected = protect_text("数据库课程", self.entries, "zh", "ru")
        self.assertNotIn("数据库", protected.text)
        self.assertEqual(restore_text(protected.text, protected), "база данных课程")

    def test_10_protects_and_restores_two_terms_in_order(self):
        protected = protect_text("数据库与数据结构", self.entries, "zh", "ru")
        self.assertEqual(len(protected.matches), 2)
        self.assertEqual(
            restore_text(protected.text, protected),
            "база данных与структуры данных",
        )

    def test_11_longer_overlap_wins(self):
        terms = (entry("short", "数据", "данные"), entry("long", "数据库", "база данных"))
        matches = find_matches("数据库", terms, "zh", "ru")
        self.assertEqual([match.entry.id for match in matches], ["long"])

    def test_12_verified_status_wins_overlap(self):
        terms = (
            entry("demo-long", "数据库", "A", status="demo"),
            entry("verified-short", "数据", "B", status="verified"),
        )
        matches = find_matches("数据库", terms, "zh", "ru")
        self.assertEqual([match.entry.id for match in matches], ["verified-short"])

    def test_13_priority_breaks_same_length_tie(self):
        terms = (
            entry("low", "数据库", "A", priority=10),
            entry("high", "数据库", "B", priority=20),
        )
        self.assertEqual(find_matches("数据库", terms, "zh", "ru")[0].entry.id, "high")

    def test_14_alias_can_match(self):
        terms = (entry("alias", "课程作业", "A", aliases=("作业",)),)
        self.assertEqual(find_matches("提交作业", terms, "zh", "ru")[0].matched_text, "作业")

    def test_15_russian_requires_word_boundary(self):
        terms = (entry("ru", "курс", "课程", direction="ru_to_zh-Hans"),)
        self.assertEqual(find_matches("экскурс", terms, "ru", "zh"), ())

    def test_16_russian_matches_with_punctuation_boundary(self):
        terms = (entry("ru", "курс", "课程", direction="ru_to_zh-Hans"),)
        self.assertEqual(len(find_matches("курс!", terms, "ru", "zh")), 1)

    def test_17_missing_placeholder_raises(self):
        protected = protect_text("数据库", self.entries, "zh", "ru")
        with self.assertRaises(GlossaryRestoreError):
            restore_text("token was lost", protected)

    def test_18_duplicated_placeholder_raises(self):
        protected = protect_text("数据库", self.entries, "zh", "ru")
        duplicated = protected.text + protected.text
        with self.assertRaises(GlossaryRestoreError):
            restore_text(duplicated, protected)

    def test_19_reserved_input_token_raises(self):
        with self.assertRaises(GlossaryRestoreError):
            protect_text("[0-0]数据库", self.entries, "zh", "ru")

    def test_20_translation_wrapper_preserves_term(self):
        result, hits = translate_with_glossary(
            "数据库很重要",
            self.entries,
            "zh",
            "ru",
            lambda text: text.replace("很重要", " важна"),
        )
        self.assertEqual(result, "база данных важна")
        self.assertEqual(hits[0]["status"], "demo")

    def test_21_translation_wrapper_uses_plain_path_without_hit(self):
        calls = []

        def translate(text):
            calls.append(text)
            return "обычный текст"

        result, hits = translate_with_glossary("普通文本", self.entries, "zh", "ru", translate)
        self.assertEqual(result, "обычный текст")
        self.assertEqual(hits, ())
        self.assertEqual(calls, ["普通文本"])

    def test_22_public_hit_does_not_expose_internal_positions(self):
        _, hits = translate_with_glossary("数据库", self.entries, "zh", "ru", lambda text: text)
        self.assertEqual(
            set(hits[0]),
            {"id", "source", "target", "category", "sourceRef", "status"},
        )

    def test_23_validation_rejects_non_list_root(self):
        with self.assertRaises(GlossaryValidationError):
            validate_records({})

    def test_24_validation_rejects_duplicate_ids(self):
        record = {
            "id": "x",
            "source": "a",
            "target": "b",
            "direction": "zh-Hans_to_ru",
            "category": "test",
            "source_ref": "test",
            "status": "demo",
            "priority": 1,
            "updated_at": "2026-09-27",
        }
        with self.assertRaises(GlossaryValidationError):
            validate_records([record, dict(record)])

    def test_25_validation_rejects_bad_status(self):
        record = {
            "id": "x",
            "source": "a",
            "target": "b",
            "direction": "zh-Hans_to_ru",
            "category": "test",
            "source_ref": "test",
            "status": "official",
            "priority": 1,
            "updated_at": "2026-09-27",
        }
        with self.assertRaises(GlossaryValidationError):
            validate_records([record])

    def test_26_validation_rejects_bad_date(self):
        record = {
            "id": "x",
            "source": "a",
            "target": "b",
            "direction": "zh-Hans_to_ru",
            "category": "test",
            "source_ref": "test",
            "status": "demo",
            "priority": 1,
            "updated_at": "27-09-2026",
        }
        with self.assertRaises(GlossaryValidationError):
            validate_records([record])

    def test_27_empty_text_has_no_match(self):
        self.assertEqual(find_matches("", self.entries, "zh", "ru"), ())

    def test_28_repeated_term_creates_distinct_tokens(self):
        protected = protect_text("数据库和数据库", self.entries, "zh", "ru")
        self.assertEqual(len(protected.matches), 2)
        self.assertNotEqual(protected.matches[0].token, protected.matches[1].token)

    def test_29_stable_id_breaks_complete_tie(self):
        terms = (entry("b", "数据库", "B"), entry("a", "数据库", "A"))
        self.assertEqual(find_matches("数据库", terms, "zh", "ru")[0].entry.id, "a")

    def test_30_match_positions_reconstruct_source(self):
        text = "学习数据库和数据结构"
        matches = find_matches(text, self.entries, "zh", "ru")
        self.assertEqual([text[m.start : m.end] for m in matches], ["数据库", "数据结构"])


if __name__ == "__main__":
    unittest.main()
