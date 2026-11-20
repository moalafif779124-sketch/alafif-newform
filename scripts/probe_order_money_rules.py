#!/usr/bin/env python3
"""Behavioural probe: the money fields of an order at CREATE time.

The app computes subtotal/tax/shipping/discount/total on the phone. The ruleset
now re-derives them server-side (`orderMoneyValid`): tax must be 5% of
(subtotal − bundle discount), shipping must match the city table in
DeliveryConfig (free at ≥ 50,000), the total must equal
subtotal + tax + shipping − discount, points are capped at 20% of the subtotal
and coupons at 50%.

Proves on the LIVE ruleset (project alafif-newform):
  1  sanaa: 4000 + 200 + 2000 = 6200                        -> 200
  2  ibb: 4000 + 200 + 1500 = 5700                          -> 200
  3  free shipping: 60000 + 3000 + 0 = 63000                -> 200
  4  points within the 20% cap                              -> 200
  5  coupon within the 50% cap                              -> 200
  6  full-look bundle: tax on (subtotal − bundle discount)   -> 200
  7  total lowered by 200 (pays less)                       -> 403
  8  shipping 0 for sanaa                                   -> 403
  9  aden fees but pays sanaa fees                          -> 403
 10  pointsDiscount 30% of subtotal                         -> 403
 11  tax omitted/zero                                      -> 403
 12  shipping 0 without reaching the free threshold         -> 403

Cleanup uses the shop-owner OAuth token (anon users cannot delete).
Usage:  python3 scripts/probe_order_money_rules.py
"""
import json
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


def order_body(uid, sub, tax, ship, disc, city="sanaa", extra=None):
    import time
    f = {
        "userId": {"stringValue": uid},
        "orderNumber": {"stringValue": f"PROBE-{int(time.time()*1000)}"},
        "status": {"stringValue": "pending"},
        "subtotal": {"doubleValue": sub},
        "tax": {"doubleValue": tax},
        "shippingCost": {"doubleValue": ship},
        "discount": {"doubleValue": disc},
        "total": {"doubleValue": total_of(sub, tax, ship, disc)},
        "paymentMethod": {"stringValue": "cod"},
        "paymentStatus": {"stringValue": "pending"},
        "cityId": {"stringValue": city},
        "createdAt": {"integerValue": str(int(time.time() * 1000))},
        "items": {"arrayValue": {"values": [
            {"mapValue": {"fields": {
                "productId": {"stringValue": "probe-prod"},
                "productName": {"stringValue": "probe"},
                "price": {"doubleValue": sub},
                "quantity": {"integerValue": "1"},
                "size": {"stringValue": ""},
            }}}
        ]}},
    }
    for k, v in (extra or {}).items():
        f[k] = v
    return {"fields": f}


def total_of(sub, tax, ship, disc):
    return sub + tax + ship - disc


def main():
    token, uid = anon_token()
    created = []

    def create(label, body, want):
        s, b = call(f"{BASE}/orders", body, token=token)
        ok = (s == want)
        print(f"{'✅' if ok else '❌'} {label}: {s} (want {want})")
        if ok and s == 200:
            created.append(b["name"].split("/")[-1])
        elif not ok:
            print("   ", json.dumps(b)[:240])
        return ok

    results = []
    # ===== should PASS =====
    results.append(create("1 sanaa 4000+200+2000-0 = 6200", order_body(uid, 4000, 200, 2000, 0), 200))
    results.append(create("2 ibb 4000+200+1500-0 = 5700", order_body(uid, 4000, 200, 1500, 0, city="ibb"), 200))
    results.append(create("3 free shipping 60000+3000+0 = 63000",
                          order_body(uid, 60000, 3000, 0, 0), 200))
    results.append(create("4 points 2000 (20% of 10000)",
                          order_body(uid, 10000, 500, 2000, 2000, extra={
                              "pointsDiscount": {"doubleValue": 2000},
                              "pointsUsed": {"integerValue": "60"}}), 200))
    results.append(create("5 coupon 3000 (30% of 10000)",
                          order_body(uid, 10000, 500, 2000, 3000, extra={
                              "couponCode": {"stringValue": "PROBE10"},
                              "couponDiscount": {"doubleValue": 3000}}), 200))
    results.append(create("6 bundle: tax on 10000-1000",
                          order_body(uid, 10000, 450, 2000, 1000, extra={
                              "bundle": {"mapValue": {"fields": {
                                  "discount": {"doubleValue": 1000},
                                  "pieces": {"integerValue": "2"}}}}}), 200))

    # ===== should FAIL =====
    bad = order_body(uid, 4000, 200, 2000, 0)
    bad["fields"]["total"] = {"doubleValue": 6000}
    results.append(create("7 total lowered to 6000", bad, 403))

    results.append(create("8 shipping 0 for sanaa", order_body(uid, 4000, 200, 0, 0), 403))
    results.append(create("9 aden fees but pays sanaa", order_body(uid, 4000, 200, 2000, 0, city="aden"), 403))

    results.append(create("10 points 3000 (30% of 10000)",
                          order_body(uid, 10000, 0, 2000, 3000, extra={
                              "pointsDiscount": {"doubleValue": 3000},
                              "pointsUsed": {"integerValue": "60"}}), 403))

    no_tax = order_body(uid, 4000, 200, 2000, 0)
    no_tax["fields"]["tax"] = {"doubleValue": 0}
    no_tax["fields"]["total"] = {"doubleValue": 6000}
    results.append(create("11 tax zeroed", no_tax, 403))

    results.append(create("12 free shipping under 50k", order_body(uid, 40000, 2000, 0, 0), 403))

    # cleanup with the owner token
    owner = open(TOKEN_FILE).read().strip()
    for oid in created:
        call(f"{BASE}/orders/{oid}", token=owner, method="DELETE")
    print(f"\ncleaned {len(created)} probe orders")
    ok = sum(1 for r in results if r)
    print(f"RESULT: {ok}/{len(results)} as expected")
    return 0 if ok == len(results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
