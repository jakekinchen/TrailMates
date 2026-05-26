# Signing Credentials

This folder contains non-private Apple code signing templates and metadata for
App Store distribution. Private key material and `.p12` files must stay outside
the repo checkout.

## Files

| File | Purpose | Sensitive? |
|------|---------|------------|
| `distribution_private.key` | Private key for distribution certificate | **YES - NEVER COMMIT** |
| `distribution.p12` | Combined certificate + private key (password: see 1Password) | **YES - NEVER COMMIT** |
| `distribution.cer` | Distribution certificate from Apple | No |
| `distribution.pem` | PEM format of certificate | No |
| `CertificateSigningRequest.certSigningRequest` | CSR used to generate certificate | No |
| `TrailMates_AppStore.mobileprovision` | App Store provisioning profile | No |
| `ExportOptions.plist` | Export settings for xcodebuild | No |

## Certificate Details

- **Identity**: Apple Distribution: Jake Kinchen (BN58T9KR6C)
- **Team ID**: BN58T9KR6C
- **Expires**: January 29, 2027
- **Bundle ID**: com.bridges.trailmatesatx

## Local Private Material

Private signing files were moved out of the checkout to:

```bash
../TrailMates-local-artifacts/signing/
```

Import the `.p12` from that local artifact folder when archiving locally. Do not
copy private keys or `.p12` files back into this repo.

## Regenerating Credentials

If the certificate expires or is revoked:

```bash
# 1. Generate new CSR and private key
openssl req -new -newkey rsa:2048 -nodes \
  -keyout distribution_private.key \
  -out CertificateSigningRequest.certSigningRequest \
  -subj "/emailAddress=jakekinchen@gmail.com/CN=Jake Kinchen/C=US"

# 2. Upload CSR to Apple Developer Portal
#    https://developer.apple.com/account/resources/certificates/add
#    Select "Apple Distribution"

# 3. Download the .cer and convert
openssl x509 -in distribution.cer -inform DER -out distribution.pem -outform PEM

# 4. Create .p12 (use -legacy for macOS Keychain compatibility)
openssl pkcs12 -export \
  -out distribution.p12 \
  -inkey distribution_private.key \
  -in distribution.pem \
  -password pass:YOUR_PASSWORD \
  -legacy

# 5. Import to Keychain
security import distribution.p12 -k ~/Library/Keychains/login.keychain-db -P YOUR_PASSWORD -T /usr/bin/codesign
```

## Creating New Provisioning Profile

1. Go to https://developer.apple.com/account/resources/profiles/add
2. Select "App Store Connect"
3. Select App ID: `com.bridges.trailmatesatx`
4. Select the distribution certificate
5. Download and place in this folder
6. Install: `cp *.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/`
