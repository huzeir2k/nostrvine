# Repository Guidelines

## Project Structure & Modules
- `mobile/`: Flutter app. Code in `lib/`; tests in `test/` and `integration_test/`; assets in `assets/`.
- `backend/`: Cloudflare Workers (TypeScript). Code in `src/`; tests in `test/`; config in `wrangler.jsonc` and `.wrangler/`.
- `nostr_sdk/`: Dart package used by the app (`lib/`, `test/`). Other roots: `docs/`, `website/`, `crawler/`.

## Build, Test, Develop
- Mobile:
  - `cd mobile && flutter pub get && flutter run` — Launch app (Chrome/device).
  - `cd mobile && flutter test` — Run unit/widget tests.
  - `cd mobile && flutter analyze` — Lints; fix all findings before PR.
  - `cd mobile && dart format --set-exit-if-changed .` — Enforce formatting.
  - `cd mobile && ./build_native.sh ios|macos [debug|release]` — Native builds.
- Backend:
  - `cd backend && npm install && npm run dev` — Wrangler dev server.
  - `cd backend && npm test` — Vitest (Workers pool).
  - `cd backend && npm run deploy` — Deploy worker.
  - `cd backend && npm run cf-typegen` — Generate Cloudflare types.
  - `cd backend && ./flush-analytics-simple.sh true|false` — Preview/flush analytics KV.

## Coding Style & Conventions
- Dart/Flutter: 2-space indent; files `snake_case.dart`; classes/widgets `PascalCase`; members `camelCase`. See `analysis_options.yaml`.
- Limits: ~200 lines/file, ~30 lines/function; never use `Future.delayed` in `lib/`.
- TypeScript: Prettier per `backend/.prettierrc` (tabs, single quotes, semicolons, width 140) and `backend/.editorconfig`.
- Naming: files `kebab-case.ts`; tests `*.test.ts|*.spec.ts` in `backend/test`.

## Testing Guidelines
- Mobile: `flutter test`; co-locate as `*_test.dart`. Target ≥80% overall coverage (see `mobile/coverage_config.yaml`).
- Backend: Vitest in `backend/test` with descriptive names; run via `npm test`.

## Commit & PR Guidelines
- Commits: Conventional Commits (`feat:`, `fix:`, `docs:`, etc.).
- PRs: clear description, linked issues, tests for new logic, and screenshots/recordings for UI changes.
- Pre-flight: analyzers, formatters, and tests pass locally (`pre-commit run -a` if configured).

## Agent-Specific Instructions
- Embedded Nostr Relay: Use `ws://localhost:7447`; do not connect directly to external relays. External access via `addExternalRelay()` (see `mobile/docs/NOSTR_RELAY_ARCHITECTURE.md`).
- Async: Avoid arbitrary sleeps; use callbacks, `Completer`, streams, and readiness signals.
- Quality Gate: After any Dart change, run `flutter analyze` and fix all findings.

## Specialized Subagents

### flutter-test-runner

**Agent Name**: flutter-test-runner
**Purpose**: Run Flutter analyze and tests, then provide clear reports

**Core Responsibilities**:
1. Run `flutter analyze` from the mobile/ directory
2. Run `flutter test` from the mobile/ directory  
3. Parse and categorize results (errors, warnings, passing/failing tests)
4. Generate clear, structured reports with:
   - Analysis issues grouped by severity
   - Test results with pass/fail counts
   - Specific error messages and stack traces
   - File paths and line numbers for quick navigation

**Output Format**:
- Summary section with counts
- Detailed issues section with actionable information
- Recommendations for next steps

**Tools Available**: Bash, Read, LS, Grep

**Agent Focus**: This agent focuses on running tests and clearly reporting results, NOT on fixing issues.

#### Usage Instructions

To use this agent, invoke it with a request like:
```
Run flutter-test-runner to analyze the current state of the Flutter codebase
```

The agent will:
1. Execute `flutter analyze` and `flutter test` commands
2. Parse the output for issues and test results
3. Generate a comprehensive report with actionable insights
4. Provide clear next steps for addressing any issues found

#### Sample Output Format

```
# Flutter Test Runner Report

## Summary
- Analysis: X errors, Y warnings, Z info messages
- Tests: A passed, B failed, C skipped
- Total Issues: N

## Analysis Issues

### Errors (X)
- [FILE:LINE] Error description
- [FILE:LINE] Error description

### Warnings (Y)  
- [FILE:LINE] Warning description
- [FILE:LINE] Warning description

## Test Results

### Failed Tests (B)
- test_name: failure_reason
- test_name: failure_reason

### Passed Tests (A)
- All passing tests listed or summary

## Recommendations
1. Priority actions based on severity
2. Suggested next steps
3. Files requiring immediate attention
```

