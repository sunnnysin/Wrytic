# Architecture Decisions

## Xcode project generation: XcodeGen

The `.xcodeproj` is generated from `project.yml` via
[XcodeGen](https://github.com/yonaskolb/XcodeGen) rather than maintained
by hand. This keeps the project file diff-friendly and scriptable (CI
regenerates it the same way a local machine does) instead of relying on
Xcode's GUI project editor, which produces large, conflict-prone
`project.pbxproj` diffs. The generated `.xcodeproj` is still committed
(not gitignored) so the repo can be opened directly without requiring
XcodeGen as a hard prerequisite — regenerate with `xcodegen generate`
only when `project.yml` changes.

## CI runner: GitHub-hosted `xcode-27` image

The build plan (Section 8) flagged a real risk: GitHub-hosted macOS
runners often lag behind the newest Xcode/iPadOS release, which could
have forced CI onto build-only verification or a self-hosted runner.
As of this project's Phase 2, GitHub's `actions/runner-images` already
ships a dedicated `xcode-27` (arm64) preview image with Xcode 27.0 beta 4
and the full iOS/iPadOS 27.0 SDK and simulators (including iPad Air/Pro
models), so CI runs full build + test on real matching simulators —
no fallback needed. If this image is ever pulled or renamed, this is the
first place to check, and the plan's documented fallback (build-only
verification, or a self-hosted runner) still applies.

## App shell navigation: NavigationSplitView

The Phase 3 shell uses a two-column `NavigationSplitView` (sidebar +
detail) rather than a three-column layout or a tab bar, matching
standard iPad navigation patterns for this kind of app. `NotebookStore`
is a plain `@Observable` in-memory placeholder for now — it exists only
so the sidebar/home screen has something real to navigate and the "New
Notebook" flow is testable; it's replaced by real persistence in Phase
17 and isn't meant to survive app relaunch until then.

## PencilKit canvas: UIScrollView + PKCanvasView, not PKCanvasView alone

`PKCanvasView` doesn't provide zoom on its own, so the Phase 4 canvas
wraps it in a plain `UIScrollView` (`PencilCanvasScrollView`) that owns
zooming/panning, with the canvas view as the scroll view's single
zoomable subview. `drawingPolicy = .pencilOnly` on the canvas means
finger touches never draw — the scroll view's own pan/pinch gestures
handle finger input instead, and a resting palm is just another
non-Pencil touch, giving palm rejection for free with no extra logic.
Canvas setup lives in `PencilCanvasConfiguration`, kept separate from
the `UIViewRepresentable` so it's unit-testable without a real UIKit
view hierarchy.

## Linting: SwiftLint

SwiftLint runs in CI (`.swiftlint.yml` at the repo root) and fails the
build on violations (`--strict`). Scoped to `Wrytic/` and `WryticTests/`
only — `RecognitionSpike/` is excluded since it's explicitly disposable
(Phase 0) and not held to the same bar.
