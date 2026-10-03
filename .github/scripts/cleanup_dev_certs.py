"""CI（xcodebuild の自動署名）が作った古い開発用証明書を削除する。

GitHub Actions のマシンは毎回まっさらなので、自動署名のたびに
「Apple Development: Created via API」という証明書が新しく作られ、
上限に達するとアーカイブが失敗する。アーカイブの前にそれだけを消す。

手動で作った証明書（名前に "Created via API" を含まないもの）と、
配布用（Distribution）の証明書には触れない。
"""
import json
import os
import sys
import time
import urllib.request

import jwt

API = "https://api.appstoreconnect.apple.com/v1"
DEV_TYPES = {"DEVELOPMENT", "IOS_DEVELOPMENT"}


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


def call(method: str, url: str, auth: str):
    req = urllib.request.Request(url, method=method, headers={"Authorization": f"Bearer {auth}"})
    with urllib.request.urlopen(req, timeout=30) as res:
        body = res.read()
        return json.loads(body) if body else None


def main() -> int:
    auth = token()
    data = call("GET", f"{API}/certificates?limit=200", auth)["data"]
    targets = []
    for cert in data:
        attr = cert.get("attributes", {})
        name = f"{attr.get('name', '')} {attr.get('displayName', '')}"
        if attr.get("certificateType") in DEV_TYPES and "Created via API" in name:
            targets.append(cert)

    print(f"証明書 {len(data)} 件のうち、CI が作った開発用証明書 {len(targets)} 件を削除します")
    for cert in targets:
        try:
            call("DELETE", f"{API}/certificates/{cert['id']}", auth)
        except Exception as e:  # 1件失敗しても続ける
            print(f"  削除に失敗：{cert['id']}（{e}）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
