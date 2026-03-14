#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; ERRORS=$((ERRORS + 1)); }
info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

ERRORS=0

echo "========================================="
echo "  AgilSign Root CA - Verification"
echo "========================================="
echo

# 1. Certificate fingerprint
info "Verifying certificate fingerprint..."
COMPUTED=$(openssl x509 -in rootCA.pem -fingerprint -sha256 -noout 2>/dev/null | sed 's/.*=//')
EXPECTED=$(cat rootCA.fingerprint.txt | sed 's/^SHA-256: *//' | tr -d '[:space:]')

if [ "$COMPUTED" = "$EXPECTED" ]; then
    pass "Certificate fingerprint matches: $COMPUTED"
else
    fail "Fingerprint mismatch"
    echo "  Computed: $COMPUTED"
    echo "  Expected: $EXPECTED"
fi
echo

# 2. DNS TXT record
info "Verifying DNS TXT record..."
DNS_RAW=$(dig +short TXT _ca-fingerprint.agilsign.ar 2>/dev/null | tr -d '"')
if [ -z "$DNS_RAW" ]; then
    DNS_RAW=$(dig +short TXT _ca-fingerprint.agilsign.ar @8.8.8.8 2>/dev/null | tr -d '"')
fi
DNS_FP=$(echo "$DNS_RAW" | sed -n 's/.*fp=\([^ ;]*\).*/\1/p' | tr -d '[:space:]')

if [ -z "$DNS_RAW" ]; then
    fail "DNS TXT record not found for _ca-fingerprint.agilsign.ar"
elif [ "$DNS_FP" = "$COMPUTED" ]; then
    pass "DNS TXT record matches fingerprint"
else
    fail "DNS TXT record does not match"
    echo "  DNS:      $DNS_FP"
    echo "  Expected: $COMPUTED"
fi
echo

# 3. FreeTSA timestamp
info "Verifying RFC 3161 timestamp (FreeTSA)..."
FREETSA_CA="$TEMP_DIR/freetsa-cacert.pem"
if curl -sf https://freetsa.org/files/cacert.pem -o "$FREETSA_CA"; then
    RESULT=$(openssl ts -verify -data rootCA.pem -in rootCA.tsr.freetsa -CAfile "$FREETSA_CA" 2>&1)
    if echo "$RESULT" | grep -q "Verification: OK"; then
        TIMESTAMP=$(openssl ts -reply -in rootCA.tsr.freetsa -text 2>/dev/null | grep "Time stamp:" | sed 's/Time stamp: //')
        pass "FreeTSA timestamp verified - $TIMESTAMP"
    else
        fail "FreeTSA timestamp verification failed"
        echo "  $RESULT"
    fi
else
    fail "Could not download FreeTSA CA certificate"
fi
echo

# 4. Sectigo timestamp
info "Verifying RFC 3161 timestamp (Sectigo)..."
SECTIGO_TOKEN="$TEMP_DIR/sectigo_token.der"
SECTIGO_CERTS="$TEMP_DIR/sectigo_certs.pem"
SECTIGO_CHAIN="$TEMP_DIR/sectigo_chain.pem"
USERTRUST_CA="$TEMP_DIR/usertrust.pem"

openssl ts -reply -in rootCA.tsr.sectigo -token_out -out "$SECTIGO_TOKEN" 2>/dev/null
openssl pkcs7 -in "$SECTIGO_TOKEN" -inform DER -print_certs -out "$SECTIGO_CERTS" 2>/dev/null

cp "$SCRIPT_DIR/usertrust-rsa-root.pem" "$USERTRUST_CA" 2>/dev/null

if openssl x509 -in "$USERTRUST_CA" -noout 2>/dev/null; then
    cat "$SECTIGO_CERTS" "$USERTRUST_CA" > "$SECTIGO_CHAIN"
    RESULT=$(openssl ts -verify -data rootCA.pem -in rootCA.tsr.sectigo -CAfile "$SECTIGO_CHAIN" 2>&1)
    if echo "$RESULT" | grep -q "Verification: OK"; then
        TIMESTAMP=$(openssl ts -reply -in rootCA.tsr.sectigo -text 2>/dev/null | grep "Time stamp:" | sed 's/Time stamp: //')
        pass "Sectigo timestamp verified - $TIMESTAMP"
    else
        fail "Sectigo timestamp verification failed"
        echo "  $RESULT"
    fi
else
    fail "Could not download USERTrust RSA root CA"
fi
echo

# 5. OpenTimestamps (Bitcoin blockchain)
info "Verifying OpenTimestamps (Bitcoin blockchain)..."
if command -v ots &>/dev/null; then
    RESULT=$(ots --no-bitcoin verify -f rootCA.pem rootCA.ots 2>&1) || true
    if echo "$RESULT" | grep -qi "PendingAttestation\|pending"; then
        info "OpenTimestamps pending confirmation on Bitcoin blockchain"
        info "Run 'ots upgrade rootCA.ots' later to complete the proof"
    elif echo "$RESULT" | grep -q "merkleroot"; then
        BLOCK=$(echo "$RESULT" | sed -n 's/.*block \([0-9]*\).*/\1/p')
        EXPECTED_MR=$(echo "$RESULT" | sed -n 's/.*merkleroot \([0-9a-f]*\).*/\1/p')
        BLOCK_HASH=$(curl -sf "https://blockstream.info/api/block-height/$BLOCK" 2>/dev/null)
        if [ -n "$BLOCK_HASH" ]; then
            ACTUAL_MR=$(curl -sf "https://blockstream.info/api/block/$BLOCK_HASH" 2>/dev/null \
                | python3 -c "import sys,json; print(json.load(sys.stdin)['merkle_root'])" 2>/dev/null)
            if [ "$ACTUAL_MR" = "$EXPECTED_MR" ]; then
                pass "OpenTimestamps verified - Bitcoin block $BLOCK (merkle root matches)"
            else
                fail "OpenTimestamps merkle root mismatch at block $BLOCK"
                echo "  Expected: $EXPECTED_MR"
                echo "  Actual:   $ACTUAL_MR"
            fi
        else
            fail "Could not fetch Bitcoin block $BLOCK from blockstream.info"
        fi
    elif echo "$RESULT" | grep -qi "success\|verified"; then
        pass "OpenTimestamps verified on Bitcoin blockchain"
    else
        fail "OpenTimestamps verification failed"
        echo "  $RESULT"
    fi
else
    info "Skipped - 'ots' command not installed (pip install opentimestamps-client)"
fi
echo

# Summary
echo "========================================="
if [ $ERRORS -eq 0 ]; then
    echo -e "  ${GREEN}All verifications passed${NC}"
else
    echo -e "  ${RED}$ERRORS verification(s) failed${NC}"
fi
echo "========================================="

exit $ERRORS
