# Security — Swift / SwiftUI (iOS / macOS)

Mandatory checks before merging any Apple-platform code.

## Secrets & credentials

- Never commit API keys, tokens, signing certs, provisioning profiles, or `*.p12`/`*.mobileprovision`. Inject via `.xcconfig` (gitignored) + `Info.plist` substitution, or a build-time secrets step, not source.
- No hardcoded staging/prod URLs in source. Resolve via `.xcconfig` build settings per configuration/scheme.
- Signing identities and App Store Connect keys pulled from CI secret storage / Keychain, never the repo.
- Scan diffs for `Authorization`, `Bearer`, `-----BEGIN`, `api_key`, `apiKey`, `password\s*=`, and `AIza`/`gh[pousr]_` token shapes before commit.

## Network

- App Transport Security on: no global `NSAllowsArbitraryLoads`. Cleartext only per-domain via `NSExceptionDomains` for documented dev hosts.
- HTTPS only for production endpoints. Pin certificates for high-value APIs declaratively with [`NSPinnedDomains`](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nspinneddomains) (`NSPinnedCAIdentities` / `NSPinnedLeafIdentities`) under `NSAppTransportSecurity` in `Info.plist`. Fall back to `URLSession`'s `urlSession(_:didReceive:)` challenge handler or a vetted pinning library only when ATS can't express the pinning policy.
- Disable URL cache for responses carrying auth tokens (`.reloadIgnoringLocalCacheData` / no-store).
- Never disable TLS validation. No "trust all" `URLAuthenticationChallenge` handler that calls `.useCredential` with an unverified server trust outside a `#if DEBUG` simulator build.

## Storage

- Tokens, refresh tokens, PII → **Keychain** (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` or stricter), never `UserDefaults`.
- Databases containing PII → SQLCipher (GRDB) or encrypt the store; for SwiftData/Core Data use file-protection `.completeUnlessOpen` or stronger plus an encrypted container.
- Set file protection (`.complete`/`.completeUnlessOpen`) on sensitive files written to disk.
- Exclude sensitive caches from iCloud/iTunes backup (`URLResourceValues.isExcludedFromBackup`) unless backup is a product requirement and PII is excluded.

## Permissions

- Declare the minimum entitlements and `Info.plist` usage strings. Audit `Info.plist` on every PR that adds a `NS*UsageDescription`.
- Request runtime authorization just-in-time, with rationale UI. Handle the denied / restricted / limited states explicitly.
- Ship a [privacy manifest](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files) (`PrivacyInfo.xcprivacy`) in the app and in every first-party framework or package that calls a required-reason API (`UserDefaults`, file timestamps, system boot time, disk space, active keyboards). Declare an [approved reason](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api) for each; App Store Connect rejects uploads that omit them. Verify third-party SDKs ship their own manifests.
- Never request Contacts, Photos full-library, background location, microphone, or local-network access without a documented product justification — App Review will ask, and so should the reviewer.

## Components & IPC

- Validate every URL-scheme parameter, universal-link path, and `NSUserActivity` payload from outside the app — treat as untrusted input.
- Universal links: verify the associated-domains `apple-app-site-association` is correct; sanitize parameters before routing.
- App extensions and the host app share data only through an App Group container with validated contents.
- `WKWebView`: never load untrusted content with JavaScript bridges open. If a `WKScriptMessageHandler` bridge is required, whitelist origins and validate every message body.

## Crypto

- Use **CryptoKit** (or vetted libsodium bindings). No hand-rolled `CommonCrypto` with custom modes.
- AES-GCM (`AES.GCM`), not ECB, not unauthenticated CBC. Nonces from the system CSPRNG (CryptoKit generates them).
- Keys live in the Secure Enclave (`SecureEnclave.P256`) or Keychain with access control; gate with `LAContext` / `.userPresence` where appropriate.
- No MD5/SHA-1 for security purposes. `SHA256` or stronger only.
- For new key exchange or signatures protecting long-lived data, prefer [CryptoKit](https://developer.apple.com/documentation/cryptokit)'s post-quantum APIs (`XWingMLKEM768X25519` hybrid KEM, `MLKEM768`, `MLDSA65`) where the deployment target allows.

## Logging

- Strip PII, tokens, and request bodies from release logs. Use `os.Logger` and mark every interpolated value that could be sensitive `privacy: .private` explicitly: [by default](https://developer.apple.com/documentation/os/generating-log-messages-from-your-code) only dynamic strings and objects are redacted, while integers, floats, and Booleans are logged in clear. Mark only non-sensitive values `.public`.
- Crash reporters must not capture auth headers or authenticated response bodies. Scrub before send.

## Dependencies

- Pin Swift Package versions to exact tags / commit hashes in `Package.resolved`; commit `Package.resolved`. No branch or `from: "x"` ranges for security-relevant deps.
- Review new package adds for maintenance status and transitive footprint. Audit periodically.
- Verify the Xcode / toolchain version in CI matches the pinned one.

## Build hardening

- Enable the [Enhanced Security](https://developer.apple.com/documentation/xcode/enabling-enhanced-security-for-your-app) capability (Signing & Capabilities) on app targets unless a documented incompatibility blocks it. The `audit-xcode-security-settings` skill walks the related compiler and analyzer settings.

## Pre-merge security gate

Reject the PR if any of the following are true:

- [ ] New entitlement or `NS*UsageDescription` added without justification in the PR description.
- [ ] ATS exception or cleartext networking introduced.
- [ ] TLS validation weakened / "trust all" challenge handler outside `#if DEBUG`.
- [ ] Secret, signing cert, or provisioning profile in diff.
- [ ] Sensitive data written to `UserDefaults` or an unencrypted store.
- [ ] Crypto primitive weaker than AES-GCM-256 or SHA-256 introduced.
- [ ] New `WKWebView` with a JS bridge over untrusted content without origin review.
- [ ] Required-reason API added, or collected-data / tracking behavior changed, without a matching `PrivacyInfo.xcprivacy` update.

See also: [coding-style.md](coding-style.md), [testing.md](testing.md).

_Last verified against developer.apple.com: 2026-11-26 (iOS 27 SDK, Swift 6.2). Every Apple API, build setting, and Info.plist key in this file was checked. The scheduled rules review re-checks them._
