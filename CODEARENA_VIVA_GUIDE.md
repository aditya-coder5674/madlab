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

A submit test case is a raw input string and expected output string. For the sample above: `stdin: "5"`, `expected: "10"`. The program must read stdin; the backend does not transform `