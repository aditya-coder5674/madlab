# CodeArena Android Build Guide

The Flutter Android app is an additional native client. The original website files remain unchanged. `Dockerfile.backend`, `compose.backend.yaml`, and `Caddyfile` provide an optional self-hosted Node backend stack; it has not been deployed to a public host from this workspace.

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

## API URL Configuration

- The Flutter app's only backend base URL is the `API_BASE_URL` compile-time value read by `flutter_app/lib/config/api_config.dart`. The GitHub Actions APK build reads the same-named repository variable.
- The browser frontend in `js/app.js` calls relative `/api/...` paths, so it talks to the same origin that served the website; it has no separate hardcoded backend host.
- `JUDGE0_BASE_URL` in `.env.example` and the backend environment is the upstream code-judging provider URL, not the CodeArena API URL.
- Loopback addresses in `tests/`, `compose.backend.yaml`, and the simulated shell files in `js/app.js`/`codearena_final.html` are local test, health-check, or shell-demo values. They are not APK backend settings. No Codespaces `*.app.github.dev` URL is checked in.

## Backend Availability

The configured public site at `https://madlab-beige.vercel.app` was probed on 2026-11-04. The auth, judge, and run API paths returned HTTP 500 `FUNCTION_INVOCATION_FAILED`, including for empty validation requests. Do not configure this deployment as a usable API until its server functions are repaired and verified. The mobile UI reports request errors and does not substitute mock authentication or execution.

The existing Node backend can provide the required API routes when deployed in an environment that supports its process and Docker requirements:

- Auth routes require persistent writable server-side auth storage for accounts/sessions.
- Submit requires a valid server-side `JUDGE0_BASE_URL` and any provider credentials configured on the backend. Never put Judge0 credentials in Flutter or GitHub variables.
- Run requires a reachable Docker daemon and the `madlab-runner:latest` image built from the existing `Dockerfile.runner`. Serverless deployments without Docker cannot provide this feature.
- The backend currently keeps execution jobs in process memory and is designed to run as one instance.

## Deploy a Persistent HTTPS Backend

The current Vercel deployment returned HTTP 500 for its API routes. Vercel's serverless functions are not a suitable host for this backend as written: Run needs a Docker daemon and shared source mount, while auth data and judge jobs need persistent writable storage and one long-lived Node process. Do not point the APK at the Vercel URL until those API routes are repaired and verified.

### Render free web service

The repository includes `render.yaml` and a minimal `package.json` for a Render Node web service. To deploy:

1. Push this repository to GitHub and sign in to [Render](https://render.com/).
2. Choose **New → Blueprint**, connect the repository, and approve the `codearena-backend` service. Keep the generated `CODEARENA_SESSION_SECRET` private.
3. In the service's **Environment** settings, enter a real `JUDGE0_BASE_URL` and any provider credentials your Judge0 service requires. Do not use the example placeholder. Save and let Render deploy.
4. Copy the service's HTTPS URL, then verify `https://YOUR-SERVICE.onrender.com/health` returns `{"status":"ok"}`. The app root should serve the web frontend.
5. Build the APK with that exact HTTPS origin using the command below.

Render's free service sleeps when idle and can take time to wake; its URL stays the same, but it is not continuously available. Free instances have no persistent disk, so account/session data stored by this backend can be lost when the service restarts or redeploys. The free plan also does not provide the Docker runner required by interactive **Run**; **Submit** can work when a real Judge0 provider is configured. Use a host with persistent storage and Docker support for durable accounts and interactive runs.

The repository now includes a single-instance Docker Compose stack for a dedicated Ubuntu VPS with Docker and Docker Compose installed. It runs the existing Node server, persists auth records, provides the Docker CLI/socket and shared runner temp path, and puts Caddy in front for automatic HTTPS. The backend is configured to require a signed-in session for Run and Submit. The Docker socket grants the backend container control of the VPS Docker daemon, so use a dedicated host and do not treat this as a multi-tenant deployment.

1. Obtain a VPS with a public IPv4 address, a domain name you control, and Docker Engine plus the Docker Compose plugin. Point an `A` record such as `api.example.com` at the VPS address. Allow inbound TCP ports 80 and 443 in the VPS firewall.
2. Put this repository's backend files on the VPS. From the repository root, copy `backend.env.example` to `.env` and edit `.env`:

```bash
cp backend.env.example .env
openssl rand -hex 32
```

Set `CODEARENA_DOMAIN` to the DNS name, paste the generated random value into `CODEARENA_SESSION_SECRET`, and set `CODEARENA_RUNFILES_DIR` to an absolute path on the VPS. Keep `.env` private; it is ignored by Git. Never put Judge0 credentials in Flutter or the APK.

3. Configure `JUDGE0_BASE_URL` and any provider credential fields in `.env` using a real Judge0-compatible service. Without that provider, Submit will continue to return a configuration error; the public Vercel response is not a Judge0 provider.
4. On the VPS, build the existing isolated runner image and start the HTTPS stack:

```bash
docker build -f Dockerfile.runner -t madlab-runner:latest .
docker compose --env-file .env -f compose.backend.yaml up --build -d
```

Caddy obtains and renews the HTTPS certificate when the DNS record resolves to the VPS and ports 80/443 are reachable. The Compose stack uses one app instance and a persistent Docker volume for account/session data. The runner source directory is bind-mounted at the same absolute path in the Node container and on the VPS so Docker can mount each run's source into its sandbox.

5. Check `https://api.example.com/` loads the site. `curl -i https://api.example.com/api/auth/me` should return HTTP 401 when no session cookie is supplied; that is the expected unauthenticated response. Register/sign in through the app before using Run or Submit. Test Run first. Submit also requires the Judge0 configuration from step 3.
6. Build a new release APK with the deployed HTTPS origin and reinstall it:

```bash
cd flutter_app
flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com
```

Replace the example host with the domain you configured. The output remains `build/app/outputs/flutter-apk/app-release.apk` relative to `flutter_app/`. The Vercel static deployment can remain online, but its relative API requests still point to Vercel; use the VPS-hosted site or keep using the native APK configured for the VPS backend.

The deployment stack was built and its backend container smoke-tested locally, but it has not been installed on a VPS, given a real domain, or tested with a live Judge0 provider. Hosting, DNS, TLS reachability, Judge0 service access/credentials, and VPS costs must be supplied by the deployment owner.

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

The backend listens on `0.0.0.0` and uses the `PORT` environment variable (default `8000`). The Android debug manifest allows cleartext traffic for local testing only. For a physical phone on the same network, run `node server.js` on the development computer and build/run with its LAN address, for example `flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000`. Allow the port through the host firewall and keep the phone and computer on the same network. Replace the example address with the actual address on your network.

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