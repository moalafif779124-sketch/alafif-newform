#!/usr/bin/env python3
"""REST probe of the LIVE Firestore rules for customer stock decrement.

Verifies against production (no device needed):
  1. anonymous sign-in works (profile-level auth the app uses)
  2. a signed-in customer CAN decrement stockQuantity (what createOrderWithStock does)
  3. the same customer CANNOT increase it        -> PERMISSION_DENIED
  4. an UNAUTHENTICATED caller cannot decrement  -> PERMISSION_DENIED

Uses a high-stock product so a 1-unit decrement is harmless.
"""
import json
import sys
import urllib.request
import urllib.error
from datetime import datetime, timezone

PROJECT = "alafif-newform"
API_KEY = json.load(open("/home/lattepanda/projects/alafif-newform/android/app/google-services.json"))[
    "client"
][0]["api_key"][0]["current_key"]
BASE = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"
PRODUCT_ID = "7m73npOcttyYi7EGullr"  # بدلات عراسي مصري — stock 501
PRODUCT_PATH = f"projects/{PROJECT}/databases/(default)/documents/products/{PRODUCT_ID}"


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
            return e.code, {"raw": body[:400]}


def anon_token():
    status, body = call(
        f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={API_KEY}",
        {"returnSecureToken": True},
    )
    if status != 200:
        print("SIGNUP FAILED", status, body)
        sys.exit(1)
    return body["idToken"], body["localId"]


def get_product():
    status, body = call(f"{BASE}/products/{PRODUCT_ID}?key={API_KEY}")
    if status != 200:
        print("READ FAILED", status, body)
        sys.exit(1)
    fields = body["fields"]
    stock = int(fields["stockQuantity"]["integerValue"])
    variants = {
        k: int(v["integerValue"])
        for k, v in fields.get("stockVariants", {}).get("mapValue", {}).get("fields", {}).items()
        if "integerValue" in v
    }
    return stock, variants, body["updateTime"]


def commit(new_stock, variants, update_time, token):
    fields = {
        "stockQuantity": {"integerValue": str(new_stock)},
        "stockVariants": {
            "mapValue": {
                "fields": {k: {"integerValue": str(v)} for k, v in variants.items()}
            }
        },
        "stockUpdatedAt": {"timestampValue": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")},
    }
    payload = {
        "writes": [
            {
                "update": {"name": PRODUCT_PATH, "fields": fields},
                "updateMask": {"fieldPaths": ["stockQuantity", "stockVariants", "stockUpdatedAt"]},
                "currentDocument": {"updateTime": update_time},
            }
        ]
    }
    return call(f"{BASE}:commit?key={API_KEY}", payload, token=token)


def main():
    print("==", datetime.now().strftime("%H:%M:%S"), "live rules probe ==")
    token, uid = anon_token()
    print(f"1) anonymous sign-in OK uid={uid[:8]}…")

    stock, variants, update_time = get_product()
    print(f"2) product stock before = {stock} variants={variants}")

    status, body = commit(stock - 1, variants, update_time, token)
    ok = status == 200
    print(f"3) signed-in DECREMENT -> {status} {'PASS' if ok else 'FAIL ' + json.dumps(body)[:300]}")
    if ok:
        after, _, _ = get_product()
        print(f"   stock now = {after} (expected {stock - 1}) -> "
              f"{'PASS' if after == stock - 1 else 'FAIL'}")
        stock, variants, update_time = after, variants, get_product()[2]
    else:
        sys.exit(2)

    status, body = commit(stock + 5, variants, update_time, token)
    denied = status == 403
    print(f"4) signed-in INCREASE  -> {status} {'PASS (denied)' if denied else 'FAIL ' + json.dumps(body)[:300]}")

    stock2, variants2, update2 = get_product()
    status, body = commit(stock2 - 1, variants2, update2, None)
    denied_anon = status == 403
    print(f"5) anonymous DECREMENT -> {status} {'PASS (denied)' if denied_anon else 'FAIL ' + json.dumps(body)[:300]}")

    ok = ok and denied and denied_anon
    print("== RESULT:", "ALL PASS" if ok else "FAILURES ABOVE", "==")
    sys.exit(0 if ok else 3)


if __name__ == "__main__":
    main()
