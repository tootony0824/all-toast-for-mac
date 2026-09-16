#!/usr/bin/env python3

import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.parse import urlparse


MODERN_RENDERER = Path(__file__).resolve().parent.parent / "renderer/dist/All Toast for Mac.app/Contents/MacOS/all-toast-for-mac"


def default_renderer():
    configured = os.environ.get("ALL_TOAST_RENDERER") or os.environ.get("INFO_TOAST_RENDERER")
    if configured:
        return Path(configured)
    return MODERN_RENDERER


class NotificationError(ValueError):
    pass


def parse_args():
    parser = argparse.ArgumentParser(
        description="Validate a standard notification payload and render it with the macOS toast app."
    )
    parser.add_argument("--input", required=True, help="Path to notification JSON, or - for stdin.")
    parser.add_argument(
        "--renderer",
        type=Path,
        default=default_renderer(),
        help="Path to the compatible All Toast for Mac executable.",
    )
    parser.add_argument("--dry-run", action="store_true", help="Validate and print the render plan without showing UI.")
    return parser.parse_args()


def require_text(value, field):
    if not isinstance(value, str) or not value.strip():
        raise NotificationError(f"{field} must be a non-empty string")
    return value.strip()


def require_url(value, field):
    value = require_text(value, field)
    parsed = urlparse(value)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise NotificationError(f"{field} must be an http or https URL")
    return value


def load_payload(source):
    try:
        if source == "-":
            payload = json.load(sys.stdin)
        else:
            path = Path(source)
            payload = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise NotificationError(f"input file does not exist: {source}") from error
    except (OSError, json.JSONDecodeError) as error:
        raise NotificationError(f"cannot read valid JSON from {source}: {error}") from error
    if not isinstance(payload, dict):
        raise NotificationError("notification payload must be a JSON object")
    return payload


def validate_common(payload):
    if payload.get("schemaVersion") != 1:
        raise NotificationError("schemaVersion must be 1")
    kind = payload.get("kind")
    if kind not in {"single", "digest"}:
        raise NotificationError("kind must be single or digest")
    require_text(payload.get("title"), "title")
    sound = payload.get("sound", "Glass")
    if not isinstance(sound, str):
        raise NotificationError("sound must be a string")
    if "sticky" in payload and not isinstance(payload["sticky"], bool):
        raise NotificationError("sticky must be a boolean")
    return kind


def validate_single(payload):
    require_text(payload.get("message"), "message")
    require_url(payload.get("url"), "url")
    duration = payload.get("duration", 30)
    if not isinstance(duration, (int, float)) or isinstance(duration, bool) or not 1 <= duration <= 120:
        raise NotificationError("duration must be a number between 1 and 120")
    theme = payload.get("theme", {})
    if not isinstance(theme, dict):
        raise NotificationError("theme must be an object")
    if "iconPath" in theme and not isinstance(theme["iconPath"], str):
        raise NotificationError("theme.iconPath must be a string")


def validate_digest(payload):
    require_text(payload.get("subtitle"), "subtitle")
    items = payload.get("items")
    if not isinstance(items, list) or not items:
        raise NotificationError("items must be a non-empty array")
    for index, item in enumerate(items):
        prefix = f"items[{index}]"
        if not isinstance(item, dict):
            raise NotificationError(f"{prefix} must be an object")
        for field in ("id", "title", "time", "summary"):
            require_text(item.get(field), f"{prefix}.{field}")
        require_url(item.get("url"), f"{prefix}.url")
        verification = item.get("verification", "unknown")
        if verification not in {"verified", "pending", "conflicting", "unknown"}:
            raise NotificationError(f"{prefix}.verification is invalid")


def build_single_command(payload, renderer):
    command = [
        str(renderer),
        "--title", payload["title"].strip(),
        "--message", payload["message"].strip(),
        "--url", payload["url"],
        "--duration", str(payload.get("duration", 30)),
        "--sound", payload.get("sound", "Glass"),
    ]
    theme = payload.get("theme", {})
    if theme.get("symbol"):
        command.extend(["--symbol", theme["symbol"]])
    if theme.get("accent"):
        command.extend(["--accent", theme["accent"]])
    detail = payload.get("detail")
    if isinstance(detail, str) and detail.strip():
        command.extend(["--detail", detail.strip()])
    icon_path = theme.get("iconPath")
    if icon_path:
        command.extend(["--icon", icon_path])
    if payload.get("sticky"):
        command.append("--sticky")
    return command, None


def build_digest_command(payload, renderer, dry_run):
    legacy_payload = {
        "title": payload["title"].strip(),
        "window": payload["subtitle"].strip(),
        "theme": payload.get("theme", {}),
        "items": [
            {
                "title": item["title"].strip(),
                "time": item["time"].strip(),
                "summary": item["summary"].strip(),
                "source": item.get("source"),
                "verification": item.get("verification"),
                "action": item.get("action"),
                "url": item["url"],
            }
            for item in payload["items"]
        ],
    }
    if dry_run:
        digest_path = Path("<temporary-digest-json>")
    else:
        handle = tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            prefix="all-toast-",
            suffix=".json",
            delete=False,
        )
        with handle:
            json.dump(legacy_payload, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
        digest_path = Path(handle.name)
    command = [
        str(renderer),
        "--digest-json", str(digest_path),
        "--sound", payload.get("sound", "Glass"),
        "--duration", str(payload.get("duration", 30)),
    ]
    theme = payload.get("theme", {})
    if theme.get("symbol"):
        command.extend(["--symbol", theme["symbol"]])
    if theme.get("accent"):
        command.extend(["--accent", theme["accent"]])
    if payload.get("sticky", True):
        command.append("--sticky")
    return command, legacy_payload


def main():
    args = parse_args()
    try:
        payload = load_payload(args.input)
        kind = validate_common(payload)
        if kind == "single":
            validate_single(payload)
            command, renderer_payload = build_single_command(payload, args.renderer)
        else:
            validate_digest(payload)
            command, renderer_payload = build_digest_command(payload, args.renderer, args.dry_run)
    except NotificationError as error:
        print(json.dumps({"status": "invalid_output", "error": str(error)}, ensure_ascii=False))
        return 2

    result = {
        "status": "validated" if args.dry_run else "shown",
        "kind": kind,
        "monitor": payload.get("monitor"),
        "renderer": str(args.renderer),
        "command": command,
    }
    if renderer_payload is not None:
        result["rendererPayload"] = renderer_payload

    if args.dry_run:
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    if not args.renderer.is_file():
        print(
            json.dumps(
                {"status": "render_missing", "path": str(args.renderer)},
                ensure_ascii=False,
            )
        )
        return 3
    try:
        subprocess.Popen(
            command,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except OSError as error:
        print(json.dumps({"status": "render_failed", "error": str(error)}, ensure_ascii=False))
        return 4
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
