# AgilSign Root CA

Public trust anchor for the AgilSign Certificate Authority.

## Current root: AgilSign Root CA G2

- **Subject:** CN=AgilSign Root CA G2, O=AgilMind, C=AR
- **Algorithm:** ECDSA P-384 with SHA-384 (~192-bit security)
- **Validity:** 2026-11-22 to 2046-11-17 (20 years)
- **SHA-256 fingerprint:**
  `E6:01:3A:16:9D:79:6C:54:03:9F:0C:80:D8:BD:6B:0A:C6:48:98:07:30:7E:8A:E0:86:49:3C:BC:21:A1:D3:31`

The root is **offline**: its private key is not on any server. It signs only
the issuing CA and its own revocation list.

```
AgilSign Root CA G2          offline, 20 years, pathlen 1
  └─ AgilSign Issuing CA 2026   5 years, pathlen 0        (issuingCA.pem)
       ├─ signing certificate   2 years
       └─ OCSP responder        90 days
```

The same fingerprint is published at:

- https://agilsign.ar/trust
- the DNS TXT record `_ca-fingerprint.agilsign.ar`

## Retired roots

A retired root no longer issues certificates. It is not revoked: documents
signed under it stay valid.

| Root | SHA-256 fingerprint | In service | Files |
|------|---------------------|------------|-------|
| CN=AgilSign Root CA, O=AgilMind, C=AR | `EC:64:18:8B:B4:95:55:F8:6A:93:FA:3C:D1:4B:B5:F6:AC:B4:B4:4F:DC:53:D2:06:09:04:9F:1E:46:C9:5B:74` | 2026-04-06 to 2026-11-22 11:10 UTC | `retired/2026-04-06-agilsign-root-ca/` |

That root was an online root that signed the signing certificates directly. It
was replaced by the hierarchy above, with the root offline and an intermediate
issuing CA.

**Documents signed under a retired root** are recognized as AgilSign's when
they carry independent proof that the signature existed before the retirement:
an RFC 3161 timestamp from a recognized time-stamping authority, or a confirmed
Bitcoin anchor of the signed file. AgilSign documents carry a timestamp by
default. A signature under a retired root with no such proof is reported as
intact but from an unrecognized issuer.

## Files

| File | Description |
|------|-------------|
| `rootCA.pem` | Current root certificate (PEM) |
| `rootCA.fingerprint.txt` | Its SHA-256 fingerprint |
| `issuingCA.pem` | Current issuing CA certificate (PEM) |
| `rootCA.tsr.freetsa` | RFC 3161 timestamp of `rootCA.pem` (FreeTSA) |
| `rootCA.tsr.sectigo` | RFC 3161 timestamp of `rootCA.pem` (Sectigo) |
| `rootCA.ots` | OpenTimestamps proof of `rootCA.pem` (Bitcoin blockchain) |
| `anchor-report.json` | Anchoring metadata |
| `usertrust-rsa-root.pem` | USERTrust RSA root, needed to verify the Sectigo timestamp |
| `verify.sh` | Automated verification script |
| `retired/<date>-<name>/` | The same evidence for each retired root |

## Verification

### Automated

```bash
./verify.sh                                        # the current root
./verify.sh retired/2026-04-06-agilsign-root-ca    # a retired root
```

Requires `openssl`, `curl` and `dig`. Optionally `ots`
([opentimestamps-client](https://github.com/opentimestamps/opentimestamps-client))
for the Bitcoin proof.

### Manual

Fingerprint:
```bash
openssl x509 -in rootCA.pem -fingerprint -sha256 -noout
```

Issuing CA chains to the root:
```bash
openssl verify -CAfile rootCA.pem issuingCA.pem
```

DNS TXT (lowercase hex, no colons):
```bash
dig TXT _ca-fingerprint.agilsign.ar
```

RFC 3161 timestamps:
```bash
curl -o /tmp/freetsa-cacert.pem https://freetsa.org/files/cacert.pem
openssl ts -verify -data rootCA.pem -in rootCA.tsr.freetsa -CAfile /tmp/freetsa-cacert.pem

openssl ts -reply -in rootCA.tsr.sectigo -token_out -out /tmp/sectigo_token.der
openssl pkcs7 -in /tmp/sectigo_token.der -inform DER -print_certs -out /tmp/sectigo_certs.pem
cat /tmp/sectigo_certs.pem usertrust-rsa-root.pem > /tmp/sectigo_chain.pem
openssl ts -verify -data rootCA.pem -in rootCA.tsr.sectigo -CAfile /tmp/sectigo_chain.pem
```

OpenTimestamps:
```bash
ots verify -f rootCA.pem rootCA.ots
```

## History

- **2026-11-22:** New offline root, AgilSign Root CA G2, with an intermediate
  issuing CA. The previous root was retired.
- **2026-04-06:** Production root (ECDSA P-384), online. Retired 2026-11-22.
- **2026-04-05:** Migrated from RSA-4096 to ECDSA P-384 + SHA-384.
- **2026-03-14:** Initial Root CA (RSA-4096, retired).
