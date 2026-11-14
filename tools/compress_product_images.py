#!/usr/bin/env python3
"""Migrate product images out of Firestore documents (Spark-plan friendly).

WHY: every active product carried its photo as a base64 string INSIDE the
document — 57 active products = 14.0 MB of payload (13.9 MB images), largest
doc 834 KB against Firestore's 1 MB limit. Every cold start downloaded it all.

WHAT THIS DOES (per product that still has base64 images):
  * decodes and re-encodes the images: max 900 px, JPEG q62  -> product_images/{id}
  * writes a ~240 px thumbnail (q70) into the product doc as `thumb`
  * clears `images` in the product doc so the catalog stays text-sized
  * the PDP fetches product_images/{id} on demand

BANNERS MODE (`--banners`): the home-screen banners still carried their photo
raw in `imageUrl` — 6 docs = 897 KB, one banner 219 KB — and every launch reads
them. This re-encodes each banner (max 1280 px, adaptive quality until it fits
under TARGET_KB) and patches only that one field.

AUTH: needs a Google access token with project-owner rights. In CI we exchange
the FIREBASE_TOKEN refresh token for one (see the workflow). Usage:

    GOOGLE_ACCESS_TOKEN=ya29... python3 tools/compress_product_images.py [--dry-run]
    GOOGLE_ACCESS_TOKEN=ya29... python3 tools/compress_product_images.py --banners [--dry-run]
"""
import base64
import io
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

from PIL import Image

try:  # Pillow >= 9.1
    RESAMPLE = Image.Resampling.LANCZOS
except AttributeError:  # pragma: no cover - older Pillow
    RESAMPLE = Image.LANCZOS

PROJECT = "alafif-newform"
BASE = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"
DOCS = f"projects/{PROJECT}/databases/(default)/documents"
FULL_MAX = 900       # px
FULL_QUALITY = 62
THUMB_MAX = 240      # px
THUMB_QUALITY = 70

# The hero is 200 dp tall and full width (AppImage decodes base64 at full
# resolution), so the source must stay ~1080 px wide — the saving has to come
# from quality, not from shrinking below what the phone actually displays.
BANNER_MAX = 1080     # px
BANNER_QUALITIES = (66, 58, 50, 44)
BANNER_TARGET_KB = 95

DRY = "--dry-run" in sys.argv
BANNERS = "--banners" in sys.argv
TOKEN = os.environ.get("GOOGLE_ACCESS_TOKEN", "").strip()
if not TOKEN:
    sys.exit("GOOGLE_ACCESS_TOKEN is required")


def api(url, payload=None, method=None):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method or ("PATCH" if data else "GET"))
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {TOKEN}")
    try:
        with urllib.request.urlopen(req) as r:
            body = r.read().decode()
            return r.status, (json.loads(body) if body else {})
    except urllib.error.HTTPError as e:
        return e.code, {"raw": e.read().decode()[:300]}


def list_products():
    """Walks every page. pageSize is capped by the API, and a single pass used to
    stop early (silently missing ~20 products), so keep going until the token is
    gone and assert the total against the count aggregation."""
    docs, token, pages = [], None, 0
    while True:
        url = f"{BASE}/products?pageSize=300" + (f"&pageToken={token}" if token else "")
        s, d = api(url)
        if s != 200:
            sys.exit(f"list products failed: {s} {d}")
        page_docs = d.get("documents", [])
        docs += page_docs
        token = d.get("nextPageToken")
        pages += 1
        print(f"  page {pages}: +{len(page_docs)} docs (total {len(docs)})")
        if not token:
            break
        if pages > 30:
            sys.exit("pagination did not finish after 30 pages")

    s, agg = api(f"{BASE}:runAggregationQuery", {
        "structuredAggregationQuery": {
            "structuredQuery": {"from": [{"collectionId": "products"}], "limit": 1},
            "aggregations": [{"alias": "n", "count": {}}],
        }
    })
    total = None
    if s == 200:
        try:
            total = int(agg["result"][0]["aggregateFields"]["n"]["integerValue"])
        except Exception:  # noqa: BLE001
            total = None
    print(f"collected {len(docs)} docs" + (f" of {total} in the collection" if total else ""))
    if total is not None and len(docs) < total:
        sys.exit(f"INCOMPLETE LIST: {len(docs)} of {total} — refusing to report a migration")
    return docs


def data_uri_to_jpeg(uri):
    if not uri.startswith("data:image"):
        return None
    _, b64 = uri.split(",", 1)
    img = Image.open(io.BytesIO(base64.b64decode(b64))).convert("RGB")
    return img


def encode(img, max_px, quality):
    w, h = img.size
    if max(w, h) > max_px:
        scale = max_px / max(w, h)
        img = img.resize((max(1, int(w * scale)), max(1, int(h * scale))), RESAMPLE)
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=quality, optimize=True, progressive=True)
    return f"data:image/jpeg;base64,{base64.b64encode(buf.getvalue()).decode()}"


def list_collection(coll, page_size=300):
    """Same pagination contract as list_products, for any collection."""
    docs, token, pages = [], None, 0
    while True:
        url = f"{BASE}/{coll}?pageSize={page_size}" + (f"&pageToken={token}" if token else "")
        s, d = api(url)
        if s != 200:
            sys.exit(f"list {coll} failed: {s} {d}")
        docs += d.get("documents", [])
        token = d.get("nextPageToken")
        pages += 1
        if not token:
            return docs
        if pages > 30:
            sys.exit(f"pagination of {coll} did not finish after 30 pages")


def encode_bounded(img, max_px, qualities, target_kb):
    """Re-encode at max_px, walking the quality ladder until the payload fits.
    A banner is paid for on every app launch, so a fixed quality that still
    lands at 200 KB is a failure, not a compromise."""
    w, h = img.size
    if max(w, h) > max_px:
        scale = max_px / max(w, h)
        img = img.resize((max(1, int(w * scale)), max(1, int(h * scale))), RESAMPLE)
    best = ""
    for q in qualities:
        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=q, optimize=True, progressive=True)
        raw = buf.getvalue()
        cand = f"data:image/jpeg;base64,{base64.b64encode(raw).decode()}"
        best = cand
        if len(cand) <= target_kb * 1024:
            break
    return best


def migrate_banners():
    banners = list_collection("banners")
    print(f"banners: {len(banners)} docs; dry-run={DRY}")
    before = sum(len(json.dumps(b)) for b in banners)
    touched = failed = 0
    after = 0
    for b in banners:
        bid = b["name"].split("/")[-1]
        f = b.get("fields", {})
        uri = f.get("imageUrl", {}).get("stringValue", "")
        title = (f.get("title", {}).get("stringValue") or "?")[:24]
        size = len(json.dumps(b))
        if not uri.startswith("data:image"):
            print(f"  {bid[:10]}… {title:26s} not base64 ({uri[:24]}…) — skipped")
            after += size
            continue
        try:
            img = data_uri_to_jpeg(uri)
            if img is None:
                after += size
                failed += 1
                continue
            dims = f"{img.width}x{img.height}"
            new_uri = encode_bounded(img, BANNER_MAX, BANNER_QUALITIES, BANNER_TARGET_KB)
            print(f"  {bid[:10]}… {title:26s} {dims:>10s} {len(uri)//1024:4d} KB -> {len(new_uri)//1024:3d} KB")
            if DRY:
                touched += 1
                after += size - len(uri) + len(new_uri)
                continue
            s, d = api(f"{BASE}/banners/{bid}?updateMask.fieldPaths=imageUrl",
                       {"fields": {"imageUrl": {"stringValue": new_uri}}}, method="PATCH")
            if s != 200:
                print(f"  !! banner patch failed {bid}: {s} {d}")
                failed += 1
                after += size
                continue
            touched += 1
            after += size - len(uri) + len(new_uri)
        except Exception as e:  # noqa: BLE001
            print(f"  !! {bid} error: {e}")
            failed += 1
            after += size

    print(f"\nbanners migrated: {touched}, failed: {failed}")
    print(f"banner payload: {before/1024:.0f} KB -> ~{after/1024:.0f} KB (every launch reads these)")
    if failed:
        sys.exit(2)


def main():
    if BANNERS:
        migrate_banners()
        return
    products = list_products()
    active = [p for p in products if p.get("fields", {}).get("isActive", {}).get("booleanValue")]
    print(f"products: {len(products)} total, {len(active)} active; dry-run={DRY}")

    before_total = sum(len(json.dumps(p)) for p in active)
    touched = skipped = failed = 0
    after_estimate = 0

    for p in active:
        pid = p["name"].split("/")[-1]
        f = p.get("fields", {})
        raw_imgs = f.get("images", {}).get("arrayValue", {}).get("values", [])
        uris = [v.get("stringValue", "") for v in raw_imgs if v.get("stringValue")]
        base64_uris = [u for u in uris if u.startswith("data:image")]

        doc_size = len(json.dumps(p))
        if not base64_uris:
            skipped += 1
            after_estimate += doc_size
            continue

        try:
            full, thumb = [], ""
            for uri in base64_uris:
                img = data_uri_to_jpeg(uri)
                if img is None:
                    continue
                if not thumb:
                    thumb = encode(img, THUMB_MAX, THUMB_QUALITY)
                full.append(encode(img, FULL_MAX, FULL_QUALITY))

            if not full:
                skipped += 1
                after_estimate += doc_size
                continue

            gallery_bytes = sum(len(u) for u in full)
            print(f"  {pid[:10]}… {(f.get('name',{}).get('stringValue') or '?')[:28]:30s} "
                  f"{doc_size//1024:4d} KB -> thumb {len(thumb)//1024:3d} KB + gallery {gallery_bytes//1024:4d} KB")

            if DRY:
                touched += 1
                after_estimate += doc_size - sum(len(u) for u in base64_uris) + len(thumb)
                continue

            # 1) write the gallery first (never lose the picture), 2) then slim the doc
            s, d = api(f"{BASE}/product_images/{pid}", {
                "fields": {
                    "images": {"arrayValue": {"values": [{"stringValue": u} for u in full]}},
                    "updatedAt": {"timestampValue": __import__("datetime").datetime.utcnow().isoformat() + "Z"},
                }
            }, method="PATCH")
            if s != 200:
                print(f"  !! gallery write failed {pid}: {s} {d}")
                failed += 1
                continue

            s, d = api(f"{BASE}/products/{pid}?updateMask.fieldPaths=thumb"
                       f"&updateMask.fieldPaths=images", {
                           "fields": {
                               "thumb": {"stringValue": thumb},
                               "images": {"arrayValue": {"values": []}},
                           }
                       }, method="PATCH")
            if s != 200:
                print(f"  !! product patch failed {pid}: {s} {d}")
                failed += 1
                continue
            touched += 1
            after_estimate += doc_size - sum(len(u) for u in base64_uris) + len(thumb)
        except Exception as e:  # noqa: BLE001
            print(f"  !! {pid} error: {e}")
            failed += 1

    print(f"\nmigrated: {touched}, skipped (no base64): {skipped}, failed: {failed}")
    print(f"active payload: {before_total/1024/1024:.1f} MB -> ~{after_estimate/1024/1024:.2f} MB "
          f"(documents only; galleries now load per-product)")
    if failed:
        sys.exit(2)


if __name__ == "__main__":
    main()
