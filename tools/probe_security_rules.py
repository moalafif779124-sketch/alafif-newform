#!/usr/bin/env python3
"""Behavioural probe of the LIVE Firestore rules for the security fixes.

Proves against production, as a normal signed-in customer (anonymous auth):
  PASS means the rule behaved as intended.

  1  create own user doc with isAdmin:true        -> DENIED (403)
  2  create own user doc (isAdmin:false)          -> ALLOWED
  3  set isAdmin:true on own user doc             -> DENIED
  4  update own name                               -> ALLOWED
  5  create order with discount = 100% of subtotal -> DENIED
  6  create order with discount = 10%              -> ALLOWED
  7  rewrite that order's total                    -> DENIED
  8  flip that order's status to 'delivered'       -> DENIED
  9  cancel that order (status=cancelled)          -> ALLOWED
 10  referral with referrerUid == self             -> DENIED

Leftovers: one throwaway anonymous user doc + one TEST-tagged cancelled order.
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


def commit(ops, token):
    return call(f"{BASE}:commit?key={API_KEY}", {"writes": ops}, token=token)


def update_op(path, fields):
    return {
        "update": {"name": path, "fields": fields},
        "updateMask": {"fieldPaths": list(fields.keys())},
    }


def sv(v):
    return {"stringValue": v}


def iv(v):
    return {"integerValue": str(v)}


def ts_now():
    return {"timestampValue": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")}


def main():
    results = []

    def check(name, got, want):
        ok = (got == want) if isinstance(want, int) else (got in want)
        results.append(ok)
        verdict = "PASS" if ok else "FAIL"
        print(f"[{verdict}] {name}: got {got}, want {want}")
        return ok

    token, uid = anon_token()
    print(f"== security probe as customer uid={uid[:8]}… ==\n")
    user_path = f"{DOCS}/users/{uid}"

    # 1) create own doc claiming admin
    person = {"name": sv("Probe"), "phone": sv("7" + uid[:8]), "isAdmin": {"booleanValue": True}}
    s, _ = commit([{"update": {"name": user_path, "fields": person}}], token)
    check("1 create own user doc with isAdmin:true", s, 403)

    # 2) create own doc as a normal customer
    person_ok = {"name": sv("Probe"), "phone": sv("7" + uid[:8]), "isAdmin": {"booleanValue": False}}
    s, _ = commit([{"update": {"name": user_path, "fields": person_ok}}], token)
    check("2 create own user doc (isAdmin:false)", s, 200)

    # 3) escalate own privilege
    s, _ = commit([update_op(user_path, {"isAdmin": {"booleanValue": True}})], token)
    check("3 set isAdmin:true on own doc", s, 403)

    # 4) ordinary profile edit still works
    s, _ = commit([update_op(user_path, {"name": sv("Probe 2")})], token)
    check("4 update own profile name", s, 200)

    # 4b) the fields the app itself writes must keep working
    s, _ = commit([update_op(user_path, {
        "fcmTokens": {"arrayValue": {"values": [sv("probe-token")]}},
        "notificationTopics": {"arrayValue": {"values": [sv("offers")]}},
        "points": iv(50),
        "streakDays": iv(1),
    })], token)
    check("4b update fcmTokens/topics/points (app paths)", s, 200)

    # 4c) but a moderation field must stay admin-only
    s, _ = commit([update_op(user_path, {"status": sv("active")})], token)
    check("4c update non-whitelisted field", s, 403)

    # 5) order with a self-approved 100% discount
    order_base = {
        "userId": sv(uid),
        "orderNumber": sv("TEST-SEC"),
        "items": {"arrayValue": {"values": []}},
        "status": sv("pending"),
        "subtotal": iv(10000),
        "shipping": iv(2000),
        "notes": sv("TEST-SECURITY — automated rules probe, safe to delete"),
        "createdAt": ts_now(),
    }
    s, _ = commit(
        [{"update": {"name": f"{DOCS}/orders/fake-{uid[:6]}",
                     "fields": dict(order_base, discount=iv(10000), total=iv(2000))}}],
        token,
    )
    check("5 create order with 100% discount", s, 403)

    # 6) legitimate order (10% discount)
    order_id = f"test-ok-{uid[:8]}"
    order_path = f"{DOCS}/orders/{order_id}"
    s, _ = commit(
        [{"update": {"name": order_path,
                     "fields": dict(order_base, discount=iv(1000), total=iv(11000))}}],
        token,
    )
    check("6 create order with 10% discount", s, 200)

    # 7) rewrite the total afterwards
    s, _ = commit([update_op(order_path, {"total": iv(0)})], token)
    check("7 rewrite order total after creation", s, 403)

    # 8) mark own order delivered
    s, _ = commit([update_op(order_path, {"status": sv("delivered")})], token)
    check("8 set own order status=delivered", s, 403)

    # 9) cancel own order (the one update customers are allowed)
    s, _ = commit(
        [update_op(order_path, {"status": sv("cancelled"),
                                "cancelReason": sv("TEST-SECURITY"),
                                "cancelledAt": ts_now()})],
        token,
    )
    check("9 cancel own order", s, 200)

    # 10) self-referral
    ref_path = f"{DOCS}/referrals/self-{uid[:6]}"
    s, _ = commit(
        [{"update": {"name": ref_path,
                     "fields": {"refereeUid": sv(uid), "referrerUid": sv(uid),
                                "status": sv("pending"), "createdAt": ts_now()}}}],
        token,
    )
    check("10 self-referral", s, 403)

    print(f"\n== RESULT: {sum(results)}/{len(results)} PASS ==")
    sys.exit(0 if all(results) else 3)


if __name__ == "__main__":
    main()
