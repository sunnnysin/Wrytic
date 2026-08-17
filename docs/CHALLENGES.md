# Challenges & Decisions Log

Dated entries for anything genuinely non-obvious encountered during
development. See `Wrytic-Build-Plan.md` (local, untracked) for the full
phase plan and instructions this log is referenced from.

## 2026-08-17 — Phase 1, Project Setup
Problem: The build plan's Section 3 sketch of `HandwritingRecognitionService`
assumed a stateless `recognize(strokes:) async throws -> RecognitionResult`
API with a bounding box and confidence score. The real `PKStrokeRecognizer`
in the Xcode 27 beta 5 SDK (iPhoneOS27.0.sdk) is an actor that holds a
`PKDrawing` via `updateDrawing(_:)` and returns text via
`recognizedText(strokeIDs:) async -> String?` — no `throws`, no confidence,
no bounding box.
Resolution: Verified the actual API by inspecting
`PencilKit.framework`'s Swift module interface directly (grepping the
`.swiftinterface` file in the installed SDK) rather than assuming the
plan's sketch was accurate. Updated the plan's Section 3 to match. The
real signature is friendlier for Phase 9's "pen-only" filtering
requirement than the assumed one — you pass the set of pen-tool stroke
UUIDs into `recognizedText(strokeIDs:)` directly.
Relevant files: `Wrytic-Build-Plan.md` (Section 3, local/untracked).

## 2026-08-17 — Phase 1, Project Setup
Problem: The build machine has Xcode 26.6 as the default toolchain
(`xcode-select`); Xcode 27 beta 5 (with the iOS 27.0 SDK this project
requires) was installed separately as `Xcode-27-beta.app` and not the
active default. Switching the global default via `sudo xcode-select -s`
would affect other unrelated projects on the same machine.
Resolution: Scoped all builds to the beta via the `DEVELOPER_DIR`
environment variable per-command instead of changing the global default.
CI (`.github/workflows/build-and-test.yml`) will need the equivalent —
selecting the Xcode 27 version explicitly on the runner rather than
relying on a global default — once GitHub-hosted runners have Xcode 27
available (see Section 8's known constraint).
Relevant files: `project.yml`, `.github/workflows/build-and-test.yml` (Phase 2).

## 2026-08-17 — Phase 1, Project Setup
Problem: No iOS 27.0 *simulator runtime* was installed alongside the
Xcode 27 beta 5 SDK (only iOS 26.5 simulator runtimes were present),
even though the device SDK itself was available. Simulator builds at
the required deployment target failed to find a matching destination.
Resolution: Confirmed the project compiles correctly via an unsigned
generic device build (`-destination 'generic/platform=iOS'
CODE_SIGNING_ALLOWED=NO`) as an interim verification step, and kicked
off `xcodebuild -downloadPlatform iOS` to fetch the matching simulator
runtime. Running on the physical iPad (already paired: "Satyam's iPad
(2)") additionally requires selecting a development team in Signing &
Capabilities, which needs interactive Apple ID access.
Relevant files: `Wrytic.xcodeproj`.
