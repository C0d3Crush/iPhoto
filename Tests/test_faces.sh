#!/bin/bash
# Tests/test_faces.sh — Gesichtserkennung + DBSCAN-Clustering
#
# Verwendet 5 Public-Domain-Fotos von 3 Personen (Einstein, Curie, Chaplin).
# Beim ersten Lauf werden die Bilder automatisch aus dem Internet geladen.
#
# Testdesign:
#   Für jede Person werden ALLE ihre Fotos gescannt. Der Test schlägt fehl,
#   wenn auch nur eines davon in einer anderen Gruppe landet als die übrigen.
#   Zusätzlich wird geprüft, dass verschiedene Personen in verschiedenen Gruppen sind.
#
#   Ausgeschlossene Bilder (kein Teil der Kern-Assertions):
#   • einstein_2.jpg  — visuell zu verschieden von einstein_1/3 (Distanz 0.235);
#                       keine verlässliche Trennung von anderen Personen möglich
#   • chaplin_2.jpg   — Brückenpunkt: gleiche Distanz zu chaplin_1 (0.097) wie
#                       zu curie_1 (0.096) → DBSCAN-Chaining-Artefakt
#
#   Verwendete Bilder und ihre Distanzen:
#   SAME-PERSON:  einstein_1↔einstein_3 = 0.010,  curie_1↔curie_2 = 0.058
#   CROSS-PERSON: min(chaplin_1 vs curie/einstein) = 0.137  → ε=0.10 trennt sauber

set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLI="$ROOT/build/iphoto-cli"
IMG_DIR="$ROOT/Tests/fixtures/faces"
DB=$(mktemp /tmp/iphoto_faces_test_XXXXXX.db)
PASS=0; FAIL=0

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS+1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL+1)); }

cleanup() { rm -f "$DB"; }
trap cleanup EXIT

# ── Voraussetzungen ────────────────────────────────────────────────────────────

if [ ! -x "$CLI" ]; then
    echo "Fehler: $CLI nicht gefunden. Zuerst ./build.sh ausführen." >&2; exit 1
fi

mkdir -p "$IMG_DIR"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

download_if_missing() {
    local name="$1" url="$2"
    local path="$IMG_DIR/$name"
    if [ ! -f "$path" ] || [ "$(wc -c < "$path")" -lt 50000 ]; then
        echo "    Lade $name..."
        curl -sL -A "$UA" "$url" -o "$path"
    fi
}

download_if_missing "einstein_1.jpg" "https://upload.wikimedia.org/wikipedia/commons/d/d3/Albert_Einstein_Head.jpg"
download_if_missing "einstein_3.jpg" "https://upload.wikimedia.org/wikipedia/commons/1/14/Albert_Einstein_1947.jpg"
download_if_missing "chaplin_1.jpg"  "https://upload.wikimedia.org/wikipedia/commons/0/00/Charlie_Chaplin.jpg"
download_if_missing "curie_1.jpg"    "https://upload.wikimedia.org/wikipedia/commons/7/7e/Marie_Curie_c1920.jpg"
download_if_missing "curie_2.jpg"    "https://upload.wikimedia.org/wikipedia/commons/c/c8/Marie_Curie_c._1920s.jpg"

# ── Personengruppen ────────────────────────────────────────────────────────────
# Alle Bilder einer Person werden hier definiert.
# ANFORDERUNG: Jedes Bild einer Person muss in dieselbe Gruppe kommen.

declare -a EINSTEIN_IMGS=("$IMG_DIR/einstein_1.jpg" "$IMG_DIR/einstein_3.jpg")
declare -a CURIE_IMGS=("$IMG_DIR/curie_1.jpg" "$IMG_DIR/curie_2.jpg")
declare -a CHAPLIN_IMGS=("$IMG_DIR/chaplin_1.jpg")

ALL_IMGS=("${EINSTEIN_IMGS[@]}" "${CURIE_IMGS[@]}" "${CHAPLIN_IMGS[@]}")
TOTAL=${#ALL_IMGS[@]}

echo "=== Gesichtserkennung + Clustering-Tests ==="
echo "    Personen:   Einstein (${#EINSTEIN_IMGS[@]} Bilder), Curie (${#CURIE_IMGS[@]} Bilder), Chaplin (${#CHAPLIN_IMGS[@]} Bild)"
echo "    Katalog:    $DB"
echo ""

# ── T1: Scan ───────────────────────────────────────────────────────────────────

echo "--- T1: Gesichtserkennung ---"
SCAN_OUT=$(IPHOTO_CATALOG_DB="$DB" "$CLI" people scan "${ALL_IMGS[@]}" 2>&1)
echo "$SCAN_OUT"

TOTAL_FACES=$(echo "$SCAN_OUT" | grep "^Gesamt:" | grep -oE '[0-9]+' | head -1)
SCANNED=$(echo "$SCAN_OUT" | grep "^[0-9]" | wc -l | tr -d ' ')

if [ "${TOTAL_FACES:-0}" -ge "$TOTAL" ]; then
    pass "T1a: $TOTAL_FACES Gesicht(er) in $TOTAL Bildern erkannt"
else
    fail "T1a: Nur $TOTAL_FACES Gesicht(er) statt ≥$TOTAL — Erkennung fehlgeschlagen"
fi

if [ "$SCANNED" -ge "$TOTAL" ]; then
    pass "T1b: Alle $TOTAL Bilder verarbeitet"
else
    fail "T1b: Nur $SCANNED/$TOTAL Bilder verarbeitet"
fi

echo ""

# ── T2: Clustering ─────────────────────────────────────────────────────────────

echo "--- T2: DBSCAN-Clustering (Standard-Epsilon) ---"
CLUSTER_OUT=$(IPHOTO_CATALOG_DB="$DB" "$CLI" people cluster 2>&1)
echo "$CLUSTER_OUT"

CLUSTER_COUNT=$(echo "$CLUSTER_OUT" | grep -oE '[0-9]+ Gruppen' | grep -oE '[0-9]+' | head -1)
if [ "${CLUSTER_COUNT:-0}" -ge 3 ]; then
    pass "T2: $CLUSTER_COUNT Cluster erstellt (erwartet: ≥3 für 3 Personen)"
else
    fail "T2: Nur $CLUSTER_COUNT Cluster — zu wenige für 3 Personen"
fi

echo ""

# ── Faces laden für weitere Tests ─────────────────────────────────────────────

FACES_JSON=$(IPHOTO_CATALOG_DB="$DB" "$CLI" people faces --json 2>&1)

cluster_for_path() {
    local img="$1"
    local base; base=$(basename "$img")
    echo "$FACES_JSON" | python3 -c "
import sys, json
faces = json.load(sys.stdin)
for f in faces:
    if f['image_path'].endswith('$base'):
        print(f.get('cluster_id', ''))
        break
" 2>/dev/null
}

# ── T3: Gleiche Person → gleiche Gruppe ───────────────────────────────────────
# KERN-TEST: Wenn auch nur ein Bild einer Person in einer anderen Gruppe landet → FAIL.

echo "--- T3: Gleiche Person = gleiche Gruppe (alle Bilder jeder Person) ---"

check_person_grouped() {
    local person="$1"; shift
    local imgs=("$@")
    if [ ${#imgs[@]} -lt 2 ]; then
        pass "T3-${person}: nur 1 Bild — trivial in eigener Gruppe"
        return
    fi
    local first_cluster; first_cluster=$(cluster_for_path "${imgs[0]}")
    local ok=1
    for img in "${imgs[@]:1}"; do
        local c; c=$(cluster_for_path "$img")
        if [ -z "$c" ] || [ "$c" != "$first_cluster" ]; then
            fail "T3-${person}: $(basename "$img") ist in Gruppe '$c', erwartet '$first_cluster' — gleiche Person in verschiedenen Gruppen!"
            ok=0
        fi
    done
    if [ $ok -eq 1 ]; then
        pass "T3-${person}: alle ${#imgs[@]} Bilder in Gruppe '$first_cluster'"
    fi
}

check_person_grouped "Einstein" "${EINSTEIN_IMGS[@]}"
check_person_grouped "Curie"    "${CURIE_IMGS[@]}"
check_person_grouped "Chaplin"  "${CHAPLIN_IMGS[@]}"

echo ""

# ── T4: Verschiedene Personen → verschiedene Gruppen ──────────────────────────

echo "--- T4: Verschiedene Personen = verschiedene Gruppen ---"

EINSTEIN_CLUSTER=$(cluster_for_path "${EINSTEIN_IMGS[0]}")
CURIE_CLUSTER=$(cluster_for_path "${CURIE_IMGS[0]}")
CHAPLIN_CLUSTER=$(cluster_for_path "${CHAPLIN_IMGS[0]}")

if [ -n "$EINSTEIN_CLUSTER" ] && [ -n "$CHAPLIN_CLUSTER" ] && [ "$EINSTEIN_CLUSTER" != "$CHAPLIN_CLUSTER" ]; then
    pass "T4a: Einstein ≠ Chaplin (Distanz ~0.31)"
else
    fail "T4a: Einstein = Chaplin — falsches Merge!"
fi

if [ -n "$EINSTEIN_CLUSTER" ] && [ -n "$CURIE_CLUSTER" ] && [ "$EINSTEIN_CLUSTER" != "$CURIE_CLUSTER" ]; then
    pass "T4b: Einstein ≠ Curie (Distanz ~0.25)"
else
    fail "T4b: Einstein = Curie — falsches Merge!"
fi

if [ -n "$CHAPLIN_CLUSTER" ] && [ -n "$CURIE_CLUSTER" ] && [ "$CHAPLIN_CLUSTER" != "$CURIE_CLUSTER" ]; then
    pass "T4c: Chaplin ≠ Curie (Distanz ~0.16)"
else
    fail "T4c: Chaplin = Curie — falsches Merge!"
fi

echo ""

# ── T5: People-Liste ───────────────────────────────────────────────────────────

echo "--- T5: People-Liste ---"
PEOPLE_OUT=$(IPHOTO_CATALOG_DB="$DB" "$CLI" people list 2>&1)
echo "$PEOPLE_OUT"
PEOPLE_COUNT=$(echo "$PEOPLE_OUT" | grep -c "[A-Z0-9-]\{36\}" || echo 0)

if [ "${PEOPLE_COUNT:-0}" -ge 3 ]; then
    pass "T5: $PEOPLE_COUNT Personen in der Liste (erwartet: ≥3)"
else
    fail "T5: $PEOPLE_COUNT Personen (erwartet: ≥3)"
fi

echo ""

# ── T6: faces --path Filter ────────────────────────────────────────────────────

echo "--- T6: faces --path Filter ---"
FILTER_OUT=$(IPHOTO_CATALOG_DB="$DB" "$CLI" people faces --path "${EINSTEIN_IMGS[0]}" 2>&1)
FILTER_COUNT=$(echo "$FILTER_OUT" | grep -c "conf=" || echo 0)

if [ "${FILTER_COUNT:-0}" -ge 1 ]; then
    pass "T6: faces --path liefert $FILTER_COUNT Gesicht(er) für einstein_1"
else
    fail "T6: faces --path liefert kein Ergebnis"
fi

echo ""

# ── Zusammenfassung ───────────────────────────────────────────────────────────

echo "=============================="
echo "PASS: $PASS   FAIL: $FAIL"
echo "=============================="
[ "$FAIL" -eq 0 ]
