# CI/CD

Everything lives in [`.github/workflows/main.yaml`](../.github/workflows/main.yaml). One workflow,
six jobs, and the APK is built **once** — the `distribute` job downloads the artifact rather than
rebuilding it.

```
PR to main ─┬─ semantic-pull-request
            ├─ spell-check
            ├─ no-network-deps
            ├─ analyze-and-test   (format · analyze · bloc lint · test @ 100% coverage)
            └─ build-android      (signed release APK, staging flavor) ──→ artifact

push to main ─── same jobs ──→ distribute (needs: analyze-and-test, build-android)
                                 └─ downloads artifact ──→ Firebase App Distribution
```

`distribute` is gated on `push`/`workflow_dispatch` **and** `refs/heads/main`, so it never runs from
a PR. `workflow_dispatch` is enabled so you can re-distribute the current `main` without pushing a
commit — useful for a first end-to-end test.

`license_check.yaml` is separate and unchanged; it only runs when `pubspec.yaml` changes.

## What each job protects

| Job | Catches |
|---|---|
| `analyze-and-test` | Formatting, `very_good_analysis` + `bloc_lint` violations, failing tests, coverage below 100% |
| `build-android` | Gradle/AGP/Kotlin breakage, R8 stripping, manifest errors, signing config errors |
| `no-network-deps` | A network, analytics or crash-reporting package entering direct dependencies (PRD non-goals) |
| `semantic-pull-request` | Non-conventional PR titles — the squash-merge subject becomes the release note |
| `license_check` | A dependency under a license outside MIT/BSD/Apache-2.0 |

### Codegen in CI

`drift_dev`, `freezed` and `json_serializable` produce files that are **not** committed. Both
`analyze-and-test` (via the reusable workflow's `setup:` input) and `build-android` run:

```sh
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
```

If you add a generator, it works in CI automatically. If you ever commit generated output instead,
remove these steps — running both is how you get "conflicting outputs" failures.

### Coverage

The threshold is **100%**, with generated code and flavor entrypoints excluded from the denominator:

```
lib/l10n/gen/**  lib/main_*.dart  lib/bootstrap.dart  **/*.g.dart  **/*.freezed.dart
```

This is deliberate: the occurrence engine (`core/scheduling/`) is pure, I/O-free logic and there is
no excuse for it to be partially covered. Reproduce the CI check locally with:

```sh
very_good test --coverage --min-coverage 100 \
  --exclude-coverage "{lib/l10n/gen/**,lib/main_*.dart,lib/bootstrap.dart,**/*.g.dart,**/*.freezed.dart}"
```

Note the exclude syntax differs between the two: the reusable workflow takes a **space-separated**
list, the `very_good test` CLI takes a **single brace-expanded glob**.

---

## Required secrets

Settings → Secrets and variables → Actions.

### Android signing

Generate an upload keystore **once**, locally:

```sh
keytool -genkeypair -v -keystore upload.jks -storetype PKCS12 \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
base64 -w0 upload.jks
```

`*.jks` is already gitignored. **Back `upload.jks` up somewhere outside the repo** — if the app ever
reaches the Play Store, losing this key is unrecoverable.

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | output of `base64 -w0 upload.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | store password |
| `ANDROID_KEYSTORE_ALIAS` | `upload` |
| `ANDROID_KEYSTORE_PRIVATE_KEY_PASSWORD` | key password |

No Gradle changes were needed for this — [`android/app/build.gradle.kts`](../android/app/build.gradle.kts)
already reads these env vars and falls back to `key.properties` for local builds.

### Firebase App Distribution

| Secret | Value |
|---|---|
| `FIREBASE_ANDROID_APP_ID` | `1:…:android:…`, from Project settings → Your apps |
| `FIREBASE_SERVICE_ACCOUNT` | the full service-account JSON, pasted as-is |

Setup in the Firebase console:

1. Register an Android app with package name **`com.example.verygoodcore.coach_app.stg`** — the
   `staging` flavor's `applicationIdSuffix`. Verified against the built APK.
2. App Distribution → Testers & Groups → create a group with alias **`internal`**, add yourself.
   The alias must match `--groups internal` in the workflow.
3. IAM → create a service account with the **Firebase App Distribution Admin** role, create a JSON
   key, paste the whole file into `FIREBASE_SERVICE_ACCOUNT`.

**No `google-services.json` and no Firebase SDK dependency are required.** App Distribution uploads
a binary through the CLI; the app itself stays entirely offline, as the PRD requires. The
`no-network-deps` job will fail the build if a `firebase_*` package is ever added to `pubspec.yaml`.

> ⚠️ The `applicationId` is still the Very Good CLI placeholder
> `com.example.verygoodcore.coach_app` (see the `TODO` in `android/app/build.gradle.kts`). Changing
> it **after** registering the Firebase Android app means re-registering it. Decide the real ID
> first.

---

## Versioning

`--build-number=${{ github.run_number }}` sets `versionCode` on every build, so it is monotonic and
unique across runs. The `+1` in `pubspec.yaml` would otherwise repeat on every build and App
Distribution would treat successive uploads as the same release. `versionName` still comes from
`pubspec.yaml` (`1.0.0`).

## Toolchain versions

Pinned in one place each — keep them in sync when upgrading Flutter:

| Where | Value |
|---|---|
| `pubspec.yaml` | `flutter: ^3.47.0`, `sdk: ^3.12.0` |
| `main.yaml` (`FLUTTER_VERSION` + `analyze-and-test` input) | `3.47.x` |
| CI JDK | Temurin 17 |
| `android/gradle/wrapper/` | Gradle 9.1.0 |
| `android/settings.gradle.kts` | AGP 8.12.0, Kotlin 2.2.20 |

Flutter 3.47 requires Kotlin ≥ 2.2.20. Gradle 9.1.0 (rather than 9.0.0) is what allows a local JDK
25 to build; CI pins JDK 17 either way.

## Not covered

- **iOS.** macOS runners bill at 10× and there is no Apple Developer account or signing identity
  yet. Add a job when iOS distribution becomes real.
- **Play Store submission.** If that arrives, revisit fastlane — tracks, metadata and screenshot
  automation are exactly what it is good at and exactly what this pipeline does not do. For a single
  Android target with no store submission, the Ruby toolchain buys nothing.
- **APK size.** The universal APK is ~50 MB (all three ABIs plus the SQLite native libs). That is
  the right shape for App Distribution, where a single installable matters more than download size.
  `--split-per-abi` is the lever if that ever changes.
