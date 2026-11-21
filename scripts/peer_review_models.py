#!/usr/bin/env python3
"""Discover free OpenCode models and cache Artificial Analysis rankings."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

AA_MODELS_URL = "https://artificialanalysis.ai/api/v2/language/models/free"
CACHE_NAME = "catalog/free-models.json"
CACHE_SCHEMA = 1


class ModelCatalogError(Exception):
    """A safe-to-display model discovery or ranking error."""


def free_opencode_models(payload: dict) -> list[dict]:
    """Return active, enabled OpenCode chat models whose full price is zero."""
    models = []
    for model in payload.get("data", []):
        if (model.get("providerID") != "opencode" or model.get("type") != "chat"
                or model.get("status") != "active" or not model.get("enabled")):
            continue
        costs = model.get("cost")
        if not costs or not all(
            isinstance(cost, dict)
            and cost.get("input") == 0
            and cost.get("output") == 0
            and all(value == 0 for value in cost.get("cache", {}).values())
            for cost in costs
        ):
            continue
        models.append({"id": model["id"], "name": model["name"]})
    return sorted(models, key=lambda model: model["id"])


def _normalized_name(name: str) -> str:
    name = re.sub(r"\s+free\s*$", "", name.strip(), flags=re.IGNORECASE)
    return re.sub(r"[^a-z0-9]", "", name.casefold())


def rank_models(free_models: list[dict], aa_catalog: dict) -> list[dict]:
    """Attach scores only when a normalized display name maps uniquely."""
    index = {}
    for model in aa_catalog.get("data", []):
        name = _normalized_name(model.get("name", ""))
        if name:
            index.setdefault(name, []).append(model)

    ranked = []
    for model in free_models:
        matches = index.get(_normalized_name(model["name"]), [])
        match = matches[0] if len(matches) == 1 else None
        evaluations = (match or {}).get("evaluations", {})
        score = evaluations.get("artificial_analysis_intelligence_index")
        if isinstance(score, bool) or not isinstance(score, (int, float)):
            score = None
        ranked.append({
            "id": model["id"],
            "display_name": model["name"],
            "aa_name": match.get("name") if match else None,
            "aa_slug": match.get("slug") if match else None,
            "intelligence_index": score,
        })
    return sorted(
        ranked,
        key=lambda model: (
            model["intelligence_index"] is None,
            -(model["intelligence_index"] or 0),
            model["display_name"].casefold(),
        ),
    )


def best_model(ranked_models: list[dict], excluded: set[str] | None = None) -> dict | None:
    excluded = excluded or set()
    return next((model for model in ranked_models
                 if model.get("intelligence_index") is not None
                 and model["id"] not in excluded), None)


def _availability(models: list[dict]) -> list[dict]:
    return sorted(({"id": model["id"], "name": model["name"]} for model in models),
                  key=lambda model: model["id"])


def _read_cache(path: Path) -> dict | None:
    try:
        cache = json.loads(path.read_text(encoding="utf-8"))
        if cache.get("schema") == CACHE_SCHEMA:
            return cache
    except (OSError, ValueError, AttributeError):
        pass
    return None


def _write_cache(path: Path, cache: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    path.parent.chmod(0o700)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=path.parent,
            prefix=".free-models-", delete=False,
        ) as handle:
            temporary = Path(handle.name)
            os.chmod(temporary, 0o600)
            json.dump(cache, handle, indent=2)
            handle.write("\n")
        temporary.replace(path)
        temporary = None
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def load_or_refresh(cache_path: Path, free_models: list[dict], fetch_catalog) -> tuple[dict, bool]:
    """Reuse AA data for the same OpenCode free-model availability set."""
    available = _availability(free_models)
    cached = _read_cache(cache_path)
    if cached and cached.get("availability") == available:
        return cached, False

    aa_catalog = fetch_catalog()
    cache = {
        "schema": CACHE_SCHEMA,
        "availability": available,
        "model_ids": [model["id"] for model in available],
        "refreshed_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "source": "Artificial Analysis Intelligence Index",
        "intelligence_index_version": aa_catalog.get("intelligence_index_version"),
        "models": rank_models(free_models, aa_catalog),
    }
    _write_cache(cache_path, cache)
    return cache, True


def _api_key() -> str:
    key = os.environ.get("ARTIFICIALANALYSIS_API_KEY", "").strip()
    if key:
        return key
    key_path = Path(os.environ.get(
        "PEER_REVIEW_AA_KEY_FILE",
        str(Path.home() / ".config" / "peer-review-aanalysis"),
    ))
    try:
        key = key_path.read_text(encoding="utf-8").strip()
    except OSError:
        key = ""
    if not key:
        raise ModelCatalogError(
            "Artificial Analysis key is missing; set ARTIFICIALANALYSIS_API_KEY "
            "or PEER_REVIEW_AA_KEY_FILE"
        )
    return key


def fetch_aa_catalog() -> dict:
    """Fetch all pages from the free-tier model endpoint in one refresh."""
    key = _api_key()
    entries = []
    total_pages = 1
    version = None
    page = 1
    while page <= total_pages:
        request = Request(
            f"{AA_MODELS_URL}?page={page}",
            headers={"x-api-key": key, "accept": "application/json"},
        )
        try:
            with urlopen(request, timeout=30) as response:
                payload = json.load(response)
        except HTTPError as exc:
            raise ModelCatalogError(
                f"Artificial Analysis request failed (HTTP {exc.code})"
            ) from None
        except (URLError, TimeoutError, ValueError, OSError) as exc:
            raise ModelCatalogError(
                f"Artificial Analysis request failed ({type(exc).__name__})"
            ) from None
        entries.extend(payload.get("data", []))
        pagination = payload.get("pagination", {})
        total_pages = pagination.get("total_pages", 1)
        version = payload.get("intelligence_index_version", version)
        page += 1
    return {"intelligence_index_version": version, "data": entries}


def discover_free_models() -> list[dict]:
    try:
        process = subprocess.run(
            ["opencode", "api", "GET", "/api/model"],
            capture_output=True, text=True, check=False,
        )
    except OSError:
        raise ModelCatalogError("OpenCode CLI is unavailable") from None
    if process.returncode:
        raise ModelCatalogError("OpenCode model discovery failed")
    try:
        payload = json.loads(process.stdout)
    except ValueError:
        raise ModelCatalogError("OpenCode returned an invalid model catalog") from None
    models = free_opencode_models(payload)
    if not models:
        raise ModelCatalogError("OpenCode has no available free chat models")
    return models


def _cache_path(cache_dir: str) -> Path:
    return Path(cache_dir) / CACHE_NAME


def _catalog_output(cache: dict | None, available: list[dict], refreshed: bool) -> dict:
    if cache is None:
        ranked = [{
            "id": model["id"], "display_name": model["name"],
            "aa_name": None, "aa_slug": None, "intelligence_index": None,
        } for model in available]
        ranked.sort(key=lambda model: model["display_name"].casefold())
        version = None
        timestamp = None
    else:
        ranked = cache["models"]
        version = cache.get("intelligence_index_version")
        timestamp = cache.get("refreshed_at")
    return {
        "cli": "opencode",
        "models": [{
            **model,
            "id": f"opencode/{model['id']}",
            "available_free": True,
        } for model in ranked],
        "ranking": {
            "source": "Artificial Analysis Intelligence Index",
            "version": version,
            "refreshed_at": timestamp,
            "refreshed_now": refreshed,
            "unavailable": cache is None,
        },
    }


def _resolve_model(available: list[dict], requested: str) -> dict:
    model_id = requested.removeprefix("opencode/")
    match = next((model for model in available if model["id"] == model_id), None)
    if match is None:
        raise ModelCatalogError(f"model is not an available free OpenCode model: {requested}")
    return match


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("list", "resolve"))
    parser.add_argument("--cache-dir", required=True)
    parser.add_argument("--model")
    parser.add_argument("--exclude", action="append", default=[])
    args = parser.parse_args()
    try:
        available = discover_free_models()
        if args.action == "resolve" and args.model:
            model = _resolve_model(available, args.model)
            print(json.dumps({"id": f"opencode/{model['id']}", "display_name": model["name"]}))
            return 0

        cache_path = _cache_path(args.cache_dir)
        try:
            cache, refreshed = load_or_refresh(cache_path, available, fetch_aa_catalog)
        except ModelCatalogError as exc:
            cached = _read_cache(cache_path)
            if cached and cached.get("availability") == _availability(available):
                cache, refreshed = cached, False
            elif cached and args.action == "resolve":
                # Availability changed but AA is unreachable: reuse stale scores.
                scores = {m["id"]: m for m in cached["models"]}
                stale = [scores.get(m["id"]) or {
                    "id": m["id"], "display_name": m["name"], "aa_name": None,
                    "aa_slug": None, "intelligence_index": None,
                } for m in available]
                cache = {**cached, "models": sorted(
                    stale, key=lambda m: (m["intelligence_index"] is None,
                                          -(m["intelligence_index"] or 0)))}
                refreshed = False
                print(f"peer-review: {exc}; using stale cached scores", file=sys.stderr)
            elif args.action == "list":
                print(json.dumps(_catalog_output(None, available, False), indent=2))
                print(f"peer-review: {exc}", file=sys.stderr)
                return 0
            else:
                raise

        result = _catalog_output(cache, available, refreshed)
        if args.action == "list":
            print(json.dumps(result, indent=2))
            return 0
        excluded = {
            model.removeprefix("opencode/")
            for item in args.exclude
            for model in item.split(",")
        }
        selected = best_model(cache["models"], excluded)
        if selected is None:
            raise ModelCatalogError(
                "no free OpenCode model has an Artificial Analysis score; "
                "choose one with --model"
            )
        print(json.dumps({
            "id": f"opencode/{selected['id']}",
            "display_name": selected["display_name"],
            "intelligence_index": selected["intelligence_index"],
            "index_version": cache.get("intelligence_index_version"),
            "refreshed_at": cache.get("refreshed_at"),
        }))
    except ModelCatalogError as exc:
        print(f"peer-review: {exc}", file=sys.stderr)
        return 1
    except OSError:
        print("peer-review: cannot access the model cache", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
