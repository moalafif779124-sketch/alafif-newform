#!/usr/bin/env python3
"""Behavioural probe: a client-chosen order id cannot create two orders.

Checkout now sends `OrderRequestId` as the order DOCUMENT id (the transaction
reads that doc first). This proves the server side of that contract on the LIVE
ruleset (project alafif-newform):

  1  create with an explicit request id            -> 200
  2  repeat the same request id (a retry)          -> 409/403 (ALREADY_EXISTS at the
     document level, so the duplicate is impossible even if the app's
     early-return guard were bypassed)
  3  a different request id                        -> 200  (a genuinely new
     purchase still goes through)

Cleanup uses the shop-owner OAuth token.
Usage:  python3 scripts/probe_order_idempotency.py
"""
import json
import time
import urllib.request
import urllib.error

PROJECT = "alafif-newform"
API_KEY = json.load(open("android/app/google-services.json"))["client"][0]["api_key"][0]["current_key"]
BASE = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"
TOKEN_FILE = "/home/lattepanda/.hermes/cache/scratch/.gacc"


def call(url, payload=None, token=None, method=None):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method or ("POST" if data else "GET"))
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        try:
            return e.code, json.loads(body)
        except Exception:
            return e.code, {"raw": body[:300]}


def anon_token():
    s, b = call(f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={API_KEY}",
                {"returnSecureToken": True})
    assert s == 200, b
    return b["idToken"], b["localId"]


def body(uid):
    ts = int(time.time() * 1000)
    return {"fields": {
        "userId": {"stringValue": uid},
        "orderNumber": {"stringValue": f"PROBE-{ts}"},
        "status": {"stringValue": "pending"},
        "subtotal": {"doubleValue": 4000},
        "tax": {"doubleValue": 200},
        "shippingCost": {"doubleValue": 2000},
        "discount": {"doubleValue": 0},
        "total": {"doubleValue": 6200},
        "paymentMethod": {"stringValue": "cod"},
        "paymentStatus": {"stringValue": "pending"},
        "cityId": {"stringValue": "sanaa"},
        "createdAt": {"integerValue": str(ts)},
        "items": {"arrayValue": {"values": [{"mapValue": {"fields": {
            "productId": {"stringValue": "probe-prod"},
            "productName": {"stringValue": "probe"},
            "price": {"doubleValue": 4000},
            "quantity": {"integerValue": "1"},
            "size": {"stringValue": ""},
        }}}]}},
    }}


def rid():
    import random
    return f"req{int(time.time()*1000):x}{random.getrandbits(48):012x}"


def main():
    token, uid = anon_token()
    first, second = rid(), rid()
    results = []

    s1, _ = call(f"{BASE}/orders?documentId={first}", body(uid), token=token)
    print(f"{'✅' if s1 == 200 else '❌'} 1 create with request id {first}: {s1} (want 200)")
    results.append(s1 == 200)

    s2, b2 = call(f"{BASE}/orders?documentId={first}", body(uid), token=token)
    print(f"{'✅' if s2 in (403, 409) else '❌'} 2 same id again (retry): {s2} "
          f"(want 409/403 — cannot duplicate)")
    results.append(s2 in (403, 409))

    s3, _ = call(f"{BASE}/orders?documentId={second}", body(uid), token=token)
    print(f"{'✅' if s3 == 200 else '❌'} 3 different id (new purchase): {s3} (want 200)")
    results.append(s3 == 200)

    owner = open(TOKEN_FILE).read().strip()
    for oid in (first, second):
        call(f"{BASE}/orders/{oid}", token=owner, method="DELETE")
    print("cleaned 2 probe orders")

    ok = sum(results)
    print(f"RESULT: {ok}/{len(results)} as expected")
    return 0 if ok == len(results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
