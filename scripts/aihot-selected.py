#!/usr/bin/env python3

import argparse
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone


API_URL = "https://aihot.virxact.com/api/public/items"
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/124.0.0.0 Safari/537.36"
)
CATEGORIES = {"ai-models", "ai-products", "industry", "paper", "tip"}


def parse_args():
    parser = argparse.ArgumentParser(description="Read AIHOT selected items and emit the local monitor-result contract.")
    parser.add_argument("--since-hours", type=int, default=24, help="Rolling lookback window, from 1 to 168 hours.")
    parser.add_argument("--take", type=int, default=50, help="Maximum number of selected items, from 1 to 100.")
    parser.add_argument("--category", choices=sorted(CATEGORIES))
    parser.add_argument("--query", help="Optional server-side keyword search.")
    return parser.parse_args()


def iso_z(value):
    return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def fail(message, start, end):
    print(
        json.dumps(
            {
                "status": "fetch_failed",
                "monitor": "aihot-selected",
                "checkedAt": iso_z(end),
                "windowStart": iso_z(start),
                "windowEnd": iso_z(end),
                "items": [],
                "errors": [{"source": "aihot", "message": message}],
            },
            ensure_ascii=False,
        )
    )


def normalize_item(item):
    identifier = item.get("id") or item.get("url") or item.get("title")
    title = item.get("title")
    url = item.get("url")
    source = item.get("source")
    published_at = item.get("publishedAt")
    if not all(isinstance(value, str) and value.strip() for value in (identifier, title, url, source, published_at)):
        return None
    return {
        "id": identifier.strip(),
        "title": title.strip(),
        "summary": " ".join(str(item.get("summary") or "点击原文查看完整内容。").split()),
        "source": source.strip(),
        "sourceType": "unknown",
        "publishedAt": published_at.strip(),
        "url": url.strip(),
        "verification": "unknown",
        "relevance": "direct",
        "importance": "important",
        "action": "点击原文查看完整信息",
        "deadline": None,
    }


def main():
    args = parse_args()
    if not 1 <= args.since_hours <= 168:
        print(json.dumps({"status": "invalid_output", "error": "since-hours must be between 1 and 168"}, ensure_ascii=False))
        return 2
    if not 1 <= args.take <= 100:
        print(json.dumps({"status": "invalid_output", "error": "take must be between 1 and 100"}, ensure_ascii=False))
        return 2
    if args.query is not None and len(args.query.strip()) < 2:
        print(json.dumps({"status": "invalid_output", "error": "query must contain at least 2 characters"}, ensure_ascii=False))
        return 2

    window_end = datetime.now(timezone.utc)
    window_start = window_end - timedelta(hours=args.since_hours)
    params = {
        "mode": "selected",
        "since": iso_z(window_start),
        "take": str(args.take),
    }
    if args.category:
        params["category"] = args.category
    if args.query:
        params["q"] = args.query.strip()
    request = urllib.request.Request(
        f"{API_URL}?{urllib.parse.urlencode(params)}",
        headers={"User-Agent": USER_AGENT},
    )
    try:
        with urllib.request.urlopen(request, timeout=25) as response:
            raw = json.load(response)
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError) as error:
        fail(str(error), window_start, window_end)
        return 1

    raw_items = raw.get("items", []) if isinstance(raw, dict) else []
    items = []
    for raw_item in raw_items:
        if isinstance(raw_item, dict):
            normalized = normalize_item(raw_item)
            if normalized:
                items.append(normalized)
    result = {
        "status": "ok" if items else "no_new",
        "monitor": "aihot-selected",
        "checkedAt": iso_z(window_end),
        "windowStart": iso_z(window_start),
        "windowEnd": iso_z(window_end),
        "items": items,
        "errors": [],
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
