# Project Guidelines

## Architecture
- This repository is the main Status app codebase for desktop and mobile.
- The frontend is primarily Qt/QML, with Nim middleware in `src/` coordinating UI-facing modules and services.
- Treat the app as local-first: there is no remote application server for core product logic. The backend runs locally on the device, and user data is stored in local databases.
- The effective backend is `vendor/status-go`. When investigating behavior, trace through the QML or Nim layer into `vendor/status-go` instead of assuming the logic ends in this repository's UI or middleware.
- If the root cause or correct implementation belongs in `vendor/status-go`, modify it there instead of adding UI-side or Nim-side workarounds.
- On Android, `status-go` may run through a separate local service and stub layer rather than directly in the UI process. Consult the Android ADRs before changing mobile service, IPC, login-resume, or notification flows.

## Conventions
- Preserve the existing layering described in `docs/architecture.md`: QML frontend, Nim middleware, and local backend responsibilities should stay separated.
- For QML architecture and component boundaries, follow `guidelines/QML_ARCHITECTURE_GUIDE.md`.
- Prefer fixes at the owning layer:
  - QML or StatusQ for presentation and interaction issues.
  - Nim in `src/` for app orchestration, signal handling, and module wiring.
  - `vendor/status-go` for backend logic, persistence, protocol, and notification behavior.
- Do not describe or implement features as if they depend on a hosted server unless the code or docs explicitly show an external integration.

## Build And Test
- Use `BUILDING.md`, `README.md`, and platform-specific docs under `mobile/` for setup and build commands.
- When touching Android service or IPC behavior, consult the ADRs under `docs/adr/`, especially the Android `status-go` service architecture.

## Working Style
- When a change spans QML, Nim, and `vendor/status-go`, inspect the full path before editing and keep the final fix in the layer that actually owns the behavior.
- Keep instructions and comments aligned with the repo's terminology: local backend, local databases, and `status-go` as the backend.