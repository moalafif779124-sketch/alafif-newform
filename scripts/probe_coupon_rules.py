#!/usr/bin/env python3
"""Behavioural probe of the LIVE Firestore rules for the coupons feature.

Proves against production (alafif-newform) that:

  as a NORMAL signed-in customer (anonymous auth):
    1  get coupons/{CODE}                       -> ALLOWED (200)
    2  list the coupons collection              -> DENIED  (403)
    3  create a new coupon                      -> DENIED  (403)
    4  usedCount +1 (the real checkout write)   -> ALLOWED (200)
    5  usedCount +2 (skipping a use)            -> DENIED  (403)
    6  change the coupon value (50%)            -> DENIED  (403)
    7  usedCount beyond maxUses                 -> DENIED  (403)
    8  order with 60% discount + coupon fields  -> DENIED  (403)  (orders cap)

  as ANONYMOUS (no auth):
    9  get coupons/{CODE}                       -> DENIED  (403)

  as the shop OWNER (OAuth, bypasses rules):
   10  create / delete the probe coupon         -> ALLOWED      (setup+cleanup)

Usage:  python3 scripts/probe_coupon_rules.py
Needs a fresh Google OAuth access token in the path below (owner credentials).
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
DOCS = f"projects/{PROJECT}/databases/(default)/documents"
CODE = "PROBECODE"
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
    s, b = call(
        f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={API_KEY}",
        {"returnSecureToken": True},
    )
    if s != 200:
        print("SIGNUP FAILED", s, b)
        sys.exit(1)
    return b["idToken"], b["localId"]


def owner_token():
    return open(TOKEN_FILE).read().strip()


def coupon_fields(value=10, used=0, max_uses=3, active=True):
    return {
        "code": {"stringValue": CODE},
        "type": {"stringValue": "percent"},
        "value": {"integerValue": str(value)},
        "minSubtotal": {"integerValue": "0"},
        "maxUses": {"integerValue": str(max_uses)},
        "usedCount": {"integerValue": str(used)},
        "active": {"booleanValue": active},
        "updatedAt": {"timestampValue": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")},
    }


def write(path, fields, token, precondition=None):
    op = {"update": {"name": path, "fields": fields},
          "updateMask": {"fieldPaths": list(fields.keys())}}
    if precondition:
        op["currentDocument"] = precondition
    return call(f"{BASE}:commit?key={API_KEY}", {"writes": [op]}, token=token)


def main():
    results = []

    def check(name, got, want):
        ok = (got == want)
        results.append((name, ok))
        print(f"{'PASS' if ok else 'FAIL'}  {name}  (got {got}, want {want})")

    owner = owner_token()
    admin_path = f"{DOCS}/coupons/{CODE}"

    # ---- setup as owner (bypasses rules) ----
    s, _ = call(f"{BASE}/coupons/{CODE}?key={API_KEY}",
                {"fields": coupon_fields(used=0)}, token=owner, method="PATCH")
    print(f"setup: owner wrote probe coupon -> {s}")
    if s != 200:
        sys.exit("cannot seed coupon — check the OAuth token in " + TOKEN_FILE)

    uid_tok, uid = anon_token()

    # ---- 9 anonymous read ----
    s, _ = call(f"{BASE}/coupons/{CODE}?key={API_KEY}")
    check("anonymous get coupon is DENIED", s, 403)

    # ---- 1 signed-in get ----
    s, _ = call(f"{BASE}/coupons/{CODE}?key={API_KEY}", token=uid_tok)
    check("signed-in get coupon is ALLOWED", s, 200)

    # ---- 2 signed-in list ----
    s, _ = call(
        f"{BASE}:runQuery?key={API_KEY}",
        {"structuredQuery": {"from": [{"collectionId": "coupons"}], "limit": 5}},
        token=uid_tok,
    )
    check("signed-in list coupons is DENIED", s, 403)

    # ---- 3 signed-in create ----
    s, _ = call(f"{BASE}/coupons/HACKED?key={API_KEY}",
                {"fields": coupon_fields()}, token=uid_tok, method="PATCH")
    check("customer create coupon is DENIED", s, 403)

    # ---- 4 usedCount +1 (the real checkout write) ----
    s, _ = write(admin_path, {"usedCount": {"integerValue": "1"}}, uid_tok)
    check("customer usedCount 0->1 is ALLOWED", s, 200)

    # ---- 5 usedCount +2 (skip) ----
    s, _ = write(admin_path, {"usedCount": {"integerValue": "3"}}, uid_tok)
    check("customer usedCount 1->3 is DENIED", s, 403)

    # ---- 6 change value ----
    s, _ = write(admin_path, {"value": {"integerValue": "50"}}, uid_tok)
    check("customer changing coupon value is DENIED", s, 403)

    # ---- 7 beyond maxUses (maxUses=3, currently 1) ----
    write(admin_path, {"usedCount": {"integerValue": "2"}}, uid_tok)
    write(admin_path, {"usedCount": {"integerValue": "3"}}, uid_tok)
    s, _ = write(admin_path, {"usedCount": {"integerValue": "4"}}, uid_tok)
    check("customer usedCount beyond maxUses is DENIED", s, 403)

    # ---- 8 orders cap with coupon fields present ----
    order = {
        "userId": {"stringValue": uid},
        "orderNumber": {"stringValue": "ANF-PROBE-COUPON"},
        "status": {"stringValue": "pending"},
        "subtotal": {"integerValue": "20000"},
        "discount": {"integerValue": "12000"},  # 60% > the 50% cap
        "total": {"integerValue": "8000"},
        "paymentMethod": {"stringValue": "cod"},
        "paymentStatus": {"stringValue": "pending"},
        "couponCode": {"stringValue": CODE},
        "couponDiscount": {"integerValue": "12000"},
        "createdAt": {"timestampValue": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")},
    }
    s, _ = call(f"{BASE}/orders?key={API_KEY}", {"fields": order}, token=uid_tok, method="POST")
    check("order with 60% coupon discount is DENIED", s, 403)
    if s == 200:
        # cleanup if the rule let it through
        oid = _.get("name", "").split("/")[-1]
        call(f"{BASE}/orders/{oid}?key={API_KEY}", token=owner, method="DELETE")

    # ---- 10 owner can still delete ----
    s, _ = call(f"{BASE}/coupons/{CODE}?key={API_KEY}", token=owner, method="DELETE")
    check("owner delete coupon is ALLOWED (cleanup)", s, 200)

    passed = sum(1 for _, ok in results if ok)
    print(f"\n{passed}/{len(results)} PASS")
    sys.exit(0 if passed == len(results) else 1)


if __name__ == "__main__":
    main()
