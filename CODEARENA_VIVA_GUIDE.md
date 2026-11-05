# CodeArena Project and Viva Guide

## Read This First

This guide describes the repository as it exists on `feature/codearena-android-app`. It includes two clients: the original browser website and an additional native Flutter Android app. The original modular website files are still present. A separate self-hosted backend deployment stack was added, and the APK was built and verified.

The most important distinction for your presentation is:

- **Run** sends a complete program to the Node server, which starts a real Docker runner and streams its output.
- **Submit** sends source, test input, and expected output to the Node server, which calls a configured Judge0-compatible service and compares the result.
- **The website Terminal page is not a real Linux shell.** Its filesystem and ordinary commands are simulated in JavaScript. Only supported source-file commands call the real Docker runner.
- **The browser leaderboard/profile statistics are sample or fabricated data.** There is no live leaderboard API or central progress database.
- **The problem metadata checks do not prove all 100 problems are judge-ready.** The README itself warns that some statements, input formats, tests, and expected results are not independently verified.
- **The temporary Codespaces backend is not a permanent deployment.** It may stop when the Codespace sleeps or is stopped. Its public port requires login before code execution. Judge0 was not configured, so Submit is unavailable there.

The repository does not document the original project motivation or a formal user study. It is reasonable to describe the purpose as giving learners one place to browse coding exercises, edit code, run programs, and practice debugging, but do not claim a measured educational outcome.

# A–J: First Viva Summary

## A. Complete Project Overview

CodeArena is a coding-practice platform with a browser interface and a separate native Flutter Android app. The browser lets users browse a bundled problem list, edit starter code, run programs using a Docker-backed service, and submit test cases through Judge0 when configured. It also contains a debugging arena, a compiler-style editor, and a simulated terminal.

The Android app is not a WebView. It is built with Flutter widgets and loads bundled JSON problem data. It has native screens for Home, Problems, Editor, and Debugging, plus Profile and Leaderboard routes. Its network-dependent functions call the same Node API.

**Problem it addresses:** learners need practice material, an editor, execution, and feedback. The project combines these into one interface. It does not currently prove that every supplied exercise has correct tests or that the sample ranking/progress information is real.

**Intended users:** people practicing programming, especially students and beginner/intermediate programmers. That audience is inferred from the features; the repository does not state a formal target-user study.

**What makes it different from a static coding tutorial:** it can start real isolated program runs and, with Judge0 configured, evaluate submitted output against expected output. However, the Terminal shell utilities, browser ranking/progress examples, and some statistics are simulations or hard-coded examples.

## B. Technology Stack

| Technology | What it does here | Where it appears |
|---|---|---|
| HTML | Defines the browser page structure and controls. | `index.html`; old preserved `codearena_final.html` |
| CSS | Styles browser pages, editor, tables, terminal, and responsive layouts. | `css/style.css` |
| Plain JavaScript | Renders pages, filters local arrays, manipulates the DOM, calls APIs, and simulates shell utilities. | `js/app.js`, `js/questions.js` |
| Node.js built-in modules | HTTP server, files, crypto, OS temp folders, and child processes; no Express framework or root npm package is present. | `server.js` |
| Docker | Runs untrusted interactive source in a restricted container. | `server.js`, `Dockerfile.runner`, `runner.sh` |
| Judge0-compatible API | Compiles/runs each Submit test case externally when configured. It is not bundled and has no configured live URL in the sample environment. | `server.js` |
| Flutter/Dart | Builds the native Android client and its screens/services. | `flutter_app/` |
| Dio | Sends JSON API requests from Flutter. | `flutter_app/lib/services/api_client.dart` and service classes |
| Flutter Secure Storage | Stores the mobile session cookie and local accepted-ID sets using platform-secure storage. | `api_client.dart`, `progress_store.dart` |
| GitHub Actions | Optional manual workflow to analyze, test, build, and upload an APK. | `.github/workflows/build-apk.yml` |
| Caddy + Docker Compose | Optional single-VPS deployment with HTTPS reverse proxy. | `Caddyfile`, `compose.backend.yaml`, `Dockerfile.backend` |

There is **no Bootstrap, React, Vue, Express, SQL database, Firebase, or MongoDB dependency** in the project files. CSS is hand-written. Node HTTP routing is implemented directly.

## C. Architecture

```text
Browser user
  -> index.html + css/style.css + js/app.js
  -> same-origin Node API in server.js
      -> Run: Docker CLI -> madlab-runner container -> stdout/stderr/SSE
      -> Submit: Judge0-compatible HTTP API -> async status polling
      -> Auth: .data/auth.json file and session cookie
  <- response/output/verdict

Android user
  -> native Flutter Material screens
  -> ProblemRepository reads bundled JSON assets
  -> Dio ApiClient + secure cookie interceptor
  -> same Node API for Auth, Run, and Submit
  <- stream/result; local accepted IDs saved on device
```

This is a **client-server system**: a client displays the interface and a Node process handles API requests. The browser and API normally use the same origin. The Android app is a separate native client. The Node service is a small monolithic backend: its routes, authentication, Judge0 client, and interactive-run management are in one `server.js` file. Calling it REST-like is reasonable because it uses HTTP methods and JSON routes, but it is not a model-view-controller (MVC) framework. There is no database layer.

## D. Complete Working Flow

1. **Open website.** `server.js` listens on `PORT` (default 8000), serves `/` as `index.html`, and serves the CSS and JavaScript files. The browser renders the static HTML and runs `js/questions.js` then `js/app.js`.
2. **Initialize browser.** `DOMContentLoaded` renders the problem/debugging tables, checks `/api/auth/me`, updates navigation/profile display, and animates hard-coded homepage counters.
3. **Register/login.** `handleRegister` or `handleLogin` in `js/app.js` sends JSON to `/api/auth/register` or `/api/auth/login`. `handleAuth` in `server.js` validates fields, hashes the password, creates a random token, writes account/session data to `.data/auth.json`, and sends an HTTP-only cookie.
4. **Select problem.** `renderProblems`, `setDiff`, and `filterProblems` filter the in-memory `PROBLEMS` array from `js/questions.js`. `openProblem` builds the detail panel and copies a language starter into the web `<textarea>`.
5. **Write code/select language.** The website uses a plain textarea, a Tab handler, and generated line numbers. `changeLang` replaces the editor with that language's starter template; it does not preserve each problem draft when you switch languages. Flutter uses a native monospace TextField, basic indentation, and per-language drafts.
6. **Run.** Website `runCode` calls `startInteractiveRun`, which POSTs `{sourceCode, language}` to `/api/run`. Flutter `InteractiveRunService.start` does the same. The server validates code/language/session capacity, writes a temporary source file, and starts a Docker container. Both clients read streamed status/stdout/stderr events; they can send stdin and request Stop.
7. **Submit.** Website `submitCode` maps problem test records into `{stdin, expected, unordered?}` and calls `/api/judge`. Flutter `JudgeService.submit` sends equivalent data. The server validates input and provider configuration, creates an execution job in memory, then processes each test case using Judge0.
8. **Run a Judge0 job.** `executeTest` Base64-encodes source and stdin, POSTs to `/submissions/?base64_encoded=true&wait=false`, takes the returned token, and polls `/submissions/{token}`. Pending status is polled until completion or timeout.
9. **Compare result.** `classify` maps Judge0 status IDs. For an accepted provider run, `outputsEqual` compares actual stdout to the expected string (or JSON structures). The server creates Accepted/Wrong Answer/error details and returns job state/results.
10. **Display.** `renderJudgeResult` in the website or `_JudgeResultPanel` in Flutter shows verdict, case, expected/actual, errors, time, and memory where supplied. Browser submission history is only in JavaScript memory. Flutter accepted problem/debug IDs are local to the device.
11. **Score/status.** There is no general scoring/ranking service. Debugging records have static `score` fields; the browser leaderboard is a hard-coded list. Browser profile formulas and heatmap are not real submission statistics.

## E. Project Structure Table

| File/folder | Purpose and important contents | Used by / input and output |
|---|---|---|
| `index.html` | Modular browser page: Home, Problems, Debugging, Solve, Compiler, Terminal, Leaderboard, Profile, login/register modals. | Loads `css/style.css`, then `js/questions.js` and `js/app.js`; buttons call global JS functions. |
| `codearena_final.html` | Preserved earlier single-file version. | Not the modular page served at `/`; it is still statically accessible as a file. |
| `css/style.css` | Hand-written dark responsive theme, tables, editor, terminal, modal, mobile breakpoint. | Loaded by `index.html`; no CSS framework. |
| `js/questions.js` | `P(...)` factory, 100 `PROBLEMS`, sample `LB`, debug seed/questions/counts, CommonJS exports. | Browser globals for `app.js`; Node tests require its exports. |
| `js/app.js` | Browser navigation, rendering, filtering, text editing, API calls, shell simulation, auth form handlers. | Receives click/input/keyboard events; updates DOM and calls `/api/*`. |
| `server.js` | Node HTTP static server and API, JSON auth file, cookie handling, Docker run lifecycle, Judge0 integration, output compare. | Receives HTTP requests; serves files/JSON/SSE; writes `.data/auth.json`; contacts Docker/Judge0. |
| `.env.example` | Local configuration names and placeholder values. | Copy to ignored `.env`; do not use placeholder Judge0 host. |
| `.data/auth.json` | Runtime auth store created by server; contains `users` and `sessions`. | Ignored runtime state, not committed schema-managed database. |
| `Dockerfile.runner` | Builds the actual runner image with Python 3, gcc/g++, Node.js, Java JDK, and coreutils. | Used by Docker `madlab-runner:latest`. |
| `runner.sh` | Selects execution mode and invokes Python, C, C++, Node, or Java inside runner. | Docker entrypoint; input via stdin and output via stdout/stderr. |
| `tests/validate_problem_bank.js` | Checks 100 problem IDs and test metadata shape/placeholders. | Does not prove every expected answer is correct. |
| `tests/validate_debugging_questions.js` | Checks 100 debug records, fields, tests/hints, and difficulty counts. | Metadata check, not algorithm correctness. |
| `tests/validate_judge_proxy.js` | Tests output normalization, JSON comparison, fence stripping, and status classification. | Imports pure helpers from `server.js`. |
| `tests/validate_judge_integration.js` | Runs a mock Judge0 HTTP provider and tests async jobs, auth headers, errors, timeouts, retry, idempotency, and validation. | Does not test an actual public Judge0 account. |
| `tests/validate_interactive_runner.js` | Docker tests interactive stdin/stdout, Stop, compiler error, runtime error for Python and C. | Requires Docker daemon and `madlab-runner:latest`; not all five languages are tested here. |
| `flutter_app/pubspec.yaml` / `pubspec.lock` | Flutter package metadata and pinned dependencies: Flutter, Dio, secure storage, Flutter test/lints. | Flutter tools resolve and build the Android app. |
| `flutter_app/lib/main.dart` | Creates services/controllers and Material 3 theme, starts `CodeArenaApp`. | App root passed into `AppShell`. |
| `flutter_app/lib/config/api_config.dart` | Reads `API_BASE_URL` compile-time define and validates URL/HTTPS in release. | Used by API client and UI warnings. |
| `flutter_app/lib/screens/` | Native Home, Problems, Details, Debugging, Editor, Auth, Profile, Leaderboard screens. | Widgets receive repositories/services/callbacks. |
| `flutter_app/lib/models/` | `Problem`, examples/tests, `DebuggingQuestion`, `RunEvent`, `InteractiveRunSession`. | Convert JSON/assets/events into typed Dart objects. |
| `flutter_app/lib/services/` | Problem asset repository, API client, auth, judge polling, SSE Run, local progress. | Separates file/network/storage behavior from screens. |
| `flutter_app/lib/state/auth_controller.dart` | `ChangeNotifier` user/loading/error state. | Screens observe it and call AuthService. |
| `flutter_app/lib/widgets/arena_widgets.dart` | Shared difficulty badges, section headings, notices, loading pane. | Reused by Flutter screens. |
| `flutter_app/assets/data/` | Generated 100 problem and 100 debug question JSON snapshots. | Loaded with Flutter `rootBundle`; generated from website JS data. |
| `flutter_app/tool/sync_question_assets.js` | Requires `js/questions.js`, exports its arrays to JSON. | Run with Node after changing source data. |
| `flutter_app/android/` | Native Android Gradle project, MainActivity, manifest, label, icon, INTERNET permission, wrapper. | Flutter Gradle build creates APK. |
| `flutter_app/test/` | Repository data test and initial dashboard widget test. | `flutter test`; no live API integration tests. |
| `.github/workflows/build-apk.yml` | Manual GitHub Action: Java 17, Flutter stable, pub get/analyze/test/build, artifact upload. | Uses repo variable `API_BASE_URL` (not a Judge0 secret). |
| `Dockerfile.backend`, `compose.backend.yaml`, `Caddyfile` | Optional Node backend + Docker CLI + Caddy HTTPS reverse-proxy deployment. | Designed for a single Docker-capable VPS, not Vercel functions. |
| `backend.env.example` | VPS environment template for domain/session secret/runner/Judge0. | Copy to private `.env`; replace all sample values. |
| `ANDROID_BUILD_GUIDE.md` | Android architecture, local build, backend, CI, install, VPS guidance. | Human-readable deployment instructions. |
| `.gitignore` and Flutter/Android `.gitignore` files | Ignore local `.env`, `.data`, caches/build/signing data; Android wrapper files are allowed through. | Protect secrets/generated outputs from Git. |
| `.vscode/tasks.json` | VS Code task to run `node server.js`. | Starts local website at default port 8000. |

### Flutter file-by-file reference

| File | Purpose and relationship |
|---|---|
| `flutter_app/lib/screens/home_screen.dart` | Dashboard, counts bundled problems, links to app sections, shows API-not-configured notice. |
| `flutter_app/lib/screens/problems_screen.dart` | Loads `ProblemRepository`, filters title/tags/difficulty, opens problem details. |
| `flutter_app/lib/screens/problem_detail_screen.dart` | Shows description/examples/constraints and opens `EditorScreen` with that problem. |
| `flutter_app/lib/screens/debugging_screen.dart` | Filters bundled debug questions; detail view shows behavior/tests and opens editor. |
| `flutter_app/lib/screens/editor_screen.dart` | Native editor, language drafts, auto-indent, Run/SSE/stdin/Stop, Submit/verdict display. |
| `flutter_app/lib/screens/auth_screen.dart` | Login/register forms; calls `AuthController`, displays errors/loading. |
| `flutter_app/lib/screens/profile_screen.dart` | Shows authenticated user, local accepted problem/debug counts, sign-in/sign-out; explicitly says progress is not server-synced. |
| `flutter_app/lib/screens/leaderboard_screen.dart` | Honest unavailable state; does not display browser sample leaderboard as real. |
| `flutter_app/lib/models/problem.dart` | Defines problem, example, test-case fields and JSON converters. |
| `flutter_app/lib/models/debugging_question.dart` | Defines debugging question/test fields and JSON converters. |
| `flutter_app/lib/models/run_event.dart` | Holds parsed SSE event name/data and run ID/event stream. |
| `flutter_app/lib/services/api_client.dart` | Dio base URL/timeouts, API errors, secure session-cookie interceptor. |
| `flutter_app/lib/services/auth_service.dart` | Calls register/login/logout/me and maps backend user JSON. |
| `flutter_app/lib/services/judge_service.dart` | POSTs test cases, polls execution ID, returns final verdict JSON. |
| `flutter_app/lib/services/interactive_run_service.dart` | Starts Run, parses SSE lines, posts stdin, requests Stop. |
| `flutter_app/lib/services/problem_repository.dart` | Reads bundled JSON assets with `rootBundle` and parses models. |
| `flutter_app/lib/services/progress_store.dart` | Reads/writes accepted IDs in Flutter Secure Storage, locally only. |
| `flutter_app/lib/state/auth_controller.dart` | Observable user/loading/error state used by screens. |
| `flutter_app/lib/widgets/arena_widgets.dart` | Shared difficulty badge, API notice, section heading, and loading components. |
| `flutter_app/android/app/src/main/AndroidManifest.xml` | App label/icon, launcher activity, and Internet permission. |
| `flutter_app/android/app/src/main/kotlin/com/codearena/codearena/MainActivity.kt` | Minimal `FlutterActivity` native entrypoint; Flutter renders the UI. |
| `flutter_app/android/app/build.gradle.kts` | Android application ID, SDK/Java versions, release build signed with debug key for testing. |
| `flutter_app/android/settings.gradle.kts` | Resolves Flutter, Android Gradle, and Kotlin Gradle plugins. |
| `flutter_app/android/gradle.properties` | AndroidX and memory-limited Gradle settings. |
| `flutter_app/android/gradle/wrapper/*`, `gradlew*` | Pins/provides the Gradle wrapper needed to reproduce Android builds. |
| `flutter_app/android/app/src/main/res/drawable/ic_codearena.xml` and `mipmap-*` | Native vector and raster launcher-icon resources. |
| `flutter_app/android/app/src/debug/AndroidManifest.xml` | Debug-only cleartext allowance for local HTTP testing; release should use HTTPS. |
| `flutter_app/test/widget_test.dart` | Checks dashboard branding/navigation control renders. |
| `flutter_app/test/problem_repository_test.dart` | Checks 100+100 bundled data counts, boundary IDs/titles, starter languages, and nonempty tests. |
| `flutter_app/.metadata`, `analysis_options.yaml`, `.gitignore`, `README.md` | Flutter project metadata, lints, ignored build/local files, and scaffold notes. |
| `flutter_app/tool/sync_question_assets.js` | Generates Flutter data snapshots from the website's `js/questions.js` arrays. |

## F. Most Important Functions and Variables

### Browser

| Symbol | File | Input → output/purpose |
|---|---|---|
| `PROBLEMS`, `DEBUGGING_QUESTIONS`, `LB` | `js/questions.js` | Static arrays → problem/debug rows, templates, sample leaderboard. |
| `showPage(name)` | `js/app.js` | Page key → toggles `.active`, initializes page renderers. |
| `renderProblems`, `setDiff`, `filterProblems` | `js/app.js` | Current query/filter + problem array → table HTML. |
| `openProblem(id)`, `openDebugProblem(id)` | `js/app.js` | ID → details HTML and starter code in textarea. |
| `changeLang`, `resetCode`, `handleTab`, `updateLineNums` | `js/app.js` | Language/editor keyboard/content → plain textarea formatting. |
| `requestJudgeExecution` | `js/app.js` | Source/language/tests → POST and polling; returns verdict/error object. |
| `submitCode`, `judgeSubmission`, `renderJudgeResult` | `js/app.js` | Editor/test data → API result and display; browser history is in memory. |
| `startInteractiveRun`, `postInteractiveInput`, `stopInteractiveRun` | `js/app.js` | Code/language/input → `/api/run` and SSE/output/stop calls. |
| `getStoredProgress`, `renderDashboard` | `js/app.js` | LocalStorage arrays/user → display counts; some formulas are synthetic. |
| `renderLB`, `renderHeatmap` | `js/app.js` | Static `LB` and random values → rows/random heatmap. |
| `CLANG_CFG` | `js/app.js` | Per-language filename, demo code, snippets → compiler page. |
| `VFS`, `getNode`, `resolvePath`, `execTerm`, `captureTerm` | `js/app.js` | Command/path → simulated directory/object operations and rendered output. |
| `handleRegister`, `handleLogin`, `handleLogout`, `refreshAuthState` | `js/app.js` | Form values/cookie → auth API and local display cache. |

### Backend

| Symbol | File | Input → output/purpose |
|---|---|---|
| `loadLocalEnv`, config constants | `server.js` | `.env` + process env → port/timeouts/provider/runner settings. Exported env wins. |
| `loadAuthState`, `persistAuthState` | `server.js` | `.data/auth.json` ↔ in-memory `AUTH_STATE`. |
| `hashPassword`, `verifyPassword` | `server.js` | Password and stored salt/hash → PBKDF2 hash or timing-safe check. |
| `getCurrentUser`, `handleAuth` | `server.js` | Cookie or auth JSON request → user/session response. |
| `createInteractiveSession` | `server.js` | Source/language → temp source file + restricted Docker process. |
| `streamRunEvent`, `handleRunEvents`, `finishInteractiveSession` | `server.js` | Run state/output → SSE records and cleanup. |
| `handleInteractiveRun` | `server.js` | Run/input/stop/events HTTP request → session operations. |
| `validateJudge0BaseUrl`, `judge0Request`, `judge0Poll` | `server.js` | Provider URL/request → validated HTTP JSON; polls have bounded transient retries. |
| `executeTest`, `runExecutionJob` | `server.js` | Source/test list → Judge0 jobs, per-case results, overall verdict. |
| `classify` | `server.js` | Judge0 status/result → Accepted, Wrong Answer, Compilation Error, Runtime Error, TLE, etc. |
| `normalizeOutput`, `outputsEqual` | `server.js` | Actual/expected strings → normalized structural/text comparison. |
| `handleApi`, HTTP server callback | `server.js` | URL/method/body/cookie → route or static file response. |
| `CODEARENA_REQUIRE_AUTH_FOR_EXECUTION` | `server.js` | Env boolean → optional 401 guard for judge/run; default false locally, true in Compose. |

### Flutter

`CodeArenaApp` wires all services in `main.dart`. `AppShell` owns the four bottom destinations. `ProblemRepository` loads JSON. `AuthController` holds user/loading/error state. `AuthService` handles auth routes. `JudgeService.submit` submits and polls. `InteractiveRunService.start` starts a run and decodes SSE lines. `ApiClient` handles Dio, timeouts, errors, and the cookie interceptor. `ProgressStore` keeps accepted IDs on device.

## G. Code Execution Mechanism

An **online judge** checks a program by giving it input and comparing its output with an expected answer. **Compilation** turns C/C++/Java source into a runnable program; Python/Node execute interpreted source. **Execution** means running it with test input. **Actual output** is what the process prints; **expected output** is the answer stored in test metadata.

### Run path (real Docker execution)

1. Browser `runCode()` or Flutter `_startRun()` takes editor text and language.
2. Client POSTs `{sourceCode, language}` to `/api/run`.
3. `handleInteractiveRun` validates nonempty code, max 128 KiB, one of Python/C/C++/JavaScript/Java, and max 3 active sessions.
4. `createInteractiveSession` writes a file under `os.tmpdir()` (`main.py`, `main.c`, `main.cpp`, `main.js`, or `Main.java`).
5. Node uses `spawn()` with an argument array (not a shell string) to run Docker. The container has no network, read-only root and source mount, user `65534:65534`, dropped capabilities, no-new-privileges, 128 MiB memory, 0.5 CPU, 32 PID limit, bounded `/tmp`, and timeout.
6. `runner.sh` selects Python, gcc, g++, Node, or Java compile/run commands.
7. Node streams stdout/stderr/status/finished events as Server-Sent Events (SSE: a long-lived HTTP response carrying named event messages). Client can POST stdin and request Stop.
8. Temporary source directory is removed after completion. The session map is cleaned after retention.

Example: `print(5 * 2)` with no stdin starts Docker, Python prints `10\n`, the SSE `stdout` event delivers `10`, then a `finished` event says `completed`/exit code 0. **Run does not compare problem expected outputs.** It only shows interactive output.

### Submit path (external Judge0)

1. Client maps each `{i,o,unordered}` problem test to `{stdin,expected,unordered?}`.
2. `/api/judge` validates code size, language ID, 1–100 test records, string input/expected fields, and configured provider URL. Missing Judge0 yields HTTP 503.
3. A job ID is stored in `executionJobs` Map. This is in-memory and disappears if Node restarts.
4. `executeTest` Base64-encodes source/stdin and POSTs to Judge0's `/submissions/?base64_encoded=true&wait=false`, passing optional RapidAPI/Auth headers only from server environment.
5. It polls the provider's submission token until completion or timeout. Safe GET polls retry transient 429/5xx/network errors up to three attempts; submission POST is deliberately not auto-retried to avoid duplicate jobs.
6. `classify` maps Judge0 status IDs. For provider Accepted, CodeArena compares stdout to expected via `outputsEqual`. It ignores object key order, allows a small numeric tolerance, normalizes CRLF/outer whitespace/trailing line spaces, and supports an optional unordered top-level JSON array comparison. Other arrays remain order-sensitive.
7. Per-case and overall results go to client. Output carries verdict, actual/expected, stderr, time and memory when provided.

Input/test formats are raw strings, not problem-specific parsers or hidden harnesses. For example, input `5` and expected `10` works only if submitted code reads stdin and prints `10`. Many stored problem statements use function-style notation while their backend tests are raw stdin strings; this is a known readiness limitation.

### Supported languages

| Language | Interactive Run implementation | Submit implementation |
|---|---|---|
| Python 3 | `python3 -u /workspace/main.py` | Judge0 language ID default 71 |
| C | gcc C11, compile then run | Judge0 ID 50 |
| C++ | g++ C++17, compile then run | Judge0 ID 54 |
| JavaScript | Node.js | Judge0 ID 63 |
| Java | `javac -d /tmp /workspace/Main.java`, then `java -cp /tmp Main` | Judge0 ID 62 |

IDs can be overridden with `JUDGE0_LANGUAGE_IDS`. The interactive test exercises Python and C, not every language. JavaScript/Java/C++ are configured in the runner code but not fully covered by that integration test.

## H. Database and Data Storage

There is **no SQL, NoSQL, ORM, table schema, or database connection**. Data is kept in several unrelated stores:

| Data | Current storage | Persistence |
|---|---|---|
| Problems/debug questions | `js/questions.js`; generated Flutter JSON assets | Source-controlled/static snapshot. |
| Browser username/email display cache | `localStorage` key `codearena-user` | Per browser; not authentication authority. |
| Browser debugging completion IDs | `localStorage` key `codearena-progress` | Per browser; problem completion array is defined but not updated by normal problem submit. |
| Browser submit list | JS arrays `submissions`, `debugSubmissions` | Current page lifetime only. |
| Accounts/password hashes/session rows | `.data/auth.json`, `{users:[], sessions:[]}` | File on server; persistent only if deployment volume persists. Not relational. |
| Judge jobs/idempotency | `executionJobs`, `idempotentExecutions` Maps | Memory only; lost on server restart. |
| Interactive runs/SSE history | `interactiveSessions` Map + temp files | Memory/temp folder; cleaned after run/retention. |
| Flutter accepted problem/debug IDs | Flutter Secure Storage JSON lists | Local device only, not synced to account. |

User registration inserts a user object into the JSON `users` array and a session into `sessions`, then synchronously writes the whole file. Solving a web problem does not create a durable server submission record. Flutter marks an accepted ID locally after an Accepted Submit. Leaderboard entries do not come from user accounts.

A relational diagram is **not applicable**. The closest conceptual relationship is `user.id -> session.userId` in the JSON file, but there are no database foreign-key constraints or queries. The Compose deployment persists the auth file in a Docker volume and is designed for one backend instance. Synchronous whole-file writes, no lock/transaction system, and no backup mechanism make this a small-project store, not a scalable database.

## I. Major Features: What Is and Is Not Implemented

| Feature | Actual implementation/status |
|---|---|
| Problem library | 100 static `PROBLEMS`; title/difficulty/tag filter/search in browser and Flutter. Metadata can be incomplete/not judge-ready. |
| Difficulty | Easy/Medium/Hard for problems; Easy/Moderate/Hard for debugging questions. Filter is client-side. |
| Editor | Browser textarea with tabs, line numbers, reset and no syntax highlighting. Flutter native monospace text field with basic indentation and language-specific drafts. |
| Run | Real Docker runner for Python/C/C++/JavaScript/Java if daemon/image available. Interactive stdin/stdout/stderr/Stop. |
| Submit | Real async Judge0 proxy when configured; not available with placeholder/missing provider. Different from Run. |
| Debugging Arena | 100 static generated records, starter code, descriptions, hints, and generic/possibly mismatched tests. Metadata tested, correctness not audited. |
| Auth | Server register/login/logout/me; PBKDF2 password hashes and HTTP-only session cookie. Optional server execution auth flag. No email verification/password reset. |
| Browser profile | Mixed static HTML plus localStorage/synthetic metrics and random heatmap; not authoritative account statistics. |
| Browser leaderboard | `LB` constant with sample users/scores. Not live. |
| Flutter profile | Real signed-in username/email if backend works; accepted IDs are local; no account progress endpoint. |
| Flutter leaderboard | Explicit “No live rankings available” notice. |
| Compiler page | Native browser editor widgets/snippets/console; Run uses actual Docker backend. “Compiler” is page name; Python/JS do not compile. |
| Terminal | Virtual `VFS`, simulated file and OS commands. `python3 file.py`, `node file.js`, `gcc file.c`, `g++ file.cpp`, and `run file` route VFS code into Docker. Many commands (`ps`, `env`, `df`, etc.) print fixed sample output. Tabs are largely presentation; command state is shared. |
| Interview Arena | Not present in current page structure. |
| SQL Playground | Not present. |
| AI chatbot | Not present. |
| Timer | No actual timed interview/problem countdown found. Docker wall timeout is an execution limit, not a user-facing contest timer. |
| Scores/ranking | Debug points are static record values. No score aggregation/ranking API. |
| Mobile app | Native Flutter app; bundled data and real API service clients. Not a WebView. Login/run need configured reachable API. |

# J. Top 30 Viva Questions

These first 30 are the quick revision set; detailed answers are repeated/expanded in the 50-question bank later.

1. **What is CodeArena?** A practice platform with a browser UI and native Flutter client for browsing coding/debug exercises and running/submitting programs.
2. **What is the frontend built with?** Plain HTML, custom CSS, vanilla JavaScript; Android uses Flutter/Dart.
3. **Is Bootstrap used?** No Bootstrap dependency or stylesheet is present.
4. **What does `server.js` do?** Serves static web files and handles auth, Run, and Judge API routes.
5. **Is Express used?** No; Node's built-in `http` server is used.
6. **Where are the 100 problems?** `js/questions.js`; Flutter JSON is generated from it.
7. **What is Run?** A live Docker-backed program session with streaming output and stdin.
8. **What is Submit?** Test-case judging through the backend and external Judge0-compatible service.
9. **Are Run and Submit identical?** No; Run is interactive, Submit compares supplied test cases.
10. **Where does interactive source execute?** In a Docker container spawned by `server.js`, not the browser.
11. **Where does Submit execute?** Judge0 provider, if configured; CodeArena itself does not compile Judge0 submissions.
12. **Which languages are supported?** Python 3, C, C++, JavaScript, and Java in configuration/runner. Interactive test coverage only exercises Python/C.
13. **How is stdin sent during Run?** `/api/run/{id}/input` forwards text to the container process stdin.
14. **How does Run output reach the UI?** Server-Sent Events: `status`, `stdout`, `stderr`, `finished` events.
15. **How does Stop work?** Client POSTs `/stop`; server asks Docker to stop/kill the named container.
16. **How is expected output compared?** `outputsEqual` normalizes whitespace and compares text or JSON structures.
17. **What does Accepted mean?** Provider execution succeeded and every test output matched, or a Run-only sentinel was used.
18. **Is there a database?** No; auth uses JSON file, jobs are maps, browser/device data is local, exercise data is static.
19. **How are passwords stored?** PBKDF2-SHA512 with random salt and timing-safe verification, not plain text.
20. **How does the browser retain a login?** Server sets an HTTP-only cookie; localStorage separately caches display identity.
21. **What is the Flutter app?** A native client with screens/services, not an embedded website.
22. **Does Flutter load problems from the API?** No; it loads bundled generated JSON assets.
23. **Where is mobile API URL set?** Compile-time `API_BASE_URL` Dart define.
24. **How is mobile session saved?** Cookie value is stored and resent using Flutter Secure Storage and Dio interceptor.
25. **Are user progress and leaderboard shared?** No; accepted IDs are device-local; leaderboard is not live.
26. **What is simulated?** Most terminal shell/file operations, browser leaderboard rows, profile stats/heatmap, and home counters.
27. **Does the project have SQL/chatbot/interview pages?** Not in the current HTML structure/code inventory.
28. **What does the test suite validate?** Data metadata, output helpers, mocked Judge0 flows, and Docker interactive Run behavior.
29. **What is the biggest correctness limitation?** Problem test inputs/expected results are not all independently validated and may not match function-style problem statements.
30. **What is the biggest deployment limitation?** Backend requires a persistent Node process, Docker, persistent file storage, and a live Judge0 provider; Vercel API was observed returning 500.

# Part 1: Project Overview and Speeches

## 30-second version

“CodeArena is a coding-practice platform with a browser website and a native Flutter Android app. Users can browse coding and debugging exercises, edit code, run programs in isolated Docker containers, and submit test cases to a Judge0-compatible service when it is configured. The project also demonstrates authentication, API communication, and result handling. Some statistics and the browser terminal shell are sample/simulated, and the problem bank still needs independent test-data verification.”

## 2-minute version

“CodeArena combines a static web frontend, a Node backend, and a Flutter Android client. On the web, `index.html`, `style.css`, and `app.js` show eight sections: Home, Problems, Debugging, Solve, Compiler, Terminal, Leaderboard, and Profile. Problems and debugging tasks are defined in `questions.js`. The browser filters that data and inserts the selected starter code into a textarea.

Run and Submit are separate. Run sends a complete source file to the Node API. The server writes it to a temporary directory, starts the language-specific process in a restricted Docker container, and streams output through SSE. Submit sends several input/expected-output pairs to the server. The server submits each case to Judge0 asynchronously, polls the submission token, classifies the result, and compares actual output with expected output.

Registration and login use server-side PBKDF2 hashes and a session cookie. There is no SQL database: accounts are JSON-file-backed, execution jobs are in-memory, browser progress is localStorage, and Android accepted IDs are device-local. The Flutter app is native, loads bundled JSON, and calls the same APIs through Dio. The leaderboard and much browser profile data are examples rather than live account data. A real public deployment needs persistent storage, Docker, HTTPS, and Judge0 configuration.”

## 5-minute version

“CodeArena was built as an online coding-practice and evaluation prototype. The current repository contains the original modular browser application and an additional native Android application. It has a Node.js server using built-in modules rather than Express, a Docker-based interactive runner, and a Judge0 integration for batch-style test-case evaluation.

When a user opens the browser app, the Node server serves `index.html`, CSS, and JavaScript. `questions.js` defines 100 coding problems, a sample leaderboard array, and 100 debugging questions. `app.js` renders and filters those arrays, opens details, switches starter code, handles the textarea, and calls the backend. The browser does not fetch the problem list from a database.

When the user clicks Run, `startInteractiveRun()` posts source and language to `/api/run`. The server validates the request, saves a temporary source file, and uses `spawn()` to call Docker. The container has no network, a read-only filesystem and source mount, a non-root identity, dropped Linux capabilities, CPU/memory/PID/file limits, and a runtime timeout. Standard output and errors are forwarded as named SSE events. The user can send stdin or stop the process. This execution is real, but it depends on Docker and the runner image.

Submit follows another route. The client sends source plus each test's stdin and expected string to `/api/judge`. The server validates the request, assigns an execution ID, and submits each case to a Judge0-compatible API with `wait=false`. It polls the returned provider token, maps Judge0 status codes to verdicts, and compares output. The provider URL and credentials must be configured on the backend. The project has no live provider configured in the checked-in sample settings, so Submit is unavailable until configured.

Authentication registers accounts with a salted PBKDF2-SHA512 password hash and uses a random session token in an HTTP-only cookie. Account and session records are stored in `.data/auth.json`, not a database. Jobs and interactive sessions are held in server memory. Browser progress uses localStorage; Android accepted IDs use secure device storage. There is no central submission history, solved-count API, or live leaderboard.

The Flutter app is a separate native project. It uses Material 3, Dio, Flutter Secure Storage, bundled problem JSON, a native editor, API services, and an Android Gradle project. The Android APK was built and tested. The editor supports basic indentation but not syntax highlighting. The GitHub Actions workflow can build and upload an APK.

The main limitations I would disclose in a viva are: the browser terminal simulates many shell commands; leaderboard and profile sample data are not real; not all problem tests are verified or compatible with starter function signatures; the deployment needs persistent single-instance Node plus Docker; Judge0 is external; and the temporary Codespaces API is not production hosting.”

# Part 2: Project Structure and File Relationships

The table in section E lists each important file. For a concise flow map:

```text
index.html + css/style.css
  -> js/questions.js provides static problem/debug arrays
  -> js/app.js renders UI and posts JSON to server.js
  -> server.js routes auth/run/judge
  -> auth: .data/auth.json
  -> Run: temp source file -> Dockerfile.runner + runner.sh -> SSE
  -> Submit: Judge0 HTTP API -> token polling -> compare -> JSON verdict

Flutter screens
  -> ProblemRepository -> bundled assets/data/*.json
  -> Auth/Judge/InteractiveRun services -> ApiClient (Dio + cookie storage)
  -> same server routes
  -> ProgressStore (local secure storage)
```

`codearena_final.html` is a preserved earlier one-file version; the Node root route serves `index.html`, not that legacy file. The root has no `package.json`; backend code depends on Node built-ins. Flutter dependency metadata lives under `flutter_app/`.

# Parts 3–4: Stack and Complete Flows

## Browser opening and navigation

`index.html` contains the DOM sections and inline `onclick`/`oninput` handlers. It loads `questions.js` before `app.js`, so globals such as `PROBLEMS` exist before render functions execute. `DOMContentLoaded` in `app.js` renders tables, calls `/api/auth/me`, and initializes profile/dashboard data. `showPage` toggles page classes and invokes the page renderer.

## Problem selection and editing

`renderProblems` filters by `diffFilter` and title/tag substring. `openProblem` looks up by ID, injects detail/example/constraint HTML, places a language starter in `#code-editor`, fills line numbers, and switches to the solve page. The language dropdown calls `changeLang`, which replaces the textarea with that language's starter. The web textarea is not syntax highlighted. The compiler textarea has snippets, cursor/line number visuals, and in-memory per-language source.

## Auth and persistence

`handleRegister`/`handleLogin` post JSON; server validates required fields, email format, uniqueness, and minimum 8-character password. `hashPassword` creates a random salt and PBKDF2-SHA512 hash. `authResponse` sets `codearena_session` with HttpOnly, SameSite=Lax, Max-Age, and Secure in production. `/api/auth/me` finds the token in `AUTH_STATE.sessions` and returns a sanitized user. `/api/auth/logout` removes the session and expires the cookie.

The “Remember me” checkbox and “Forgot password?” link in browser HTML have no implemented handler. There is no email verification, password reset, roles, or user profile API.

## Run and stdin example

A complete run test can be:

- Source: `print(5 * 2)`
- Language: `python`
- Run behavior: it prints `10` and exits successfully.

For interactive stdin, use `print(int(input()) * 2)` and send `5` at the stdin prompt; output is `10`. Run does not use problem tests or decide Accepted/WA. A function starter with no call/print can run successfully but show no visible output.

## Submit and verdict

A submit test case is a raw input string and expected output string. For the sample above: `stdin: "5"`, `expected: "10"`. The program must read stdin; the backend does not transform function-style examples into a test harness.

# Part 5: Online Judge Concepts in This Project

- **Online judge:** a service that runs a submitted program against test inputs and decides whether its output is acceptable.
- **Compilation:** translating C/C++/Java source into an executable or bytecode. The runner invokes real compilers for these languages.
- **Interpretation/execution:** running source through a runtime such as Python or Node.js.
- **Test case:** one input string plus one expected output string. `PROBLEMS[].tc` uses fields `i` and `o`; the browser maps them to API `stdin` and `expected`.
- **Actual output:** bytes printed by the program; the server captures stdout.
- **Accepted:** the provider successfully executed a test and CodeArena's comparison passes all cases. **Wrong Answer:** the program ran, but its output did not match. **Compilation Error:** Judge0 reports compile failure. **Runtime Error:** it compiled/started but crashed. **Time Limit Exceeded:** Judge0 status 5 or interactive timeout.

For `print(5 * 2)`, ordinary Run needs no stdin: Python executes inside Docker and stdout `10\n` arrives through SSE. For Submit, the program must read the provided test stdin and Judge0 must be configured. CodeArena sends source and input to Judge0, receives Base64 output/status, decodes them, and compares actual `10` with expected `10`.

The runner has meaningful sandbox restrictions: no network, read-only container filesystem and code mount, non-root UID/GID, dropped capabilities, no-new-privileges, memory/CPU/PID/file limits, bounded runtime/output, and a temporary directory removed after the process ends. This is stronger than running user code directly in Node, but it is not a formal proof of isolation. In the VPS Compose deployment the API container mounts the host Docker socket, which is highly privileged; a compromise of that container could control host Docker. Use a dedicated machine, keep Docker/OS patched, and do not treat that deployment as multi-tenant infrastructure.

# Part 6: Language Selection and Execution

The browser problem editor's `<select id="lang-select">` calls `changeLang`; the standalone compiler uses `CLANG_CFG` and `switchCLang`. Flutter uses a dropdown backed by `_languages`. The client sends language strings `python`, `c`, `cpp`, `javascript`, or `java`.

| Language | Interactive runner (`runner.sh`) | Submit default Judge0 ID | Input/output/errors |
|---|---|---:|---|
| Python 3 | `python3 -u /workspace/main.py` | 71 | `input()`/stdin; stdout/stderr streamed in Run or returned by Judge0. |
| C | `gcc -std=c11`, then run `/tmp/program` | 50 | `scanf`/stdin, `printf`; compiler diagnostics and runtime stderr are captured. |
| C++ | `g++ -std=c++17`, then run `/tmp/program` | 54 | `cin`/stdin, `cout`; compiler/runtime errors are captured. |
| JavaScript | Node.js on `/workspace/main.js` | 63 | Node stdin/stdout/stderr. |
| Java | `javac -d /tmp /workspace/Main.java`, then `java -cp /tmp Main` | 62 | Java stdin/stdout/stderr. |

The five are configured in both server language maps and the runner script. Tests exercise Python and C interactively, plus mock Judge0 language IDs for Python and C; they do not prove all five languages against a live provider. A language appearing in a menu proves only that UI configuration exists; the relevant server/runner/provider must also be available.

# Part 7: Database and CRUD Reality

There is no database engine, schema, SQL query, migration, or database connection. Do not draw database tables as if they exist. Account data is a JSON file with two arrays:

```text
.data/auth.json
  users: { id, username, email, passwordHash, joinedAt }[]
  sessions: { token, userId, expiresAt }[]
```

Registration adds a user and session; login finds a username/email and verifies the password hash, replaces that user's old sessions, then writes the file. Logout removes a session. `/api/auth/me` reads the cookie token and looks up its session and user. This resembles CRUD, but is implemented by loading/mutating/writing a whole JSON document, not database queries. There are no foreign-key constraints, indexes, transactions, audit history, or concurrent-write protection.

Solving a problem does not create a durable server row. Browser debug progress is a localStorage array. Browser normal-problem submissions and debug submission history are page-memory arrays. Flutter accepted problem/debug IDs are lists in device secure storage. Leaderboard data is a JavaScript constant. Judge and Run job state is in Node Maps and disappears on restart. Therefore there are no real “appear on leaderboard” or account-wide score writes.

# Part 8: Frontend and Native Screens

## Browser (`index.html`, `css/style.css`, `js/app.js`)

- **Home:** hero buttons switch sections; the three counters animate toward hard-coded values 100, 24,600, and 380,000. They are not queried from users/submissions.
- **Problems:** search and Easy/Medium/Hard filter the bundled problem array. Clicking a row calls `openProblem(id)`.
- **Debugging Arena:** search and difficulty filter generated debugging entries; details include description, buggy code, hints, and tests. Accepted IDs are stored locally.
- **Solve/editor:** a 40% problem panel plus plain textarea, language select, line numbers, Run, Submit, output tabs, and restricted clipboard toggle. The toggle is client-side friction, not a secure exam/anti-cheating control.
- **Compiler:** a separate textarea editor with five language tabs, snippets, font-size/theme controls, stdin box, and the same real interactive Run backend. It is not a standalone compiler bundled in the browser.
- **Terminal:** has a sidebar backed by the `VFS` JavaScript object, command prompt, tabs, help, and simulated shell utilities. Source execution commands call the Docker API using code read from VFS.
- **Leaderboard:** `renderLB()` renders constant `LB` rows. No network request or ranking calculation.
- **Profile:** HTML starts with sample identity/stats; `renderDashboard()` substitutes local values and formula-derived numbers. `renderHeatmap()` uses `Math.random()`, so activity is decorative, not submission history.
- **Login/register modals:** submit to backend routes. Remember-me and forgot-password controls are not wired.
- **Interview Arena, SQL Playground, AI chatbot:** absent from the current `index.html` pages and current JS implementation. Not implemented.

HTML owns page elements and inline event attributes, CSS owns appearance/responsive rules, and JS finds element IDs, reads values, builds table/detail markup, calls APIs, and updates the DOM. There is one `@media(max-width:768px)` rule that changes several layouts; this is responsive styling, not a separate mobile frontend framework.

## Android (`flutter_app/`)

The app is native Flutter/Dart, not a WebView. `main.dart` constructs service instances and a Material 3 theme. `AppShell` supplies bottom tabs Home/Problems/Editor/Debug; Profile and Leaderboard open as routes. Home loads source-backed problem assets and displays actual bundled counts. Problem library search/filter uses title and tags; details show descriptions/examples/constraints and a warning that test data is not certified. Debug screens show provided behavior/hints/tests. Editor uses a monospace TextField with basic automatic indentation, per-language drafts, output, stdin, Run, Stop, and Submit. It has no syntax highlighting.

Profile shows the current backend account if signed in and accepted IDs stored locally. Leaderboard explicitly says no live ranking is available. Auth, Run, and Submit show an API configuration/error state rather than fake success. Progress is device-only and is not synced to the server.

# Part 9: JavaScript Concepts and Important Functions

`js/app.js` uses global state variables for the active problem, current filters, current run, browser submission arrays, current language, terminal cwd/history/tabs, and `VFS`. Functions are declared globally because HTML inline handlers call them. `DOMContentLoaded` initializes views and attaches scroll/password listeners.

- `renderProblems`/`renderDebuggingProblems`: filter arrays with `Array.filter`, then build rows using template strings and `innerHTML`.
- `openProblem`/`openDebugProblem`: find a record by ID, inject details, set editor text, and show Solve.
- `handleTab`/`compTab`: intercept Tab and insert four spaces into textarea.
- `startInteractiveRun`: POST, obtains run ID, creates browser `EventSource`, handles typed SSE events.
- `requestJudgeExecution`: POSTs with a random `Idempotency-Key`, polls every 500 ms, and converts network/API exceptions to an Execution Error object.
- `submitCode`: creates test list, changes button/loading state, calls backend, stores current-page/local debug progress, renders result.
- `normalizeOutput`/`outputsEqual` are backend JS, not browser functions; they perform comparison.
- `execTerm`: a large `switch` implements virtual command behavior. `captureTerm` supports only a subset for simple pipes.
- `handleRegister`/`handleLogin`/`handleLogout`: form validation + fetch + cookie-based API calls + local identity cache.
- `escapeHTML` escapes five HTML-sensitive characters in some dynamic outputs. Not every static-data HTML interpolation uses it.
- `setTimeout`/`setInterval`: toast clearing, loading bar reset, fake homepage number animation, job polling.

JavaScript arrays/objects are in-memory data structures; `localStorage` is per-browser text storage; `fetch` makes HTTP requests; template strings build HTML; DOM means the browser's in-memory representation of the page.

# Part 10: Backend API Table

| Endpoint | Method | Purpose/input | Processing/output |
|---|---|---|---|
| `/api/auth/register` | POST | `{username,email,password}` | Validates; creates PBKDF2 hash and user/session; 201 `{user}` plus cookie, or 400/409. |
| `/api/auth/login` | POST | `{username/email,password}` | Verifies account; rotates sessions; returns user + cookie, or 401. |
| `/api/auth/logout` | POST | Cookie | Removes current session, expires cookie, `{ok:true}`. |
| `/api/auth/me` | GET | Cookie | 200 authenticated user or 401 `{authenticated:false,user:null}`. |
| `/api/run` | POST | `{sourceCode,language}` | Creates Docker session; 202 `{runId,state}`; validation/capacity/Docker errors. |
| `/api/run/{id}/events` | GET | Run ID | `text/event-stream`: status/stdout/stderr/finished events. |
| `/api/run/{id}/input` | POST | `{data}` | Forwards stdin to live process; 202 or 400/409/413. |
| `/api/run/{id}/stop` | POST | Run ID | Requests stop; 202. |
| `/api/judge` | POST | `{sourceCode,language,tests:[{stdin,expected,unordered?}]}` | Validates, creates async job; 202 `{executionId,state}` or 400/503. |
| `/api/judge?id={id}` | GET | Execution ID | Returns queued/running/completed/failed state and final result, or 404 expired/missing job. |

There are no PUT, PATCH, or DELETE routes. `/api/run` and `/api/judge` are only gated by sign-in if `CODEARENA_REQUIRE_AUTH_FOR_EXECUTION=true`; the local default is false and Compose sets true. Auth endpoints remain available for registration/login.

## Complete frontend-to-provider-to-frontend Submit example

`submitCode()` in browser maps `PROBLEMS[n].tc` to stdin/expected strings and invokes `judgeSubmission()` -> `requestJudgeExecution()` -> `POST /api/judge`. `handleApi()` validates and creates a map-backed job. `runExecutionJob()` calls `executeTest()` per test; that calls Judge0. Judge0 response is Base64-decoded, classified, compared with expected output, then saved as job result. Browser polling `GET /api/judge?id=...` receives final JSON; `renderJudgeResult()` displays verdict and test info. Flutter uses `JudgeService.submit` for the same endpoint contract.

# Part 11: Authentication and Security Review

## What exists

Registration requires username/email/password, checks basic email shape, uniqueness, and server-side minimum length 8. `hashPassword` uses random 16-byte salt encoded as hex and PBKDF2 with 120,000 SHA-512 iterations and 64-byte output. `verifyPassword` uses `crypto.timingSafeEqual`. The session identifier has 32 random bytes (64 hex characters); it is an opaque bearer token, meaning possession of the cookie identifies the session. Cookie is HttpOnly, SameSite=Lax, Secure in production, and has configurable expiry. Flutter stores cookie value with Flutter Secure Storage and never stores password.

## Issues and improvements

| Severity | Problem → risk → improvement |
|---|---|
| HIGH | VPS API container mounts `/var/run/docker.sock`; Docker socket access is effectively host control. Keep the host dedicated and trusted; consider a separately isolated runner host/remote daemon or a narrower execution service. |
| HIGH | Public registration has no rate-limit, CAPTCHA, email verification, or abuse controls; an attacker can create accounts and consume PBKDF2/disk. Add throttling, verification, quotas, monitoring, and account lifecycle controls. |
| HIGH | Browser leaderboard/profile counters are fake but labels look factual, which misleads users. Replace them with real authorized aggregate APIs or label as demo data. |
| HIGH | Problem tests are raw strings and not consistently connected to described function signatures; a plausible solution can receive unusable input/expected values. Standardize input format/harness, independently verify every expected output, and do not advertise all as judge-ready. |
| MEDIUM | `AUTH_SESSION_SECRET` is read into a constant but not referenced elsewhere in `server.js`; session tokens are random and stored directly in JSON, not signed HMAC cookies despite some README wording. Either remove the unused secret and document opaque server-side sessions accurately, or implement an intentional signed-token design. |
| MEDIUM | Auth storage is synchronous whole-file JSON with no atomic write/locking/backup; concurrent writes or disk loss can corrupt/lose data. Use a database or atomic writes/backups before real accounts. |
| MEDIUM | Job/idempotency/run state is only in process Maps. Restart loses active jobs and multiple replicas cannot poll each other's job. Keep one instance (Compose does) or move state to shared storage. |
| MEDIUM | Browser `innerHTML` interpolates problem/debug data without escaping every field. Current records are bundled source data, but future remotely editable data can create XSS. Escape untrusted fields or use `textContent`/DOM node construction. |
| MEDIUM | No explicit CSRF token or request Origin validation. SameSite=Lax helps, and same-origin use is expected, but add CSRF/Origin controls before broader web account deployment. |
| MEDIUM | `parseCookies` uses `decodeURIComponent`; malformed cookie encodings can throw, and request handler has no top-level error wrapper. Validate/catch bad cookie values and catch async route failures. |
| MEDIUM | Codespaces backend uses public forwarding and an ephemeral process. Do not use for real accounts or a production showcase with sensitive passwords. Use a stable HTTPS host and rotate the session secret. |
| LOW | “Remember me” and “Forgot password?” are visible but nonfunctional. Remove or implement them. |
| LOW | Browser terminal file operations and ordinary system output are simulations. Make this prominent in the UI or use an actual managed terminal service. |
| LOW | The Flutter editor has no syntax highlighting; mobile editor function is usable but basic. Add a maintained editor component if needed. |
| LOW | Root `README.md` still contains an older note that Flutter was unavailable/scaffold-only. It is stale relative to current built Flutter app; use `ANDROID_BUILD_GUIDE.md` as current Android instructions and update README when allowed. |

There is no SQL database, so SQL injection into a project database is not applicable. CORS headers are not configured; same-origin web requests do not need CORS, and native Dio is not subject to browser CORS. Docker command invocation uses `spawn(binary,args)` rather than concatenating user source into a shell command; source is mounted as a file, and the runner container has no network. The Docker socket on the backend host remains the largest infrastructure privilege.

# Part 12: Feature-by-Feature Status

1. **Coding problems:** implemented as bundled static data, 100 IDs, filters/search/details. Not remote database-managed.
2. **Difficulty:** local string filter; problem values Easy/Medium/Hard, debug values Easy/Moderate/Hard.
3. **Editor:** plain textarea / Flutter TextField; basic tabs/indentation/line numbers. No syntax coloring, language server, or code completion.
4. **Languages:** five are in the client and runner mapping; actual provider availability depends on Judge0 IDs/config. Docker tests cover only Python/C.
5. **Compiler/execution:** real Docker compilers/interpreters for Run. Judge0 for Submit. No compilation occurs in browser.
6. **Test cases:** data exists but has not been exhaustively checked; tests are supplied verbatim as stdin.
7. **Submission:** actual async Judge0 proxy when configured; absent provider makes it unavailable.
8. **Score:** debugging record has static score; no total score engine or live leaderboard scoring.
9. **Leaderboard:** browser constant only; native screen clearly says no live rankings.
10. **Profile:** auth identity is real if backend works; dashboard statistics are partly sample/formula-driven; Flutter progress is local.
11. **Dashboard:** real navigation/count of bundled data; browser counters are hardcoded.
12. **Interview Arena:** absent.
13. **Timer:** no user-facing timed challenge; runtime timeout exists on server.
14. **Debugging questions:** 100 metadata-rich bundled entries; validation does not prove each exercise's code/tests are coherent.
15. **SQL Playground:** absent (no SQL page/engine/database).
16. **AI chatbot:** absent.
17. **Shell terminal:** hybrid; virtual FS/commands are simulated, file execution goes to Docker.

# Part 13: Algorithms and Logic

| Logic | Location | Simple explanation and complexity |
|---|---|---|
| Problem filter/search | `renderProblems`, `renderDebuggingProblems` | Scans all records and checks title/tags; O(n × string/tag checks), O(n) output list. n is 100. |
| Virtual path normalization | `resolvePath`, `normPath` | Processes path segments, pushing/popping `..`; O(number of path segments). |
| Virtual filesystem lookup | `getNode` | Walks object children by each path segment; O(depth). |
| Output normalization | `normalizeOutput` | Converts CRLF, trims outer whitespace and trailing horizontal line spaces; O(output length). |
| JSON output compare | `outputsEqual` | Recursively compares numbers/arrays/objects; object key order is sorted. Usually O(n log n) due to key sorting, plus structure walk. |
| Unordered top-level array compare | `outputsEqual(...unorderedTopLevelArray:true)` | Finds/removes a match for each expected item; worst-case O(k²) item searches for k top-level values. |
| Judge retry/backoff | `judge0Poll` | Retries transient GET polling errors with capped exponential delay; never resubmits POST on timeout. At most three GET attempts per poll operation. |
| Async job polling | clients | Browser waits 500 ms between job checks; Flutter same interval, up to 65 seconds. |
| Debug difficulty generation | `js/questions.js` | Filters a seed by difficulty, takes configured slices, maps each to IDs 101–200. Linear scan/map over seed. |
| Sorting | terminal `sort`; problem ID validation | JS `.sort()` used on virtual file lines; not a ranking algorithm. |

The repository does not implement a novel competitive-programming algorithm as its core. Its main algorithmic contribution is orchestration/comparison/sandbox workflow, not solving every stored problem.

# Part 14: Important Variables

| Name | File | Purpose/type |
|---|---|---|
| `PROBLEMS` | `js/questions.js` | Array of 100 problem objects: id, title, diff, tags, sample acceptance/solved, description, examples, constraints, tests, starter code. |
| `DEBUGGING_QUESTIONS` | same | 100 generated debug objects, IDs 101–200, tests/hints/templates/score. |
| `LB` | same | Static sample leaderboard users/score/solved/streak/colors. |
| `curProblem`, `curDebugProblem` | `js/app.js` | Current browser selection object or null. |
| `submissions`, `debugSubmissions` | same | Current-page submission history arrays, not server persistence. |
| `activeInteractiveRun` | same | Current browser run ID/EventSource/UI/state. |
| `CLANG_CFG`, `cCode` | same | Compiler starter/snippet config and unsaved in-memory per-language drafts. |
| `VFS`, `termCwd`, `termHistory` | same | Simulated file tree, cwd, and terminal command history. |
| `executionJobs`, `idempotentExecutions`, `interactiveSessions` | `server.js` | Maps holding transient job/session state. |
| `AUTH_STATE` | same | Loaded JSON object of users/sessions. |
| `JUDGE0_BASE_URL`, `TIME_LIMIT_MS` | same | Provider URL and resource/time settings from environment. |
| `CODEARENA_REQUIRE_AUTH_FOR_EXECUTION` | same | Boolean security gate for `/api/judge` and `/api/run`; Compose sets true. |
| `ApiConfig.baseUrl` | Flutter config | Compile-time API URL. |
| `_language`, `_drafts`, `_runId`, `_judgeResult` | Flutter `editor_screen.dart` | Active editor language/code drafts/session/result state. |
| `_problemKey`, `_debugKey` | Flutter `progress_store.dart` | Secure-storage keys for local accepted-ID arrays. |

# Part 15: Error Handling

- **Invalid registration:** server returns 400 for missing fields, short password, invalid email; 409 for username/email conflict. Browser displays toast; Flutter shows a SnackBar.
- **Invalid login:** server returns 401; clients display API error. Password comparison is server-side.
- **Missing auth:** `/api/auth/me` returns 401. If optional execution gate enabled, Run/Submit routes return 401 before execution.
- **Empty/oversize source:** Run/Judge returns 400; source max 128 KiB. Judge stdin max 64 KiB, test count max 100.
- **Unsupported language:** 400 with message; interactive allows Python/C/C++/JavaScript/Java.
- **Runner unavailable/capacity:** 503 on container launch failure; 429 at max three active sessions. Runtime/output limit events stop process.
- **Compile/runtime errors:** interactive outputs stderr and finished state; Judge0 statuses are mapped to verdicts.
- **Wrong answer:** server stops at first mismatched test and returns expected/actual. Later test cases are not run after first failure.
- **Judge0 unavailable/invalid:** categorized execution error; logs request ID/provider HTTP status without source or credentials. Poll GET may retry; provider POST does not.
- **Timeout:** Judge overall deadline defaults 30s; interactive run defaults 30s, capped at 120s; Flutter polling deadline is 65s.
- **Network errors:** browser wraps judge fetch errors into Execution Error; Flutter maps Dio exceptions to user messages; SSE drop has connection status handling.
- **Missing problem assets:** Flutter FutureBuilder shows error/loading notices. Browser source constants are loaded as scripts; there is no remote problem fetch.
- **Database errors:** no database exists. JSON file load falls back to empty arrays on parse/read error, logging a warning.

Limitations: no global Express-style error middleware; the async HTTP callback/route should have a comprehensive rejection boundary. The browser has better handling in the judge path than in all other fetch/run paths.

# Part 16: Testing

| Test file | Tests | Does not prove |
|---|---|---|
| `tests/validate_problem_bank.js` | Exactly 100 IDs 1–100, test field types, non-empty cases, screens selected placeholders. | Algorithm correctness or consistency of stdin with statement. |
| `tests/validate_debugging_questions.js` | Parses generated question slice; 100 questions, IDs/required fields/tests/hints, 35/40/25 distribution. | Whether each bug description and expected answer is correct. |
| `tests/validate_judge_proxy.js` | Output whitespace, JSON structural equality, numeric tolerance, unordered top array, code-fence cleanup, Judge0 status mapping. | Real network/provider behavior. |
| `tests/validate_judge_integration.js` | Mock provider success, payload/auth headers, async polling, retries, timeout, malformed requests, provider errors, idempotency, log redaction. | Real Judge0 account, credentials, latency, service behavior. |
| `tests/validate_interactive_runner.js` | Docker live stdin/stdout, Stop, C compile error, Python runtime error, Python/C success. | Full five-language coverage or phone UI/API end-to-end. |
| `flutter_app/test/problem_repository_test.dart` | 100 problems/debug questions, first/last titles/IDs, language starter map and non-empty tests. | Live backend or all data correctness. |
| `flutter_app/test/widget_test.dart` | Dashboard branding and navigation control render. | Full screen navigation, auth, Run, Submit, Android device behavior. |

Validated during this project: Flutter `pub get`, `flutter analyze`, `flutter test`, standard release APK build; Node validators; runner Docker integration; backend image/Compose config and loopback smoke test. Not validated: real Judge0 provider, actual VPS TLS deployment, Play Store signing, every Flutter API call against a production API, every language in Docker, all problem answers, and Android testing on a physical phone.

Viva tests to demonstrate honestly: good Python `print(2)` Run; stdin prompt/echo; runtime error; stop a long run; compilation error with C; Judge mock test showing accepted/wrong/error classification; missing Judge0 configuration returns clear execution error; unauthenticated run on protected deployment returns 401; register/login and persisted cookie in a configured backend.

# Part 17: Code Review Findings

| Severity | Finding |
|---|---|
| HIGH | Public deployment mounts Docker socket into backend. API compromise can control host Docker; use dedicated host and consider isolated remote runner service. |
| HIGH | User registration is open and unthrottled; can be abused for PBKDF2 CPU/disk growth. Add rate limits/email verification/CAPTCHA/monitoring. |
| HIGH | Browser sample leaderboard/profile data look real. Replace with actual aggregate API or label clearly. |
| HIGH | Stored test data is not an authoritative problem oracle; several tests/inputs are not coherent with function-style descriptions. Standardize a harness and manually verify. |
| MEDIUM | `AUTH_SESSION_SECRET` is read but unused. README wording about “signed session cookies” does not match implementation: the cookie is a random opaque token looked up in JSON. Correct docs or implement signing. |
| MEDIUM | JSON account persistence writes whole file synchronously without locking/atomic replacement/backup; multiple instances are unsafe. Use a database for production. |
| MEDIUM | Job/session Maps are process-local. Restart loses work and multi-replica job polling fails. Use shared state or maintain exactly one replica. |
| MEDIUM | Browser uses `innerHTML` for some problem/debug fields without escaping each field. Bundled data is current trust boundary; escape if content becomes user/API-supplied. |
| MEDIUM | No explicit CSRF token/Origin check. SameSite=Lax helps, but explicit CSRF protection is safer for cookie-authenticated web routes. |
| MEDIUM | Public Codespaces backend is temporary; don't use real passwords/sensitive data. The public execution route is gated by account login, not by a deployment-grade abuse/rate-control system. |
| LOW | Remember-me and forgot-password controls are only markup. |
| LOW | Terminal tabs share global VFS/cwd/history rather than true independent shells. |
| LOW | Single breakpoint and desktop-oriented browser layout; Flutter is the real phone UI. |
| LOW | Root README Flutter paragraph is stale and says scaffold/unavailable despite current Android build. Use `ANDROID_BUILD_GUIDE.md`; update README if project constraints allow. |

No SQL means SQL injection is not applicable. No user file-upload endpoint exists. No explicit CORS configuration exists; website uses same origin, and native Flutter/Dio isn't governed by browser CORS. `spawn` takes a fixed executable and argument array; source content is in a file, not interpolated into a shell command. Docker resource restrictions are real but do not neutralize the privilege of mounting the Docker daemon socket.

# Part 18: Architecture and Request Arrows

```text
User
  -> Browser HTML/CSS/JS or native Flutter UI
  -> client behavior/filter/editor/API service
  -> Node HTTP server routes
  -> auth JSON file OR Docker runner OR Judge0 provider
  -> JSON/SSE response
  -> browser DOM or Flutter widgets
```

The first arrow is clicks, text, and selected code. The second is local rendering or an HTTP request. The server validates and routes. Run uses Docker and returns streaming events; Submit calls Judge0 and returns polled JSON; Auth reads/writes JSON. The client formats returned data for people. There is no separate database layer or message queue.

**Architecture classification:** client-server is supported. The Node service is a small monolith with route/helper functions in one file. API shape is REST-like. It is not a formal MVC implementation and not microservices. Docker and Judge0 are external execution components, not modules inside the browser.

# Part 19: “Why Did You Use This?” Viva Answers

- **Why HTML?** “HTML gives the browser the page structure and controls. In this project it defines navigation, problem tables, editors, result areas, and dialogs.”
- **Why CSS?** “CSS controls the CodeArena dark theme, layout, editor/terminal appearance, and one mobile breakpoint without needing a UI framework.”
- **Why JavaScript?** “Vanilla JavaScript handles filters, DOM updates, events, API fetches, SSE, and the terminal simulator; there is no frontend framework dependency.”
- **Why Node.js?** “Node provides one server process for static pages and API calls, and its child-process APIs can invoke Docker and handle streaming output.”
- **Why Docker?** “It runs user programs separately with resource and filesystem/network restrictions instead of executing arbitrary code inside the web server process.”
- **Why Judge0?** “The backend delegates batch compilation/execution to a Judge0-compatible service and polls its asynchronous result; the provider URL/credentials stay server-side.”
- **Why Flutter?** “Flutter builds a separate native-style Android UI from Dart widgets while reusing the existing API contract and bundled question data.”
- **Why Dio?** “Dio provides HTTP requests, timeouts, JSON, interceptors, and error mapping for Flutter.”
- **Why secure storage?** “It stores the mobile session cookie and local accepted IDs outside plain-text preferences. Passwords are never stored.”
- **Why API?** “The app sends code to a trusted server service because a phone/browser should not run submitted programs on the UI process.”
- **Why no database?** “This prototype uses a JSON auth file, Maps, and local/device storage. It is simpler to demonstrate but should be replaced with a database for multi-instance production.”
- **Why this architecture?** “The website is a static client plus one Node server; the native app is another client. Run and Submit are separated because interactive stdin and test-case judging have different workflows.”

# Part 20: Fifty Project-Specific Viva Questions

Each answer starts with a short answer suitable for the viva, followed by a little more detail and the relevant code location.

1. **What is CodeArena?** Simple: A coding practice and evaluation platform. Detail: It combines static problem data, browser/native editors, Docker Run, and optional Judge0 Submit. Code: `index.html`, `server.js`, `flutter_app/lib/main.dart`.
2. **Which parts are browser and which are Android?** Simple: The repo has a modular website and separate Flutter app. Detail: The native app does not load the website in WebView. Code: `index.html`, `flutter_app/lib/screens/app_shell.dart`.
3. **How many regular problems exist?** Simple: 100 records. Detail: IDs are 1–100 in `PROBLEMS`; validator checks IDs and metadata, not correctness. Code: `js/questions.js`, `tests/validate_problem_bank.js`.
4. **How many debug questions?** Simple: 100, IDs 101–200. Detail: Generated from seed data with Easy/Moderate/Hard distribution 35/40/25. Code: `js/questions.js`, validator.
5. **Is Bootstrap used?** Simple: No. Detail: Styles are custom CSS and browser JS is vanilla. Code: `index.html`, `css/style.css`.
6. **Is Express used?** Simple: No. Detail: The server uses Node `http.createServer` and a custom dispatcher. Code: `server.js`.
7. **What happens when the page loads?** Simple: Server returns HTML; browser loads CSS/data/JS. Detail: `DOMContentLoaded` renders arrays and checks auth. Code: server static handler, `index.html`, `app.js`.
8. **How are problems searched?** Simple: Client-side filtering. Detail: Lowercases query and tests title/tags through `Array.filter`. Code: `renderProblems`.
9. **What does Run do?** Simple: Runs complete source in Docker and streams output. Detail: POST returns run ID; SSE carries events; input/stop use additional routes. Code: `startInteractiveRun`, `handleInteractiveRun`.
10. **What does Submit do?** Simple: Sends test cases through Judge0. Detail: Server posts Base64 source/stdin, polls token, compares output. Code: `submitCode`, `executeTest`.
11. **Why are Run and Submit separate?** Simple: Run is an interactive terminal; Submit evaluates fixed cases. Detail: Run accepts stdin over a live session; Submit tracks expected output per case. Code: `/api/run`, `/api/judge`.
12. **Where does Run code execute?** Simple: Docker on the Node backend host. Detail: Not in browser; the runner uses no network, limits, and read-only mounts. Code: `createInteractiveSession`, `runner.sh`.
13. **Where does Submit code execute?** Simple: Judge0 when configured. Detail: CodeArena does not compile it itself; current Codespaces/Vercel setup has no live Judge0 provider. Code: `executeTest`.
14. **What is a test case?** Simple: Input and expected output. Detail: Server accepts strings `stdin`/`expected` and optional unordered flag. Code: `/api/judge` validation.
15. **How is Accepted decided?** Simple: Every test must run and match. Detail: Provider must report execution accepted and `outputsEqual` must pass. Code: `runExecutionJob`.
16. **How are spaces handled?** Simple: Outer/trailing line spaces are normalized. Detail: JSON gets structural compare, number tolerance, and optional top-level unordered arrays. Code: `normalizeOutput`, `outputsEqual`.
17. **What is SSE?** Simple: A long HTTP connection carrying named events. Detail: It carries `status`, `stdout`, `stderr`, and `finished` from server to UI. Code: `handleRunEvents`, `EventSource`, `InteractiveRunService`.
18. **How does stdin work?** Simple: Client posts a string to a running session. Detail: Server writes it to child stdin and runner process reads normally. Code: `/api/run/{id}/input`.
19. **How does Stop work?** Simple: Server asks Docker to stop the container. Detail: It retries stop and schedules a force kill. Code: `stopInteractiveSession`.
20. **How is code fenced with Markdown handled?** Simple: Outer code fences may be stripped. Detail: `cleanSourceCode` removes a complete leading/trailing fence only. Code: `server.js`.
21. **What does Docker sandboxing restrict?** Simple: Network, filesystem, privileges, resources, and runtime. Detail: no network, read-only root/source, UID 65534, 128 MiB, 0.5 CPU, pids 32. Code: Docker args in `createInteractiveSession`.
22. **Is it fully secure?** Simple: It has meaningful limits but is not a guarantee. Detail: Backend mounting Docker socket is high privilege; public registration needs abuse controls. Code: `compose.backend.yaml`, server validation.
23. **What languages exist?** Simple: Python, C, C++, JavaScript, Java. Detail: Runner maps each to interpreter/compiler and Judge0 maps IDs. Code: `runner.sh`, language maps.
24. **What compilers are used?** Simple: gcc, g++, javac; Python/Node runtimes. Detail: Runner compiles C11/C++17 and Main.java. Code: `runner.sh`.
25. **What does compilation error mean?** Simple: Compiler could not build source. Detail: Judge0 status 6 maps to Compilation Error; Docker Run emits compiler stderr/program failure. Code: `classify`, runner.
26. **What does runtime error mean?** Simple: Program crashed after launch. Detail: Judge0 IDs 7–12 map to Runtime Error; interactive stderr is streamed. Code: `classify`, Run events.
27. **How is timeout handled?** Simple: The process is stopped and reported. Detail: Judge0 deadline and runner timeout are separate configurable limits. Code: `executeTest`, session timeout.
28. **Does a score get calculated?** Simple: No general score engine. Detail: Debug records have static point values; no service aggregates score. Code: `DEBUGGING_QUESTIONS`, `renderDebuggingProblems`.
29. **Where is the leaderboard data?** Simple: Hard-coded in browser. Detail: `LB` contains sample names/values; Flutter says no live rankings. Code: `questions.js`, `renderLB`, `leaderboard_screen.dart`.
30. **Is there a database?** Simple: No. Detail: JSON file, Maps, localStorage, assets, and Flutter secure storage are used. Code: `AUTH_STATE`, `VFS`, `ProgressStore`.
31. **How are passwords stored?** Simple: Not as plain text; they are salted PBKDF2 hashes. Detail: 120,000 SHA-512 iterations and timingSafeEqual. Code: `hashPassword`, `verifyPassword`.
32. **Is the session cookie signed?** Simple: It is a random opaque token looked up server-side, not HMAC-signed in current code. Detail: `AUTH_SESSION_SECRET` is declared but unused; docs saying signed cookie are inaccurate. Code: `generateToken`, `getCurrentUser`.
33. **What is stored in `.data/auth.json`?** Simple: Users and sessions. Detail: Password hash, random IDs, session token, user ID, expiry; deployment volume persists file. Code: `loadAuthState`, `persistAuthState`.
34. **Does logout delete the account?** Simple: No, it removes that session. Detail: User remains; cookie expires. Code: `/api/auth/logout`.
35. **What does “Remember me” do?** Simple: Nothing currently. Detail: Checkbox has no event wiring; cookie expiry is configured globally. Code: login modal, `handleLogin`.
36. **What does “Forgot password” do?** Simple: Nothing currently. Detail: Anchor is markup only; no reset route/email service. Code: `index.html`, auth routes.
37. **Are profile stats real?** Simple: Mostly not in browser. Detail: Browser uses sample stats/formulas/random heatmap; Flutter shows only current account and locally accepted counts. Code: `renderDashboard`, `renderHeatmap`, `profile_screen.dart`.
38. **What is saved in browser localStorage?** Simple: Display user data and debug progress. Detail: Not a database or password store; problem progress array is not updated by standard problem submit. Code: `getStoredProgress`, auth handlers.
39. **What does the Flutter app use?** Simple: Native Dart/Flutter screens with Dio and secure storage. Detail: Asset repository and separate services call backend. Code: `main.dart`, `services/`.
40. **How does Flutter know backend URL?** Simple: Compile-time `API_BASE_URL`. Detail: Release requires HTTPS; absent setting blocks API-dependent actions. Code: `api_config.dart`, build command.
41. **Does Flutter use a WebView?** Simple: No. Detail: Widgets/screens are native Flutter and Android app has its own entrypoint. Code: `MainActivity.kt`, `main.dart`.
42. **How does Flutter preserve login?** Simple: It stores cookie in platform secure storage. Detail: Dio interceptor writes Set-Cookie's session pair and sends Cookie on next calls. Code: `_SessionCookieInterceptor`.
43. **Is Android progress synced?** Simple: No. Detail: Accepted IDs are device-only secure-storage lists. Code: `ProgressStore`.
44. **Why is leaderboard blank in Flutter?** Simple: There is no live API. Detail: Static browser sample users are deliberately not presented as real. Code: `leaderboard_screen.dart`.
45. **What tests exist?** Simple: Five Node validators plus two Flutter tests. Detail: They check metadata, output helpers, mocked Judge0, Docker Python/C, assets, dashboard. Code: `tests/`, `flutter_app/test/`.
46. **Do tests prove all problems are correct?** Simple: No. Detail: Metadata shape/count validation does not execute/verify every expected algorithm answer. Code: problem-bank validator and README warning.
47. **Why can Vercel fail?** Simple: Existing backend needs persistent Node and Docker. Detail: Serverless functions do not meet the runner/process-local maps/shared temp mount assumptions; deployed endpoints were observed 500. Code: `server.js`, deployment guide.
48. **What does Caddy do?** Simple: Reverse proxy and HTTPS. Detail: It forwards public domain traffic to Node on port 8000 and manages TLS certificates. Code: `Caddyfile`, Compose.
49. **Can multiple backend replicas run?** Simple: Not safely with current Maps/file writes. Detail: jobs belong to one process and auth file writes aren't coordinated. Code: `executionJobs`, `interactiveSessions`, JSON storage.
50. **What is the honest biggest limitation?** Simple: Some data is sample/unverified and backend needs external services. Detail: The app demonstrates the execution architecture, but real Submit requires Judge0 and durable deployment requires a Docker-capable host. Code: README, server configuration, deployment files.

# Part 21: Professor Cross-Questioning

**Professor: Is this truly an online judge if Judge0 is not configured?**

Answer: “The code implements the Judge0 integration, async job IDs, polling, error mapping, and test comparison, and tests it against a mock provider. A live Judge0 service is an external requirement. Without `JUDGE0_BASE_URL`, the server deliberately returns 503, so I would not claim live Submit is available in that environment.”

**Professor: Where is your database?**

Answer: “There isn't a database in the current repository. Auth rows are stored in `.data/auth.json`; jobs are in process-local Maps; browser data uses localStorage; Android accepted IDs are local secure storage. For production I would migrate auth and progress to a database and jobs to shared storage.”

**Professor: How do you protect the server from malicious code?**

Answer: “Interactive Run uses a Docker container with no network, read-only source/root, non-root UID, dropped capabilities, no-new-privileges, CPU/memory/PID/file limits, a runtime timeout, and output/input caps. The backend still needs a trusted Docker host; the Docker socket is very privileged.”

**Professor: Can you prevent cheating?**

Answer: “Not fully. There is a browser restricted-clipboard toggle, but a user can bypass client-side controls. The app does not include plagiarism detection, proctoring, hidden test secrecy, or a secure exam mode.”

**Professor: How is your score calculated?**

Answer: “The backend returns pass/fail verdicts, not an aggregate score. Debug questions have static score metadata. Browser profile and leaderboard numbers are sample data, so I should not present them as calculated user results.”

**Professor: What happens if a provider times out?**

Answer: “The job becomes an Execution Error with a category. Poll GETs may retry transient errors within a deadline; the initial POST is not retried because the provider might already have accepted it.”

**Professor: Why use a function-style starter if judge stdin is raw?**

Answer: “That is a real limitation. The test data is sent verbatim as stdin and there is no universal parser/harness. I would standardize each problem’s input contract and verify each expected output before claiming the bank is judge-ready.”

**Professor: What happens if Node restarts mid-run?**

Answer: “Job/session maps disappear and browser polling can return not found. The current design is one process. A production multi-instance design needs durable/shared job storage and a shared runner/session service.”

**Professor: Why not use Firebase/SQL?**

Answer: “The current prototype uses a simple JSON file and local stores; it does not use a database. That was simpler for a small demo, but it limits safe concurrency, querying, backups, and scale. The project doesn't document a measured comparison of alternatives.”

**Professor: Which part is your algorithm?**

Answer: “The project mainly integrates the execution pipeline, output comparison, async polling, filtering, and a constrained runner; it is not a new problem-solving algorithm collection. `outputsEqual` handles normalized text and structural JSON comparison.”

# Part 22: Important Code Sections Explained

1. **Problem source factory `P` — `js/questions.js`:** builds a common record from ID/title/difficulty/tags/examples/constraints/tests and adds language starter templates. Without it, each record would repeat the same shape. It does not create a custom algorithm harness.
2. **Problem selection `openProblem` — `js/app.js`:** finds the selected problem, puts its details into the side panel, copies starter code into the textarea, updates line numbers, and shows Solve. Removing it breaks row-to-editor navigation.
3. **Judge request `requestJudgeExecution` — `js/app.js`:** submits code/tests, validates execution ID, polls until terminal state, handles invalid JSON/status/504, and returns a user-visible error object. It is the browser's Submit bridge.
4. **Docker runner `createInteractiveSession` — `server.js`:** maps language to filename, writes source in temp space, creates restrictive Docker args, starts `spawn`, forwards stdout/stderr, and emits state events. This is the core real Run mechanism.
5. **Output comparator `outputsEqual` — `server.js`:** normalizes and compares strings/JSON. Without it, Judge0's process status alone would not prove output is correct.
6. **Provider client `executeTest` — `server.js`:** constructs Base64 Judge0 payload, POSTs once, polls token, classifies status and returns output/time/memory. It is the actual Submit service integration.
7. **Flutter API client `ApiClient` — `flutter_app/lib/services/api_client.dart`:** creates Dio with base URL/timeouts, adds cookie interceptor, validates configuration, and maps network errors. Screens should not hardcode hostnames.
8. **Cookie interceptor — same file:** reads secure cookie before request and saves/expires it after response. Without it, backend HTTP-only session behavior would not persist across app calls.
9. **Runner process commands — `runner.sh`:** uses Python, gcc, g++, Node, or javac/java. The Dockerfile provides these tools; deleting one install breaks that language's Run.
10. **Flutter local progress — `ProgressStore`:** reads/writes sorted accepted-ID JSON lists in Flutter Secure Storage. It is intentionally device-local; it does not update server user data.

# Part 23: Presentation Preparation

## One-minute introduction

“CodeArena is a practice platform implemented as both a browser app and a native Flutter Android app. The web client is plain HTML/CSS/JavaScript and the backend is a Node HTTP server. Users browse bundled exercises and can use interactive Run, which executes in a restricted Docker container. Submit is separate: it sends test cases through the backend to a Judge0-compatible provider, polls the result, and compares output. Auth uses hashed passwords and server sessions, but the prototype has no database; some progress and leaderboard data are sample or local. The main work needed for production is verified test data, a durable database/job store, abuse protection, and a deployed Judge0/Docker-capable backend.”

## Three-minute explanation

Use the 2-minute script in Part 1, then add: “The web terminal has a virtual filesystem, so commands such as `ls` and `cat` are simulated; commands that launch source files go through the Docker runner. In Flutter, exercises are bundled JSON generated from the same JavaScript source. Dio uses a compile-time HTTPS API origin, secure cookie storage handles login, and accepted IDs stay on-device. Tests include metadata checks, mocked Judge0 integration, and Docker Run for Python/C. These tests do not certify every problem answer or a real Judge0 account. The current Codespaces API is temporary and Submit needs provider credentials.”

## Slide status

No presentation/slides file is present in the tracked project inventory, so I cannot provide a slide-by-slide script from an existing deck. If you create slides, use: problem/background, objectives, architecture, browser/app UI, Run flow, Submit flow, authentication/storage, tests, limitations, and future work.

# Part 24: Demonstration Script

1. Open the website or APK and say this is the current browser/native client.
2. Show Home; explicitly label animated counters as sample values.
3. Open Problems; show title search and difficulty filter.
4. Open one problem; explain that data is bundled and examples are source metadata.
5. In editor, choose Python and run a complete program such as `print(1 + 1)`; show output `2`. For stdin, use `print(int(input()) * 2)` and enter `5` in Run input.
6. Show Stop on a short sleep loop, then perhaps show a compile/runtime error in Docker if time.
7. Explain Submit separately. Only demonstrate live Submit if a real Judge0 provider is configured and tested immediately before the presentation. Otherwise say it uses the Judge0 integration and show the mock-provider test, not a fabricated live verdict.
8. Show Debugging Arena but disclose questions/tests are not independently validated.
9. Show Terminal and explicitly explain `ls` is virtual while `python3 file.py` uses Docker.
10. Show Profile / Leaderboard only as implementation status: local/demo stats and no live rankings.
11. If showing Android, display native Flutter screens and explain its bundled data, sign-in, and API configuration. Avoid claiming all app backend routes are live if Codespace is asleep.

Avoid claiming the browser profile's “Rank #42”, sample leaderboard names, random heatmap, home totals, every problem's correctness, the SQL playground, chatbot, or Interview Arena as production functionality.

# Part 25: Strengths, Weaknesses, and Future Improvements

## Strengths

1. Clear separation between interactive Run and case-based Submit.
2. Real Docker execution rather than browser `eval`.
3. Defense-in-depth restrictions on runner containers.
4. SSE streaming and interactive stdin/Stop.
5. Async Judge0 job model with request IDs/logging.
6. Output normalization and JSON comparison tests.
7. Server-side password hashing and HTTP-only session cookie.
8. Source-backed static data plus generator for Flutter assets.
9. Separate native Android UI, not a WebView wrapper.
10. Tests cover mock provider errors and actual local Docker Run.

## Weaknesses

1. No database or durable job store.
2. Judge0 has no configured real service in sample environment.
3. Vercel API was observed returning function errors and cannot provide Docker process assumptions.
4. Problem tests can mismatch described function signatures.
5. Browser leaderboard/profile/home values are fake/sample.
6. No central submission history or server progress endpoint.
7. No rate limiting/account verification/password reset.
8. Session secret variable is unused and docs say “signed” inaccurately.
9. Docker socket grants powerful host capability.
10. Native editor lacks syntax highlighting; language coverage tests are incomplete.

## Future work

1. Store users/sessions in PostgreSQL or another durable database with migrations and backups.
2. Move job/session state to Redis or an execution queue; separate API from worker.
3. Deploy runner on a dedicated, hardened host/service with auditable lifecycle.
4. Configure and monitor a real Judge0 provider; protect secrets.
5. Define each problem's input parser/harness and verify all expected outputs.
6. Persist submission records, progress, score, and leaderboard aggregates server-side.
7. Add rate limiting, email verification, account recovery, CSRF/Origin controls, logging/monitoring.
8. Add syntax highlighting and better editor accessibility/mobile ergonomics.
9. Test all five languages, auth lifecycle, API errors, app network transitions, and device sizes.
10. Remove or label every sample/demo metric and update stale README claims.

## Honest response to criticism

“This is a working prototype, not a production-scale judge. The execution design and tests demonstrate real Docker Run and the Judge0 adapter, but live Submit requires provider credentials. The dataset checks validate shape, not every solution. I’ve kept those limits explicit and designed the next steps around data verification, persistent storage, and secure deployment.”

# Part 26: Final Cheat Sheet

- **Definition:** browser + native Android coding-practice platform.
- **Frontend:** HTML, custom CSS, vanilla JS; Android is Flutter/Dart.
- **Backend:** one Node built-in HTTP server in `server.js`.
- **Run:** interactive Docker execution, SSE, stdin, stop.
- **Submit:** Judge0-compatible async submission/polling plus CodeArena output compare; provider required.
- **Languages:** Python 3, C, C++, JavaScript, Java in configuration/runner.
- **Data:** no DB; auth JSON file, jobs in Maps, browser localStorage, Android secure storage, static asset arrays.
- **Security:** PBKDF2 password hashes, HTTP-only cookie, optional execution auth, restricted Docker runner; public registration and Docker socket are risks.
- **Tests:** 5 Node validators + 2 Flutter tests; mock Judge0 and Docker Python/C; not all data/provider/language cases.
- **Largest limits:** unverified problem tests, no live leaderboard/account progress, missing live Judge0, temporary Codespaces backend.
- **Avoid claiming:** fake profile stats, leaderboard as real, simulated shell as real Linux, absent Interview/SQL/chatbot features.
- **Build:** `flutter build apk --release --dart-define=API_BASE_URL=https://YOUR_HOST`.

## Twenty short answers to memorize

1. CodeArena helps learners browse coding exercises and run or submit code.
2. The browser uses plain HTML, CSS, and JavaScript.
3. The Android app is Flutter, not a WebView.
4. The Node server uses built-in HTTP modules, not Express.
5. Run is interactive and Docker-backed.
6. Submit is test-based and uses Judge0 when configured.
7. Run streams events using SSE.
8. Submit polls an asynchronous execution ID/token.
9. The runner supports Python, C, C++, JavaScript, and Java.
10. The runner container has no network and has resource limits.
11. There is no SQL database.
12. Accounts are stored in `.data/auth.json` with password hashes.
13. Browser progress uses localStorage.
14. Android accepted progress stays on the device.
15. The leaderboard is not live.
16. Some profile and homepage statistics are sample values.
17. Problem tests are not all independently verified.
18. The backend is single-instance because job Maps are in memory.
19. Vercel's API was returning HTTP 500; the Docker backend needs a persistent host.
20. The honest next steps are real provider setup, verified test data, database/progress APIs, and stronger deployment controls.

## Closing viva statement

“CodeArena demonstrates a complete client-server execution idea: static problem data, native and browser interfaces, authenticated API routes, isolated Docker Run, and asynchronous Judge0 Submit. I can show which parts are working and tested, and I can also explain clearly what is still sample data or requires production services.”