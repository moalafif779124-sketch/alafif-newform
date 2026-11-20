#!/usr/bin/env python3
"""Behavioural probe: the customer's post-create order writes.

The checkout screen creates the order, THEN calls update() twice:
  (1) regional delivery fields (city, cityId, streetAddress, district,
      nearestLandmark, recipientPhone, deliveryNotes, shippingCost,
      pointsUsed, pointsDiscount)
  (2) transfer proof (transactionRef, transferMethod, receiptImageBase64)
while the order is still `pending`. If the update rule whitelist does not
cover those fields, both writes 403 inside try/catch -> the order keeps
transactionRef: null and no delivery details, and nobody notices.

Proves on the LIVE ruleset (project alafif-newform):
  1  pending order: PATCH transactionRef + delivery fields      -> 200
  2  pending order: PATCH total (money field)                   -> 403
  3  cancelled order: PATCH transactionRef                      -> 403
  4  anonymous (no auth): PATCH transactionRef                  -> 403

Cleanup uses the shop-owner OAuth token (anon users cannot delete).

Usage:  python3 scripts/probe_order_proof_rules.py
"""
import json
import sys
import urllib.request
import urllib.error

PROJECT = "alafif-newform"
API_KEY = json.load(open("android/app/google-services.json"))["client"][0]["api_key"][0]["current_key"]
BASE = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"
DOCS = f"projects/{PROJECT}/databases/(default)/documents"
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


def order_doc(user_id, status="pending"):
    # يجب أن يطابق `orderMoneyValid()` في firestore.rules:
    # الضريبة 5% من المجموع الفرعي، والتوصيل سعر المحافظة، والإجمالي = مجموعهما.
    return {"fields": {
        "userId": {"stringValue": user_id},
        "status": {"stringValue": status},
        "subtotal": {"doubleValue": 20000},
        "tax": {"doubleValue": 1000},
        "shippingCost": {"doubleValue": 2000},
        "cityId": {"stringValue": "sanaa"},
        "total": {"doubleValue": 23000},
        "discount": {"doubleValue": 0},
        "paymentMethod": {"stringValue": "cod"},
        "paymentStatus": {"stringValue": "pending"},
        "createdAt": {"integerValue": "1"},
    }}


def commit(writes, token):
    return call(f"{BASE}:commit?key={API_KEY}", {"writes": writes}, token)


results = []


def check(name, got, want):
    ok = got == want
    results.append(ok)
    print(f"{'PASS' if ok else 'FAIL'}  {name}: {got} (want {want})")


def main():
    owner = open(TOKEN_FILE).read().strip()
    uid_token, uid = anon_token()
    print(f"anon uid: {uid}")

    # --- 1. pending order -> proof/delivery update ALLOWED
    name = f"{DOCS}/orders/PROBE-PENDING-{uid[:6]}"
    s, b = commit([{"update": {"name": name, "fields": order_doc(uid)["fields"]}}], uid_token)
    check("create pending order", s, 200)
    s, b = commit([{
        "update": {"name": name, "fields": {
            "transactionRef": {"stringValue": "TRX-1"},
            "transferMethod": {"stringValue": "kuraimi"},
            "city": {"stringValue": "صنعاء"},
            "shippingCost": {"doubleValue": 2000},
        }},
        "updateMask": {"fieldPaths": ["transactionRef", "transferMethod", "city", "shippingCost"]},
    }], uid_token)
    check("pending: attach proof + delivery", s, 200)

    # --- 2. money field still blocked
    s, b = commit([{
        "update": {"name": name, "fields": {"total": {"doubleValue": 1}}},
        "updateMask": {"fieldPaths": ["total"]},
    }], uid_token)
    check("pending: rewrite total", s, 403)

    # --- 3. cancelled order -> proof update blocked
    s, b = commit([{
        "update": {"name": name, "fields": {
            "status": {"stringValue": "cancelled"},
            "cancelledAt": {"integerValue": "2"},
        }},
        "updateMask": {"fieldPaths": ["status", "cancelledAt"]},
    }], uid_token)
    check("cancel own order", s, 200)
    s, b = commit([{
        "update": {"name": name, "fields": {"transactionRef": {"stringValue": "TRX-2"}}},
        "updateMask": {"fieldPaths": ["transactionRef"]},
    }], uid_token)
    check("cancelled: attach proof", s, 403)

    # --- 4. anonymous write blocked
    s, b = commit([{
        "update": {"name": name, "fields": {"transactionRef": {"stringValue": "TRX-3"}}},
        "updateMask": {"fieldPaths": ["transactionRef"]},
    }], None)
    check("anonymous: attach proof", s, 403)

    # cleanup with owner token
    call(f"{BASE}/orders/PROBE-PENDING-{uid[:6]}?key={API_KEY}", None, owner, method="DELETE")
    print("cleanup done")
    sys.exit(0 if all(results) else 1)


if __name__ == "__main__":
    main()
