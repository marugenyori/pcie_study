"""App ID（Bundle ID）に Capability / App Service を App Store Connect API で追加する。

Apple Developer の画面で「Identifiers → App ID → チェックを入れて Save」するのと同じ。
すでに入っていれば何もしない。使えない種類を指定したときは、API が返す
「使える種類の一覧」をそのまま表示する。

使い方: enable_capability.py <capabilityType> <bundle identifier>
"""
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt

API = "https://api.appstoreconnect.apple.com/v1"


def token() -> str:
    with open(os.environ["ASC_KEY_PATH"], encoding="utf-8") as f:
        key = f.read()
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
        key,
        algorithm="ES256",
        headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"},
    )


def call(method: str, url: str, auth: str, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": f"Bearer {auth}",
        "Content-Type": "application/json",
    })
    try:
        with urllib.request.urlopen(req, timeout=30) as res:
            raw = res.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        # API のエラーの中身（使える値の一覧など）を表示してから止める
        print(f"{method} {url} → HTTP {e.code}")
        print(e.read().decode(errors="replace"))
        raise


def main() -> int:
    capability, identifier = sys.argv[1], sys.argv[2]
    auth = token()

    query = urllib.parse.urlencode({"filter[identifier]": identifier, "limit": 200})
    bundles = call("GET", f"{API}/bundleIds?{query}", auth)["data"]
    # filter は前方一致なので、ウィジェット（.widget）などを除いて完全一致のものを選ぶ
    bundle = next((b for b in bundles if b["attributes"]["identifier"] == identifier), None)
    if bundle is None:
        print(f"::error::App ID {identifier} が見つかりません")
        return 1

    current = call("GET", f"{API}/bundleIds/{bundle['id']}/bundleIdCapabilities", auth)["data"]
    names = sorted(c["attributes"]["capabilityType"] for c in current)
    print(f"{identifier} の現在の設定: {', '.join(names) or '（なし）'}")
    if capability in names:
        print(f"{capability} はすでに有効です")
        return 0

    body = {"data": {
        "type": "bundleIdCapabilities",
        "attributes": {"capabilityType": capability},
        "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bundle["id"]}}},
    }}
    try:
        call("POST", f"{API}/bundleIdCapabilities", auth, body)
    except urllib.error.HTTPError as e:
        print(f"::error::{capability} を有効にできませんでした（HTTP {e.code}）")
        return 1
    print(f"{capability} を有効にしました")
    return 0


if __name__ == "__main__":
    sys.exit(main())
