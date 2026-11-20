#!/usr/bin/env python3
"""Import AI Bridge groups: group ratios, user-selectable groups and model lists.

Reads deploy/import/model-groups.json and writes, through the admin API:
  - option GroupRatio          group name -> price ratio (discount of official price)
  - option UserUsableGroups    group name -> description shown to users
  - prefill groups (type=model) group name -> supported model list

Existing entries for other groups are kept; entries with the same name are updated.

Usage:
  BASE_URL=http://localhost:3000 ACCESS_TOKEN=xxx python3 deploy/import-groups.py [--dry-run]
ACCESS_TOKEN is a root user's personal access token (Settings -> Personal -> Access token).
Set USER_ID too if your deployment requires the New-Api-User header.
"""
import json
import os
import sys
import urllib.request

BASE_URL = os.environ.get("BASE_URL", "http://localhost:3000").rstrip("/")
TOKEN = os.environ.get("ACCESS_TOKEN", "")
USER_ID = os.environ.get("USER_ID", "")
DRY = "--dry-run" in sys.argv
DATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "import", "model-groups.json")


def call(method, path, body=None):
    headers = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}
    if USER_ID:
        headers["New-Api-User"] = USER_ID
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE_URL + path, data=data, method=method, headers=headers)
    with urllib.request.urlopen(req, timeout=30) as resp:
        out = json.load(resp)
    if not out.get("success"):
        sys.exit(f"{method} {path} failed: {out.get('message')}")
    return out.get("data")


def main():
    if not TOKEN and not DRY:
        sys.exit("ACCESS_TOKEN is required (use --dry-run to only preview)")
    with open(DATA, encoding="utf-8") as f:
        groups = json.load(f)["groups"]

    ratios = {g["name"]: g["group_ratio"] for g in groups}
    usable = {
        g["name"]: f'{g["name"]}（倍率 {g["rate"]}，官方价格的 {g["discount_percent"]}%）' for g in groups
    }

    if DRY:
        print("GroupRatio      :", json.dumps(ratios, ensure_ascii=False))
        print("UserUsableGroups:", json.dumps(usable, ensure_ascii=False))
        for g in groups:
            print(f'prefill {g["name"]:16} -> {", ".join(g["models"])}')
        return

    options = {o["key"]: o["value"] for o in call("GET", "/api/option/")}
    for key, new in (("GroupRatio", ratios), ("UserUsableGroups", usable)):
        merged = json.loads(options.get(key) or "{}")
        merged.update(new)
        call("PUT", "/api/option/", {"key": key, "value": json.dumps(merged, ensure_ascii=False)})
        print(f"updated option {key} ({len(new)} groups)")

    existing = {p["name"]: p for p in call("GET", "/api/prefill_group/?type=model") or []}
    for g in groups:
        body = {
            "name": g["name"],
            "type": "model",
            "items": g["models"],
            "description": f'{g["category"]} 分组支持的模型',
        }
        if g["name"] in existing:
            call("PUT", "/api/prefill_group/", {**body, "id": existing[g["name"]]["id"]})
            print("updated prefill group", g["name"])
        else:
            call("POST", "/api/prefill_group/", body)
            print("created prefill group", g["name"])


if __name__ == "__main__":
    main()
