# Security — Android (Java/Kotlin)

Mandatory checks before merging any Android code.

## Secrets & credentials

- Never commit API keys, tokens, signing keys, keystores, or `google-services.json` with prod IDs. Use `local.properties` (gitignored) + `BuildConfig` fields, or `gradle.properties` env injection.
- No hardcoded URLs to staging/prod in source. Resolve via `BuildConfig.BASE_URL` per build flavor.
- Keystore passwords pulled from env vars or `~/.gradle/gradle.properties`, never the repo.
- Scan diffs for `Authorization`, `Bearer`, `-----BEGIN`, `api_key`, `apiKey`, `password\s*=` before commit.

## Network

- `cleartextTrafficPermitted="false"` in `network-security-config.xml`. Cleartext only allowed per-domain for documented dev hosts.
- HTTPS only for production endpoints. Pin certificates for high-value APIs (`OkHttp CertificatePinner` or `network-security-config` pin-set).
- Disable HTTP cache for responses containing auth tokens.
- Validate TLS hostname; never set `HostnameVerifier { _, _ -> true }` or trust-all `X509TrustManager` outside instrumented debug builds.

## Storage

- Tokens, refresh tokens, PII → Jetpack `DataStore` encrypted with Tink, keys in Android Keystore. Never plain `SharedPreferences`. `EncryptedSharedPreferences` and all of `androidx.security:security-crypto` are [deprecated with no further releases](https://developer.android.com/privacy-and-security/cryptography); migrate existing uses at next touch.
- DB containing PII → Room with SQLCipher via [`sqlcipher-android`](https://github.com/sqlcipher/sqlcipher-android)'s `SupportOpenHelperFactory`. The old `android-database-sqlcipher` (`SupportFactory`) is deprecated.
- `android:allowBackup="false"` and `android:dataExtractionRules` configured unless backup is a product requirement and PII is excluded.
- External storage writes use scoped storage APIs (Android 10+). No `MANAGE_EXTERNAL_STORAGE` without policy approval.

## Permissions

- Declare the minimum permission set. Audit `AndroidManifest.xml` on every PR that touches it.
- Runtime permissions: request just-in-time, with rationale UI. Handle "Don't ask again" state.
- Never request `READ_SMS`, `READ_CALL_LOG`, `RECEIVE_SMS`, `ACCESS_BACKGROUND_LOCATION`, or `QUERY_ALL_PACKAGES` without Play policy justification.

## Components & IPC

- Exported components (`activity`, `service`, `receiver`, `provider`) must set `android:exported` explicitly; default to `false`.
- Validate every `Intent` extra and `Uri` from external apps — treat as untrusted input.
- Create `PendingIntent`s with `FLAG_IMMUTABLE` unless they must be mutable. Apps targeting API 31+ [must declare mutability](https://developer.android.com/about/versions/12/behavior-changes-12) on every `PendingIntent`.
- Deep links: verify host with App Links assetlinks.json; sanitize parameters before routing.
- No `WebView` with `setJavaScriptEnabled(true)` over untrusted content. If JS bridges required, use `@JavascriptInterface` on API 17+ only and whitelist origins.

## Crypto

- Use Tink, with keys in Android Keystore. Not `androidx.security.crypto` (deprecated). No raw `Cipher` with custom modes.
- AES-GCM (not ECB, not CBC without HMAC). Random IVs from `SecureRandom`.
- Keys live in Android Keystore (`AndroidKeyStore`) with `setUserAuthenticationRequired` where appropriate.
- No MD5/SHA-1 for security purposes. SHA-256+ only.

## Logging

- Strip `Log.d/v/i` of PII, tokens, request bodies in release builds. Use `Timber` with a release tree that drops below WARN.
- Crash reporters (Crashlytics, Sentry) must not capture auth headers or response bodies of authenticated requests.

## Dependencies

- Run `./gradlew dependencyUpdates` (Ben Manes) and `./gradlew :app:dependencyCheckAnalyze` (OWASP) before release.
- No SNAPSHOT, no `+` version ranges. Pin to exact versions in `libs.versions.toml`.
- Verify Gradle wrapper SHA256 (`gradle/wrapper/gradle-wrapper.properties` + checksum).

## Pre-merge security gate

Reject the PR if any of the following are true:

- [ ] New permission added without justification in the PR description.
- [ ] `android:exported="true"` added without intent filter signature review.
- [ ] Cleartext or trust-all networking introduced.
- [ ] Secret or key material in diff.
- [ ] Crypto primitive weaker than AES-GCM-256 or SHA-256 introduced.
- [ ] New `WebView` without explicit JS / file-access settings review.

See also: [coding-style.md](coding-style.md), [testing.md](testing.md).

_Last verified against developer.android.com and kotlinlang.org: 2026-11-26 (API 36, Kotlin 2.x, AGP 9). Every Android API, Gradle setting, and Play requirement in this file was checked. The scheduled rules review re-checks them._
