"""Tests for free OpenCode model discovery and local benchmark caching."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import peer_review_models as models  # noqa: E402


def entry(model_id: str, name: str, *, provider: str = "opencode", enabled: bool = True,
          status: str = "active", model_type: str = "chat", input_cost: int = 0,
          output_cost: int = 0) -> dict:
    return {
        "id": model_id,
        "name": name,
        "providerID": provider,
        "type": model_type,
        "status": status,
        "enabled": enabled,
        "cost": [{"input": input_cost, "output": output_cost,
                  "cache": {"read": 0, "write": 0}}],
    }


class FreeModelTests(unittest.TestCase):
    def test_catalog_selects_only_enabled_active_zero_cost_chat_models(self) -> None:
        catalog = {"data": [
            entry("free", "Free"),
            entry("paid", "Paid", input_cost=0.1),
            entry("disabled", "Disabled", enabled=False),
            entry("old", "Old", status="deprecated"),
            entry("embedding", "Embedding", model_type="embedding"),
            entry("other-provider", "Other", provider="openai"),
        ]}

        self.assertEqual(models.free_opencode_models(catalog), [
            {"id": "free", "name": "Free"},
        ])

    def test_rank_uses_exact_name_match_and_leaves_ambiguous_models_unranked(self) -> None:
        free = [
            {"id": "glm-5.3-flash-free", "name": "GLM-5.3-Flash Free"},
            {"id": "mystery", "name": "Mystery Free"},
        ]
        aa = {
            "intelligence_index_version": 5,
            "data": [
                {"name": "GLM-5.3-Flash", "slug": "glm-5-3-flash",
                 "evaluations": {"artificial_analysis_intelligence_index": 42}},
                {"name": "Mystery", "slug": "mystery-a",
                 "evaluations": {"artificial_analysis_intelligence_index": 30}},
                {"name": "Mystery", "slug": "mystery-b",
                 "evaluations": {"artificial_analysis_intelligence_index": 35}},
            ],
        }

        ranked = models.rank_models(free, aa)

        self.assertEqual(ranked[0]["id"], "glm-5.3-flash-free")
        self.assertEqual(ranked[0]["intelligence_index"], 42)
        self.assertIsNone(ranked[1]["intelligence_index"])
        self.assertIsNone(ranked[1]["aa_slug"])

    def test_aa_catalog_is_reused_until_available_free_model_ids_change(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            cache = Path(tmp) / "catalog.json"
            free = [{"id": "glm-free", "name": "GLM Free"}]
            catalog = {"intelligence_index_version": 5, "data": []}
            fetch = Mock(return_value=catalog)

            first, refreshed = models.load_or_refresh(cache, free, fetch)
            second, refreshed_again = models.load_or_refresh(cache, free, fetch)

            self.assertTrue(refreshed)
            self.assertFalse(refreshed_again)
            self.assertEqual(fetch.call_count, 1)
            self.assertEqual(first, second)
            self.assertEqual(cache.stat().st_mode & 0o777, 0o600)

            changed, refreshed_changed = models.load_or_refresh(
                cache, [*free, {"id": "new-free", "name": "New Free"}], fetch,
            )
            self.assertTrue(refreshed_changed)
            self.assertEqual(fetch.call_count, 2)
            self.assertEqual(changed["model_ids"], ["glm-free", "new-free"])

    def test_best_model_ignores_unranked_models(self) -> None:
        ranked = [
            {"id": "unranked", "intelligence_index": None},
            {"id": "best", "intelligence_index": 50},
            {"id": "lower", "intelligence_index": 25},
        ]
        self.assertEqual(models.best_model(ranked)["id"], "best")
        self.assertIsNone(models.best_model([ranked[0]]))

    def test_best_model_can_skip_a_model_blocked_by_the_provider(self) -> None:
        ranked = [
            {"id": "blocked", "intelligence_index": 50},
            {"id": "next", "intelligence_index": 40},
        ]
        self.assertEqual(models.best_model(ranked, {"blocked"})["id"], "next")


if __name__ == "__main__":
    unittest.main()
