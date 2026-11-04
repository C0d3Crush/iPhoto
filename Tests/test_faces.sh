#!/bin/bash
# Tests/test_faces.sh — Gesichtserkennung + DBSCAN-Clustering
#
# Verwendet 7 Public-Domain-Fotos von 3 historischen Personen (Einstein, Chaplin, Curie),
# die beim ersten Lauf vom Skript aus dem Internet geladen werden.
#
# Hinweis: VNGenerateImageFeaturePrintRequest vergleicht visuelle Ähnlichkeit,
# keine Identität. Für moderne Farbfotos (Norm-Use-Case) liegen same-person-
# Distanzen deutlich unter 0.08; die historischen S/W-Fotos hier sind ein
# konservativer Grenztest.

set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLI="$ROOT/build/iphoto-cli"
IMG_DIR="$ROOT/Tests/fixtures/faces"
DB=$(mktemp /tmp/iphoto_faces_test_XXXXXX.db)
PASS=0; FAIL=0

# Farben
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS+1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL+1)); }

cleanup() { rm -f "$DB"; }
trap cleanup EXIT

# ── Voraussetzungen ────────────────────────────────────────────────────────────

if [ ! -x "$CLI" ]; then
    echo "Fehler: $CLI nicht gefunden. Zuerst ./build.sh ausführen." >&2
    exit 1
fi

# Testbilder laden (falls noch nicht vorhanden)
mkdir -p "$IMG_DIR"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

download_if_missing() {
    local name="$1" url="$2"
    local path="$IMG_DIR/$name"
    if [ ! -f "$path" ] || [ "$(wc -c < "$path")" -lt 50000 ]; then
        echo "    Lade $name..."
        curl -sL -A "$UA" "$url" -o "$path"
        local sz
        sz=$(wc -c < "$path")
        if [ "$sz" -lt 50000 ]; then
            echo "Warnung: $name zu klein ($sz Bytes) — Download eventuell fehlgeschlagen." >&2
            return 1
        fi
    fi
    return 0
}

IMAGES_OK=1
download_if_missing "einstein_1.jpg" "https://upload.wikimedia.org/wikipedia/commons/d/d3/Albert_Einstein_Head.jpg"   || IMAGES_OK=0
download_if_missing "einstein_2.jpg" "https://upload.wikimedia.org/wikipedia/commons/3/3e/Einstein_1921_by_F_Schmutzer_-_restoration.jpg" || IMAGES_OK=0
download_if_missing "einstein_3.jpg" "https://upload.wikimedia.org/wikipedia/commons/1/14/Albert_Einstein_1947.jpg"    || IMAGES_OK=0
download_if_missing "chaplin_1.jpg"  "https://upload.wikimedia.org/wikipedia/commons/0/00/Charlie_Chaplin.jpg"         || IMAGES_OK=0
download_if_missing "chaplin_2.jpg"  "https://upload.wikimedia.org/wikipedia/commons/8/82/Charlie_Chaplin_portrait_Getty_1739411952.jpg" || IMAGES_OK=0
download_if_missing "curie_1.jpg"    "https://upload.wikimedia.org/wikipedia/commons/7/7e/Marie_Curie_c1920.jpg"       || IMAGES_OK=0
download_if_missing "curie_2.jpg"    "https://upload.wikimedia.org/wikipedia/commons/c/c8/Marie_Curie_c._1920s.jpg"   || IMAGES_OK=0

if [ "$IMAGES_OK" -eq 0 ]; then
    echo "Warnung: Einige Testbilder konnten nicht geladen werden. Tests werden trotzdem ausgeführt." >&2
fi

# Zähle vorhandene valide Bilder
VALID_IMAGES=0
for f in einstein_1 einstein_2 einstein_3 chaplin_1 chaplin_2 curie_1 curie_2; do
    local_path="$IMG_DIR/${f}.jpg"
    if [ -f "$local_path" ] && [ "$(wc -c < "$local_path")" -ge 50000 ]; then
        VALID_IMAGES=$((VALID_IMAGES+1))
    fi
done

echo "=== Gesichtserkennung + Clustering-Tests ==="
echo "    Testbilder: $IMG_DIR ($VALID_IMAGES/7 vorhanden)"
echo "    Katalog:    $DB"
echo ""

# ── T1: Scan ───────────────────────────────────────────────────────────────────

echo "--- T1: Scan aller Testbilder ---"
export IPHOTO_CATALOG_DB="$DB"

SCAN_OUT=$(IPHOTO_CATALOG_DB="$DB" "$CLI" people scan \
    "$IMG_DIR/einstein_1.jpg" \
    "$IMG_DIR/einstein_2.jpg" \
    "$IMG_DIR/einstein_3.jpg" \
    "$IMG_DIR/chaplin_1.jpg" \
    "$IMG_DIR/chaplin_2.jpg" \
    "$IMG_DIR/curie_1.jpg" \
    "$IMG_DIR/curie_2.jpg" 2>&1)

echo "$SCAN_OUT"

TOTAL_FACES=$(echo "$SCAN_OUT" | grep "^Gesamt:" | grep -oE '[0-9]+' | head -1)
if [ "${TOTAL_FACES:-0}" -ge 7 ]; then
    pass "T1a: $TOTAL_FACES Gesicht(er) in 7 Bildern erkannt (erwartet: ≥7)"
else
    fail "T1a: Nur $TOTAL_FACES Gesicht(er) erkannt (erwartet: ≥7)"
fi

SCANNED_IMGS=$(echo "$SCAN_OUT" | grep "^[0-9]" | wc -l | tr -d ' ')
if [ "$SCANNED_IMGS" -ge 7 ]; then
    pass "T1b: Alle 7 Bilder verarbeitet"
else
    fail "T1b: Nur $SCANNED_IMGS/7 Bilder verarbeitet"
fi

echo ""

# ── T2: Faces in DB ───────────────────────────────────────────────────────────

echo "--- T2: Faces im Katalog ---"
FACES_JSON=$(IPHOTO_CATALOG_DB="$DB" "$CLI" people faces --json 2>&1)
FACE_COUNT=$(echo "$FACES_JSON" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)

if [ "$FACE_COUNT" -ge 7 ]; then
    pass "T2: $FACE_COUNT Gesicht(er) im Katalog (erwartet: ≥7)"
else
    fail "T2: $FACE_COUNT Gesicht(er) im Katalog (erwartet: ≥7)"
fi

echo ""

# ── T3: Cluster (epsilon=0.08) ─────────────────────────────────────────────────

echo "--- T3: DBSCAN epsilon=0.08 ---"
CLUSTER_OUT=$(IPHOTO_CATALOG_DB="$DB" "$CLI" people cluster --epsilon 0.08 2>&1)
echo "$CLUSTER_OUT"

CLUSTER_COUNT=$(echo "$CLUSTER_OUT" | grep -oE '[0-9]+ Gruppen' | grep -oE '[0-9]+' | head -1)
if [ "${CLUSTER_COUNT:-0}" -ge 2 ]; then
    pass "T3a: $CLUSTER_COUNT Cluster erstellt (erwartet: ≥2)"
else
    fail "T3a: $CLUSTER_COUNT Cluster (erwartet: ≥2 verschiedene Personen)"
fi

echo ""

# ── T4: Same-Person-Paare im gleichen Cluster ─────────────────────────────────

echo "--- T4: Same-Person-Cluster-Prüfung ---"

# Hilfsfunktion: cluster_id für Bildpfad aus JSON
cluster_for_path() {
    local path="$1"
    echo "$FACES_JSON_AFTER_CLUSTER" | python3 -c "
import sys, json
faces = json.load(sys.stdin)
for f in faces:
    if f['image_path'].endswith('$path'):
        print(f.get('cluster_id', ''))
        break
" 2>/dev/null
}

# Faces nach Clustering neu laden
FACES_JSON_AFTER_CLUSTER=$(IPHOTO_CATALOG_DB="$DB" "$CLI" people faces --json 2>&1)

E1=$(cluster_for_path "einstein_1.jpg")
E3=$(cluster_for_path "einstein_3.jpg")
C1=$(cluster_for_path "curie_1.jpg")
C2=$(cluster_for_path "curie_2.jpg")
CH1=$(cluster_for_path "chaplin_1.jpg")

# Einstein 1 und 3 haben Distanz 0.0101 — sollten im selben Cluster sein
if [ -n "$E1" ] && [ -n "$E3" ] && [ "$E1" = "$E3" ]; then
    pass "T4a: einstein_1 + einstein_3 im gleichen Cluster (Distanz ~0.01)"
else
    fail "T4a: einstein_1 ($E1) und einstein_3 ($E3) in unterschiedlichen Clustern"
fi

# Curie 1 und 2 haben Distanz 0.0583 — sollten im selben Cluster sein
if [ -n "$C1" ] && [ -n "$C2" ] && [ "$C1" = "$C2" ]; then
    pass "T4b: curie_1 + curie_2 im gleichen Cluster (Distanz ~0.058)"
else
    fail "T4b: curie_1 ($C1) und curie_2 ($C2) in unterschiedlichen Clustern"
fi

echo ""

# ── T5: Verschiedene Personen in unterschiedlichen Clustern ───────────────────

echo "--- T5: Cross-Person-Trennung ---"

E1=$(cluster_for_path "einstein_1.jpg")
CH1=$(cluster_for_path "chaplin_1.jpg")

# Einstein vs Chaplin: Distanz ~0.308 — weit auseinander
if [ -n "$E1" ] && [ -n "$CH1" ] && [ "$E1" != "$CH1" ]; then
    pass "T5a: einstein_1 und chaplin_1 in unterschiedlichen Clustern (Distanz ~0.31)"
else
    fail "T5a: einstein_1 ($E1) und chaplin_1 ($CH1) fälschlich im gleichen Cluster"
fi

echo ""

# ── T6: People list ───────────────────────────────────────────────────────────

echo "--- T6: People-Liste ---"
PEOPLE_OUT=$(IPHOTO_CATALOG_DB="$DB" "$CLI" people list 2>&1)
echo "$PEOPLE_OUT"
PEOPLE_COUNT=$(echo "$PEOPLE_OUT" | grep -c "[A-Z0-9-]\{36\}" || echo 0)

if [ "${PEOPLE_COUNT:-0}" -ge 2 ]; then
    pass "T6: $PEOPLE_COUNT Personen in der Liste"
else
    fail "T6: $PEOPLE_COUNT Personen (erwartet: ≥2)"
fi

echo ""

# ── T7: Re-Cluster mit Standard-Epsilon ───────────────────────────────────────

echo "--- T7: Re-Clustering mit Standard-Epsilon (0.15) ---"
RECLUSTER_OUT=$(IPHOTO_CATALOG_DB="$DB" "$CLI" people cluster 2>&1)
echo "$RECLUSTER_OUT"
if echo "$RECLUSTER_OUT" | grep -q "Clustering abgeschlossen"; then
    pass "T7: Re-Clustering erfolgreich"
else
    fail "T7: Re-Clustering fehlgeschlagen"
fi

echo ""

# ── Zusammenfassung ───────────────────────────────────────────────────────────

echo "=============================="
echo "PASS: $PASS   FAIL: $FAIL"
echo "=============================="
[ "$FAIL" -eq 0 ]
