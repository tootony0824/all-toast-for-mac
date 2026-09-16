#!/usr/bin/env python3

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path
from urllib.parse import urlparse
from zoneinfo import ZoneInfo


BEIJING = ZoneInfo("Asia/Shanghai")


class ConversionError(ValueError):
    pass


def parse_args():
    parser = argparse.ArgumentParser(description="Convert a monitor-result JSON object to the All Toast for Mac notification contract.")
    parser.add_argument("--input", required=True, help="Monitor result JSON path, or - for stdin.")
    parser.add_argument("--title", required=True, help="Notification title.")
    parser.add_argument("--kind", choices=["auto", "single", "digest"], default="auto")
    parser.add_argument("--symbol", default="bell.fill")
    parser.add_argument("--accent", default="systemBlue")
    parser.add_argument("--sound", default="Glass")
    parser.add_argument("--max-items", type=int, default=10)
    return parser.parse_args()


def read_input(source):
    try:
        if source == "-":
            return json.load(sys.stdin)
        return json.loads(Path(source).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ConversionError(f"cannot read valid monitor JSON: {error}") from error


def parse_time(value):
    try:
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError as error:
        raise ConversionError(f"invalid date-time: {value}") from error
    if parsed.tzinfo is None:
        raise ConversionError(f"date-time has no timezone: {value}")
    return parsed.astimezone(BEIJING)


def display_time(value, now):
    published = parse_time(value)
    if published.date() == now.date():
        return f"今天 {published:%H:%M}"
    if (now.date() - published.date()).days == 1:
        return f"昨天 {published:%H:%M}"
    return f"{published:%m/%d %H:%M}"


def valid_url(value):
    parsed = urlparse(str(value))
    return parsed.scheme in {"http", "https"} and bool(parsed.netloc)


def compact(value, limit):
    text = " ".join(str(value or "").split())
    if len(text) <= limit:
        return text
    return text[: limit - 1].rstrip("，。；：,.!！?？ ") + "…"


def validate_result(result):
    if not isinstance(result, dict):
        raise ConversionError("monitor result must be an object")
    status = result.get("status")
    if status not in {"ok", "no_new", "partial", "fetch_failed"}:
        raise ConversionError(f"unsupported monitor status: {status}")
    if status in {"no_new", "fetch_failed"}:
        raise ConversionError(f"monitor status {status} has no notification to render")
    items = result.get("items")
    if not isinstance(items, list) or not items:
        raise ConversionError("monitor result contains no items")
    return items


def item_summary(item):
    summary = compact(item.get("summary") or "点击查看原文。", 108)
    verification = item.get("verification")
    if verification == "pending":
        summary = f"待核实 · {summary}"
    elif verification == "conflicting":
        summary = f"信息冲突 · {summary}"
    action = compact(item.get("action"), 48)
    if action and action not in summary:
        summary = compact(f"{summary} 建议：{action}", 150)
    return summary


def main():
    args = parse_args()
    if not 1 <= args.max_items <= 50:
        print(json.dumps({"status": "invalid_output", "error": "max-items must be between 1 and 50"}, ensure_ascii=False))
        return 2
    try:
        result = read_input(args.input)
        items = validate_result(result)[: args.max_items]
        now = datetime.now(BEIJING)
        normalized = []
        for index, item in enumerate(items):
            if not isinstance(item, dict):
                raise ConversionError(f"items[{index}] must be an object")
            if not valid_url(item.get("url")):
                raise ConversionError(f"items[{index}].url is invalid")
            normalized.append(
                {
                    "id": str(item.get("id") or item["url"]),
                    "title": compact(item.get("title") or "未命名信息", 72),
                    "time": display_time(item.get("publishedAt"), now),
                    "summary": item_summary(item),
                    "source": str(item.get("source") or "未知来源"),
                    "sourceType": item.get("sourceType", "unknown"),
                    "verification": item.get("verification", "unknown"),
                    "relevance": item.get("relevance", "unknown"),
                    "importance": item.get("importance", "unknown"),
                    "action": str(item.get("action") or ""),
                    "deadline": item.get("deadline"),
                    "url": item["url"],
                }
            )
    except (ConversionError, KeyError) as error:
        print(json.dumps({"status": "invalid_output", "error": str(error)}, ensure_ascii=False))
        return 2

    kind = args.kind
    if kind == "auto":
        kind = "single" if len(normalized) == 1 else "digest"
    common = {
        "schemaVersion": 1,
        "kind": kind,
        "monitor": result.get("monitor"),
        "title": args.title,
        "theme": {"symbol": args.symbol, "accent": args.accent},
        "sound": args.sound,
    }
    if kind == "single":
        item = normalized[0]
        notification = {
            **common,
            "message": compact(item["summary"], 55),
            "detail": item["summary"],
            "url": item["url"],
            "duration": 30,
        }
    else:
        start = parse_time(result["windowStart"])
        end = parse_time(result["windowEnd"])
        notification = {
            **common,
            "subtitle": f"{start:%m/%d %H:%M} - {end:%m/%d %H:%M} · {len(normalized)} 条",
            "sticky": True,
            "items": normalized,
        }
    print(json.dumps(notification, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
