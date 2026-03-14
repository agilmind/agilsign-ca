# AgilSign Root CA

Public trust anchor for the AgilSign Certificate Authority.

## Fingerprint

See `rootCA.fingerprint.txt` for the SHA-256 fingerprint of the Root CA.

This fingerprint is also published as a DNS TXT record at `_ca-fingerprint.agilsign.ar`.

## Files

| File | Description |
|------|-------------|
| `rootCA.pem` | Root CA certificate (PEM format) |
| `rootCA.fingerprint.txt` | SHA-256 fingerprint |
| `rootCA.tsr.freetsa` | RFC 3161 timestamp (FreeTSA) |
| `rootCA.tsr.sectigo` | RFC 3161 timestamp (Sectigo) |
| `rootCA.ots` | OpenTimestamps proof (Bitcoin blockchain) |
| `anchor-report.json` | Anchoring metadata and results |
| `usertrust-rsa-root.pem` | USERTrust RSA root CA (for Sectigo chain verification) |
| `verify.sh` | Automated verification script |

## Verification

### Automated

The `verify.sh` script verifies all trust anchors automatically (downloads required CA certificates into a temp directory):

```bash
./verify.sh
```

Requires: `openssl`, `curl`, `dig`. Optionally `ots` ([opentimestamps-client](https://github.com/opentimestamps/opentimestamps-client)) for Bitcoin blockchain verification.

### Manual

#### Certificate Fingerprint
```bash
openssl x509 -in rootCA.pem -fingerprint -sha256 -noout
```

#### DNS TXT
```bash
dig TXT _ca-fingerprint.agilsign.ar
```

#### RFC 3161 Timestamps

FreeTSA:
```bash
curl -o /tmp/freetsa-cacert.pem https://freetsa.org/files/cacert.pem
openssl ts -verify -data rootCA.pem -in rootCA.tsr.freetsa -CAfile /tmp/freetsa-cacert.pem
```

Sectigo (requires extracting the certificate chain from the TSR and the USERTrust RSA root CA):
```bash
openssl ts -reply -in rootCA.tsr.sectigo -token_out -out /tmp/sectigo_token.der
openssl pkcs7 -in /tmp/sectigo_token.der -inform DER -print_certs -out /tmp/sectigo_certs.pem
curl -o /tmp/usertrust.pem 'https://crt.sh/?d=1199354'
cat /tmp/sectigo_certs.pem /tmp/usertrust.pem > /tmp/sectigo_chain.pem
openssl ts -verify -data rootCA.pem -in rootCA.tsr.sectigo -CAfile /tmp/sectigo_chain.pem
```

#### OpenTimestamps
```bash
ots verify rootCA.ots
```
