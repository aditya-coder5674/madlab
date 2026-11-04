# CodeArena Android Build Guide

The Flutter Android app is an additional native client. The existing website and Node backend remain separate and unchanged.

## Architecture and Features

- `flutter_app/lib/screens/` contains the home dashboard, searchable problem bank, problem details, debugging arena, editor, authentication, profile, and leaderboard availability screens.
- `flutter_app/lib/models/` defines the problem, debugging-question, and interactive-run data types.
- `flutter_app/lib/services/` contains the bundled-data repository, Dio API client, secure session-cookie handling, authentication, Judge0 polling, interactive-run streaming, and device-local accepted progress.
- `flutter_app/lib/config/api_config.dart` reads `API_BASE_URL` from a Dart compile-time define.
- `flutter_app/lib/state/` contains the authentication controller; reusable UI state components are in `flutter_app/lib/widgets/`.
- `flutter_app/assets/data/` contains JSON generated directly from `js/questions.js`. Regenerate it after source problem changes with `node flutter_app/tool/sync_question_assets.js`.
- `flutter_app/android/` is the native Android Gradle project. The application ID is `com.codearena.codearena`, the label is `CodeArena`, and the launcher icon is a native vector resource.

The problem browser includes the source problem titles, descriptions, examples, constraints, tags, test inputs, and language starter code. The app preserves those values but does not certify the problems: the repository README warns that some problem test cases and expected answers are incomplete or not independently verified. The debugging questions are also shown as provided; their correctness has not been independently audited.

The editor is a native monospace text editor with language-specific starter code, basic automatic indentation, a live output panel, stdin input, and separate Run and Submit actions. It does not currently provide syntax highlighting. Run streams events from the isolated Docker runner; it does not execute locally or fake a result. Submit calls Judge0 through the Node backend and polls the returned execution ID.

Authentication uses the existing `/api/auth/register`, `/api/auth/login`, `/api/auth/logout`, and `/api/auth/me` endpoints. The app saves only the returned HTTP-only session cookie using Android secure storage; it never stores passwords. Accepted problem/debugging counts are device-local and are not represented as server-side account progress. The backend has no live leaderboard endpoint, so leaderboard rows are not presented as current rankings.

## Backend Availability

The configured public site at `https://madlab-beige.vercel.app` was probed on 2026-11-04. The auth, judge, and run API paths returned HTTP 500 `FUNCTION_INVOCATION_FAILED`, including for empty validation requests. Do not configure this deployment as a usable API until its server functions are repaired and verified. The mobile UI reports request errors and does not substitute mock authentication or execution.

The existing Node backend can provide the required API routes when deployed in an environment that supports its process and Docker requirements:

- Auth routes require persistent writable server-side auth storage for accounts/sessions.
- Submit requires a valid server-side `JUDGE0_BASE_URL` and any provider credentials configured on the backend. Never put Judge0 credentials in Flutter or GitHub variables.
- Run requires a reachable Docker daemon and the `madlab-runner:latest` image built from the existing `Dockerfile.runner`. Serverless deployments without Docker cannot provide this feature.
- The backend currently keeps execution jobs in process memory and is designed to run as one instance.

## Local Setup

Install Flutter stable and Android SDK tools, accept Android SDK licenses, and use Java 17. From the repository root:

```bash
cd flutter_app
flutter doctor
flutter pub get
flutter analyze
flutter test
```

For a standard Android emulator and a Node backend running on the development host:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

The Android debug manifest allows cleartext traffic for local testing only. For a physical phone on the same network, run the backend bound to a LAN-accessible interface and use the development computer's LAN IP, for example `http://192.168.1.20:8000`. Allow the port through the host firewall and keep the phone and computer on the same network. Replace the example address with the actual address on your network.

For release builds, the app requires an HTTPS `API_BASE_URL`. A missing URL leaves browsing available but disables server-dependent auth, Run, and Submit with an explanatory error.

## Build the APK Locally

From the repository root:

```bash
cd flutter_app
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR_BACKEND_URL
```

The installable APK is written to:

```text
flutter_app/build/app/outputs/flutter-apk/app-release.apk
```

For personal sideload testing, the generated release configuration uses the local debug signing key. Keep that key private and do not use it as a Play Store upload key. Play publishing requires a private upload keystore, a protected signing configuration (typically supplied through CI secrets), and enrollment in Play App Signing. No signing passwords or keystores are committed by this project.

## Build with GitHub Actions

1. In repository Settings → Secrets and variables → Actions → Variables, add `API_BASE_URL` with the HTTPS backend origin that has been verified to serve the APIs.
2. Open Actions → **Build CodeArena Android APK** → Run workflow.
3. Wait for dependency resolution, analysis, tests, and release build to complete.
4. Open the completed workflow run and download the `CodeArena-Android-APK` artifact.

The workflow builds `flutter_app/build/app/outputs/flutter-apk/app-release.apk` with `--dart-define=API_BASE_URL=${{ vars.API_BASE_URL }}`. If the repository variable is absent, the APK still builds but server features remain unconfigured. The workflow does not use or print API credentials.

## Install on Android

1. Download and extract the `CodeArena-Android-APK` artifact, or locate the local APK at the path above.
2. Transfer `app-release.apk` to the phone, or install over USB with `adb install -r app-release.apk`.
3. If prompted, allow the file manager or browser to install unknown apps, then open the APK and confirm installation.
4. Verify that the APK was built with a reachable HTTPS `API_BASE_URL`; an APK built without it can browse bundled content but cannot authenticate, submit, or run code.

## Automated Checks

The GitHub workflow runs `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build apk --release`. Local Flutter tests verify the bundled datasets and dashboard initialization. They do not verify a live Judge0 provider, remote authentication, or the deployment's Docker runner. Those require a functioning backend and configured provider/runner services.