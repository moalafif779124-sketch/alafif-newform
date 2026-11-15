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

AUTH: needs a Google access token with project-owner rights. In CI we exchange
the FIREBASE_TOKEN refresh token for one (see the workflow). Usage:

    GOOGLE_ACCESS_TOKEN=ya29... python3 tools/compress_product_images.py [--dry-run]
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

DRY = "--dry-run" in sys.argv
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


def main():
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
