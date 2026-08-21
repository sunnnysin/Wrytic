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

## Drawing tools: PKToolPicker, not a custom palette

Evaluated both options from the Phase 5 spec. Went with Apple's native
`PKToolPicker` rather than a custom SwiftUI tool palette: it's
system-provided, already gives pen/highlighter/eraser selection, a
color picker, and a width slider for free, follows the system's
light/dark appearance automatically, and is what most iPad users
already know from Notes/Freeform/every other PencilKit app. A custom
palette would mean rebuilding all of that UI (including a real color
picker) for no functional gain at this stage — it's a better fit for
Phase 28's visual-polish pass than for now, if ever.

PencilKit has no distinct "highlighter" ink type — real PencilKit apps
(including Apple's own) build highlighter behavior out of the `.marker`
ink type with a translucent color and a wider default width, which is
what `DrawingToolPickerFactory` does.

Eraser modes map to `PKEraserTool.EraserType`: `.vector` is the
whole-stroke eraser, `.bitmap` is the partial/pixel eraser. Only one
`PKToolPickerEraserItem` (`.vector`) is offered as a picker item —
unlike `PKToolPickerInkingItem`, it has no settable `identifier`, and
per Apple's documented dedup behavior a second instance silently
collides with the first and gets dropped (caught by CI: `toolItems`
came back with 3 items instead of the assumed 4, on real hardware, not
just in unit tests against a mocked picker). Whether the single vector
eraser item's own native flyout additionally exposes bitmap/pixel
erasing (the same way a single `PKToolPickerInkingItem`'s color/width
are still adjustable beyond its constructor defaults) needs on-device
confirmation — if not, a second, explicit way to reach bitmap erasing
is still owed against the "both eraser modes" requirement.

Each stroke's originating tool is derived from `PKStroke.ink.inkType`
via `StrokeTool.from(_:)` (pen ↔ `.pen`, highlighter ↔ `.marker`) rather
than tracked in a separate side table — since Wrytic fully controls
which ink type each of its own tools uses, this mapping is unambiguous
and needs no extra state to stay in sync. This is what Phase 9's
recognition filtering will call to skip highlighter strokes.

## Linting: SwiftLint

SwiftLint runs in CI (`.swiftlint.yml` at the repo root) and fails the
build on violations (`--strict`). Scoped to `Wrytic/` and `WryticTests/`
only — `RecognitionSpike/` is excluded since it's explicitly disposable
(Phase 0) and not held to the same bar.

## Shape recognition: custom heuristic (no public shape-fitting API exists)

Checked the actual iOS 27 SDK before implementing anything — searched
every `PencilKit.framework` header and the Swift module interface for
any shape-recognition or geometry-fitting API (`grep -i "shape"` across
all headers, the full `PencilKit.h` umbrella header symbol list, and the
`.swiftinterface`). None exists. PencilKit's only geometry-adjacent tool
is `PKToolPickerRulerItem` (a straight-edge drawing aid), not shape
recognition. So Phase 7 implements a custom heuristic, per the plan's
fallback instructions:

- **Hold/pause detection** (`PencilCanvasView.Coordinator`): a real
  wall-clock debounce timer (`DispatchQueue.main.asyncAfter`, 0.4s),
  reset on every `canvasViewDrawingDidChange`. The first implementation
  tried inferring a "hold" purely from the stroke's own recorded
  `PKStrokePoint.timeOffset`/`location` data (whether trailing points
  stayed still) — on-device testing showed this was unreliable, because
  PencilKit doesn't reliably keep generating new points while the Pencil
  is genuinely stationary, so the data the detector needed often just
  wasn't there. A real timer that fires only once drawing has *actually*
  stopped changing for the debounce window is what the plan's fallback
  wording ("a stroke-end-plus-pause gesture") describes, and it doesn't
  depend on PencilKit's internal point-sampling behavior at all.
- **Classification** (`ShapeClassifier`): pure geometry over `[CGPoint]`.
  Closed vs. open is decided by how close the stroke's start and end
  points are relative to its bounding-box diagonal. Open strokes with low
  max-deviation from the straight line between their endpoints become
  `.line`. Closed strokes are split into `.rectangle` vs. `.ellipse` by
  comparing the polygon's enclosed area (shoelace formula) against its
  bounding-box area — a rectangle drawn roughly still fills most of its
  bounding box, while a circle/ellipse fills ~78.5% (π/4) of it, giving a
  clean, well-separated threshold between the two. A minimum bounding-box
  *diagonal* (not width/height independently, since a genuine straight
  line can be arbitrarily thin in one axis) filters out handwriting-scale
  loops (e.g. a lowercase "o") from being misread as intentional shapes.
- **Fitting** (`ShapePathBuilder`): converts the classified shape into a
  clean `PKStrokePath` (line: 2-point path; rectangle: the 4 bounding-box
  corners; ellipse: a sampled circle/ellipse outline in the bounding box).
- **Replacement** (`ShapeSnapService` + `PencilCanvasView.Coordinator`):
  once the debounce timer fires without being cancelled by further
  drawing, the still-current last stroke is evaluated once (tracked by
  `PKStroke.id` to avoid reprocessing); if it qualifies, it's swapped
  in-place in `canvasView.drawing.strokes` for the fitted
  version, preserving the original ink/tool/color.

Applies to any inking stroke drawn (pen or highlighter), not restricted
by tool — Phase 8/9's stroke-model/tagging work will need to decide
separately how shape-snapped strokes are tagged for handwriting
recognition exclusion (per the build plan, shape-snapped strokes must
never reach the recognizer), since that persisted tagging model doesn't
exist yet at this phase.

## Stroke capture: a decoupled model layer over `PKDrawing`, not a duplicate store

Phase 8 adds `CapturedStroke`/`StrokeGroup` (`Core/Models`) and
`StrokeCaptureService` (`Core/Services`) as the abstraction non-canvas
code (recognition, positioning, persistence) reads strokes through,
rather than reaching into `PKDrawing`/`PKStroke` directly. It derives
data from the live drawing on demand (`PKStroke.renderBounds` for the
bounding box, `PKStrokePath`'s creation date for the timestamp, point
locations from the stroke's own path) instead of keeping a second,
independently-updated copy of stroke geometry — `PKDrawing` stays the
single source of truth.

This is also where the `.shape` gap noted above gets closed:
`StrokeTool.from(_:isShapeSnapped:)` now takes an explicit
shape-snapped flag rather than relying solely on `PKInkType`, since a
shape-snapped stroke keeps its original ink type after
`ShapeSnapService` replaces its path — ink type alone can't distinguish
it from a normal pen stroke. The caller (wired into the canvas
coordinator in a later phase) is expected to pass the same
`snappedStrokeIDs` set `PencilCanvasView.Coordinator` already tracks
internally for shape-selection.

`StrokeCaptureService.group(_:)` clusters captured strokes into lines by
vertical bounding-box overlap (with a small tolerance for natural
baseline/height variance), sorted top-to-bottom then left-to-right
within each line. This is deliberately simple spatial grouping, not
full line/word segmentation — it exists so Phase 12 (text positioning)
has a starting structure to build on rather than reinventing grouping
from scratch, without trying to solve positioning itself here.

## Handwriting recognition: thin actor wrapper over `PKStrokeRecognizer`

Phase 9 wraps `PKStrokeRecognizer` (Section 3 of the build plan) behind
`HandwritingRecognitionService` (`Features/Recognition`) rather than
using the SDK type directly wherever recognition is needed — the same
swappable-backend reasoning the plan calls for.
`PKStrokeRecognitionService` is a thin actor forwarding to the real
recognizer 1:1; there's nothing to add on top since the SDK type
already matches the protocol's shape almost exactly.

Pen-only filtering (never highlighter or shape-snapped strokes) is a
separate concern from the recognition service itself:
`PenStrokeFilter.penStrokeIDs(in:)` takes the `[CapturedStroke]` Phase
8's `StrokeCaptureService` produces and returns just the `.pen`-tagged
stroke IDs, which get passed into `recognizedText(strokeIDs:)`. Keeping
this out of the recognition service keeps it a pure wrapper and lets
the filtering logic be tested without touching `PKStrokeRecognizer` at
all.

"Preserve original strokes on recognition failure" falls out of the
service's design rather than needing explicit handling:
`PKStrokeRecognizer` never mutates the drawing it's given and
`recognizedText` never throws, only returns `nil` on failure — so as
long as the caller (Phase 11's wiring) doesn't delete the source
strokes until it has actual replacement text in hand, nothing is ever
lost to a failed recognition. Retrying is just calling
`recognizedText(strokeIDs:)` again; there's no failure state to reset.

## Font rendering: named fonts + an injectable availability seam

Phase 10 adds **Noteworthy** to the plan's original font list (Chalkboard
SE, Helvetica, Avenir, Georgia, Times New Roman, Courier, System, System
Rounded) — a real system font, well-suited to a handwriting app, added on
request the same way Phase 7 added arrow shapes beyond its original scope.

`AppFont` (`Features/Fonts/AppFont.swift`) maps each case to the exact
PostScript name iOS registers it under — verified against the real SDK at
runtime (`UIFont.fontNames(forFamilyName:)`) rather than assumed, since
guessing PostScript names wrong (e.g. `Avenir-Regular` instead of the
real `Avenir-Book`) fails silently by falling back to the system font
with no error.

`SystemFontAvailabilityService` (`Features/Fonts/FontAvailabilityService.swift`)
checks a font's real availability via `UIFont(name:size:)` before
resolving it to a SwiftUI `Font`, falling back to `.system` when a named
font isn't present. Every font this ships with is a stock iOS font that's
always available on-device, so the fallback path can't be exercised
against real data — the existence check is exposed as an injectable
`fontExists` closure (defaulting to the real `UIFont` lookup) purely so
the fallback logic itself has a deterministic test, per the phase's
"unit tests for the availability/fallback logic" requirement.

Weight (Light/Regular/Bold) is a second axis on top of family, and not
every family ships every weight — Noteworthy has no Regular, Georgia/
Times New Roman/Courier have no Light (confirmed against the SDK the
same way, not assumed). `AppFont.postscriptName(for:)` looks weight up
from a per-family dictionary rather than a nested switch, since the
nested-switch version tripped SwiftLint's cyclomatic complexity limit.
`FontPickerView`'s weight picker disables options the selected font
doesn't support and re-picks a valid weight on font change, rather than
silently falling back — `resolvedFont` still falls back to the family's
Regular weight (then to `.system` if the whole family is unavailable)
as a safety net, but the UI shouldn't offer a choice that visibly does
nothing.

`TextStyle` (`Core/Models/TextStyle.swift`, font + weight + size) and
`FontSettingsStore` (`Core/Services/FontSettingsStore.swift`) follow the
same placeholder pattern `NotebookStore` set in Phase 3: an in-memory
`@Observable` store wired into `AppShellView`, not persisted — Phase 17
is what makes settings survive a relaunch. The picker itself
(`FontPickerView`) is reachable now from `SettingsView` as "Default
Font," since that's the only place in the app a font+size selection
makes sense today; Phase 25 is what builds Settings out further, not
what introduces font selection into it.

## Automatic handwriting-to-text workflow: a second, independent debounce

Phase 11 wires Phases 8-10 together into the actual "write and watch it
become text" loop: `AutoRecognitionWorkflow` (`Features/Recognition/`)
composes `StrokeCaptureService` + `PenStrokeFilter` +
`HandwritingRecognitionService` into one `async` call that returns a
`RecognizedTextObject?` (`Core/Models/`) — pure data, no UIKit
dependency, so the whole pipeline is testable against synthetic
`PKDrawing` data without touching the live canvas.

`PencilCanvasView.Coordinator` schedules this on its own debounce timer
(`recognitionDebounceDelay`, 3.0s), deliberately longer than the
existing shape-snap debounce (0.4s) — a stroke that's about to become a
snapped shape shouldn't be sent to recognition in its rough, pre-snap
form first. Both timers key off the same `canvasViewDidEndUsingTool`/
`canvasViewDrawingDidChange` triggers already in place from Phase 7,
running independently.

3.0s (rather than something snappier like 0.8s, tried first) came from
on-device testing: a short debounce reliably fires mid-word, sending
isolated letter fragments to the recognizer with no surrounding word to
disambiguate against — accuracy on a lone letter is dramatically worse
than on a real word, since the model leans on lexical context. The
debounce resets on every new stroke regardless of length, so continuous
writing just keeps pushing the fire time out — only a genuine pause
this long triggers conversion, which is what lets a full word or short
phrase get written before anything is sent to recognition.

The actual recognition work happens off the main actor for free, not
because of any explicit dispatch: `PKStrokeRecognizer` is itself an
actor (Section 3 of the build plan), so `await`-ing into
`HandwritingRecognitionService` already hops off the main thread. The
`Task { @MainActor in }` wrapping the debounced work item exists for
the opposite reason — to hop *back* onto the main actor afterward, since
applying the result (removing source strokes from `canvasView.drawing`,
adding the rendered `UILabel`) touches UIKit.

On success, source strokes are only removed if every one of them is
still present in the drawing (`sourceStrokeIDs.isSubset(of:)`) — if the
user kept writing or erased something during the debounce window, the
now-stale result is discarded rather than removing strokes that no
longer match what was actually recognized. This is what "preserve
original strokes on recognition failure" (Phase 9's architecture note)
extends to in practice: strokes are only ever removed once there's a
result that's still valid for them specifically.

Rendering the recognized text is a plain `UILabel` positioned at the
source strokes' unioned bounding box, using
`FontAvailabilityService.resolvedUIFont(for:weight:size:)` (added
alongside the existing SwiftUI-facing `resolvedFont` from Phase 10, not
replacing it — the canvas layer is UIKit, the Settings picker is
SwiftUI, and both need the same underlying font resolution). This is
deliberately rough placement, not a real text-layout system — Phase 12
is what turns this into properly positioned, line-aware text, and
Phase 13 is what makes it tappable/editable rather than a static label.

### Fixing a real fragmentation bug: timer cancellation wasn't enough

On-device testing surfaced a real bug in the debounce design above: a
multi-word phrase was fragmenting into several small, garbled
conversions instead of one clean recognition, with leftover unconverted
ink remaining alongside them. Cancelling `pendingRecognitionWorkItem`
before scheduling a new one (already in place) turned out to be
necessary but not sufficient — the recognizer call itself is `async`
and can take long enough that a *second* debounce timer fires and
starts its own recognition attempt before the *first* one's call to
`recognizedText(strokeIDs:)` has even returned. Both attempts then land
and mutate the drawing, each against a different partial slice of what
had been written.

Fixed with a generation counter (`recognitionGeneration`): every
`scheduleRecognition` call increments it and captures its own value;
the async continuation checks that the counter still matches its
captured value immediately before calling `applyRecognizedText`, and
discards the result otherwise. This closes the gap timer-cancellation
alone can't — it doesn't matter how long the recognizer call takes,
only whether a newer attempt has since been scheduled.

### Settings toggle: `RecognitionSettingsStore.isAutoConvertEnabled`

A user can reasonably want to write without every stroke eventually
disappearing into text — added `RecognitionSettingsStore`
(`Core/Services/`), the same in-memory placeholder pattern as
`FontSettingsStore`/`NotebookStore`, with a single `isAutoConvertEnabled`
flag exposed as a toggle in Settings. `scheduleRecognition` checks it
before doing any work, so disabling it stops new conversions outright
without needing to touch the recognition pipeline itself.

### Fixing the fragmentation bug for real: line-scoped recognition, not a session-long recognizer

The generation-counter fix above closed one real race, but on-device
testing showed multi-word phrases were still fragmenting — a clean
phrase like "Satyam Kumar Singh how are you" was coming back as a
garbled few words with scattered, partially-erased ink left over. Two
architectural choices turned out to matter more than another timing
patch:

- **Recognizing the whole page as one flat blob of "all currently
  un-recognized pen strokes" was the wrong scope.** `AutoRecognitionWorkflow`
  now groups pen strokes into spatial lines first, using
  `StrokeCaptureService.group(_:)` — already built in Phase 8 for
  exactly this, but never actually plugged into the Phase 11 pipeline
  until now — and calls `recognizedText(strokeIDs:)` once per line
  group, producing a separate `RecognizedTextObject` per group. A bad
  recognition on one line can no longer bleed into or corrupt a
  different line, and each result's bounding box is that group's own
  (`StrokeGroup.boundingBox`), not a union spanning unrelated content.
- **A single `PKStrokeRecognizer` reused for the whole canvas session is
  conservative to avoid.** The SDK documents scoping one loaded drawing
  to multiple `strokeIDs` subsets as intended usage (confirmed via
  Apple's WWDC session on this API), but says nothing about accuracy
  across a long-lived instance fed a growing-then-shrinking drawing over
  many separate calls spread out over real time. `AutoRecognitionWorkflow`
  now takes a `makeRecognitionService` factory and constructs a fresh
  recognizer per recognition attempt instead of reusing one held by the
  `Coordinator` — cheap to construct, and removes any possibility of
  accumulated state across attempts as a variable.

`HandwritingWorkflowService.process` returns `[RecognizedTextObject]`
now (one per successfully recognized line group) instead of a single
optional, and `PencilCanvasView.Coordinator` applies each result in the
loop it gets back.

### Deleting converted text: tap-to-select, not the eraser tool

The first attempt at this used a `UIPanGestureRecognizer` restricted to
Pencil touches, tracking the eraser tool via `PKToolPickerObserver`, to
let the eraser remove text overlays the same way it removes ink. It
didn't work, and research into how PencilKit apps are built confirmed
why it couldn't reliably: `canvasView.drawingPolicy = .pencilOnly`
means `PKCanvasView` exclusively claims Pencil touches for its own
internal stroke handling, and a sibling gesture recognizer competing
for the same Pencil touches is a documented source of conflict in
PencilKit apps, not a solvable timing issue.

The fix drops the eraser angle entirely and reuses the same
tap-based pattern already proven for shape selection
(`handleDeselectTap`): converted text is a `UILabel`, a genuinely
separate view from `canvasView`, so a plain finger tap on it is never
in contention with `.pencilOnly` — that policy only governs what
canvasView itself treats as ink, not what a sibling view's own gesture
recognizer receives. Tapping a converted text object selects it (a blue
border plus a small delete button); tapping it again, tapping the
delete button, or tapping elsewhere follows the same
select/confirm/deselect shape the shape-selection overlay already
established.

### The actual fragmentation root cause: a stroke-classification bug, not timing

Every fix above (generation counter, line-scoped recognition, fresh
recognizer instances) was necessary but none of them were the actual
cause of the on-device fragmentation bug. The real bug was in
`PencilCanvasView.Coordinator.attemptSnap` (shape recognition, Phase
7): when `ShapeSnapService.snap` correctly decided a stroke was *not* a
shape, the code still called `snappedStrokeIDs.insert(lastStroke.id)`.
That set was doing two unrelated jobs at once — "don't re-run shape
detection on this stroke" and "this stroke is a shape, exclude it from
handwriting recognition" (`StrokeTool.from(_:isShapeSnapped:)` reads it
for the latter). Any ordinary letter stroke where the Pencil paused
briefly at the end — completely normal while forming letters, and
`holdDetectionDelay` is only 0.35s — got permanently misclassified as
`.shape` and silently dropped by `PenStrokeFilter` before recognition
ever ran, even though it was correctly rejected as *not* a shape and
stayed on the canvas as ordinary ink. Confirmed via on-device logging:
writing "Satyam Kumar Singh" (16 strokes) only sent 9 to the recognizer,
producing the exact garbled/fragmented symptom seen. Fixed by splitting
the guard-only concern into its own `snapEvaluatedStrokeIDs` set,
leaving `snappedStrokeIDs` to mean only "actually became a shape."

### Writing over/below converted text: `RecognizedTextLabel` hit-testing

The `UILabel` used for converted text sits above `PKCanvasView` in
`pageContainer`, and as a normal `UIView` it claims every touch inside
its frame during hit-testing — including Pencil touches — before
`canvasView` ever sees them. `.pencilOnly` only governs what
`canvasView` itself treats as ink; it has no effect on a sibling view's
hit-testing. `RecognizedTextLabel` overrides `hitTest(_:with:)` to
return `nil` whenever the touch is a Pencil touch, letting it fall
through to `canvasView` below, while finger touches still resolve
normally for tap-to-select.

### Per-line text objects, not per-paragraph, and font-derived label sizing

Two related problems showed up once real multi-line notes were tested:
tapping a text object deleted an entire paragraph at once, and the
label blocked Pencil input far beyond where the actual text sat.
Both traced to `StrokeCaptureService.group(_:)`: its "shares line" check
compares a candidate stroke against the group's own *union* bounding
box, which grows every time a stroke joins — with no ceiling, that
growing union eventually reaches into the next line too, and merging
snowballs into one group spanning a whole paragraph. (A height cap on
that union was tried and reverted — it broke ordinary letters with
larger ascenders/descenders for bigger handwriting, misreading them as
separate lines. See below for the approach that actually replaced it.)

Two independent fixes:
- The label's frame is now derived from the font size
  (`ceil(style.size * 1.25)`) with `RecognizedTextLabel` vertically
  centering the glyphs inside it, instead of `sizeToFit`'s tight box —
  keeps the hit-testable/dead-zone area predictable and proportional to
  the chosen font size regardless of the font's own metrics.
- Grouping itself was left as designed (whole-union-based, uncapped);
  what actually needed to change was scope, covered next.

### Tried and reverted: recombining strokes across recognition passes

To let writing more on an existing line extend it instead of creating a
disconnected fragment, `RecognizedTextObject` briefly gained a
`sourceStrokes: [PKStroke]` field, and new ink whose bounding box fell
within an existing line's vertical band was recombined with that line's
retained strokes and re-recognized as one unit. On-device testing
showed this reliably garbles the result (`"Satyam kumarangnyou doing."`
from writing more content next to an already-converted "Satyam Kumar
Singh") rather than cleanly extending it. This lines up with Apple's
own documented guidance on `PKStrokeRecognizer` being limited to
"throttle your calls," with nothing about feeding it a recombined or
regrown stroke set reliably across separate recognition passes.
Reverted: `HandwritingWorkflowService.process` stays a stateless
`(drawing, shapeSnappedStrokeIDs, style) -> [RecognizedTextObject]`,
and every debounce firing recognizes whatever unconverted ink currently
exists as independent line groups, same as the original design. New
writing near existing text becomes its own cleanly-recognized text
object rather than being fused into the old one's data — it still sits
on the same row visually, since it's positioned where it was actually
written.

### Selecting and moving converted text

`RecognizedTextLabel` gets a `UIPanGestureRecognizer` alongside its tap
recognizer, disabled by default so an unselected label never competes
with the page's own finger-pan-to-scroll gesture. `selectTextObject`
enables it; `deselectTextObject` disables it again. While enabled, a
finger drag repositions the label (and its delete button) live and
commits the new origin back into `RecognizedTextObject.boundingBox` via
`RecognizedTextStore.update(_:)` once the gesture ends — the same
select-then-manipulate shape the shape-selection overlay (Phase 7)
already established for snapped shapes.

### Text positioning: center-anchored placement, no size auto-scaling

Phase 11 anchored every converted line at its source strokes' bounding-box
top-left corner. `TextPositioningService` (`HandwritingTextPositioningService`)
now anchors the label frame by vertical center on the source strokes'
bounding box instead — handwriting's own ascenders/descenders extend
past a glyph's visual center, so centering tracks the written line's
position more consistently than anchoring to its raw top. Horizontal
origin stays exactly the strokes' `minX`, unchanged from Phase 11.

Tried and reverted: scaling the rendered `TextStyle.size` off each
group's stroke-bounding-box height, so bigger handwriting rendered as
bigger text. Direct product feedback after trying it on-device: the same
font-size setting producing visibly different rendered sizes depending
on how big a given line happened to be written reads as inconsistent,
not as "positioning" — rendered size should track the user's chosen
font setting only. `HandwritingTextPositioningService` always returns
`baseStyle` unchanged; only placement (the frame's origin) adapts.

`AutoRecognitionWorkflow` calls this per group before building each
`RecognizedTextObject`; `PencilCanvasView+Recognition`'s `sizeTextView`
now just applies the already-computed `boundingBox` instead of
re-deriving a height from `style.size` itself, so there's one source of
truth for a converted line's frame.

### Phase 13: real editable text, word selection, and pencil-driven replace

Converted text (`RecognizedTextLabel`, a `UILabel`) became
`RecognizedTextView`, a `UITextView` — real, selectable, copyable text
rather than a static label, per the phase's "never rasterize"
requirement. `RecognizedTextObject` gained `styleRuns: [TextRun]`
alongside its existing whole-object `style`, and `AttributedTextRenderer`
layers per-run overrides on top of the base style when building the
`NSAttributedString` actually shown — needed because font/size/weight/
color changes are scoped to *whatever's currently selected*: the whole
object on a plain tap, or just a word/range on double-tap/hold, per
direct product decision (an earlier whole-object-only design was
implemented first, then corrected once it was clear the intent was
per-word styling all along).

**The real cause of drag-to-move breaking, after several dead-end fix
attempts:** `UITextView` is a `UIScrollView` subclass and always carries
its own built-in `panGestureRecognizer` for content scrolling, present
in `gestureRecognizers` (just disabled, since `isScrollEnabled = false`)
alongside the custom pan gesture added for whole-object move.
`panGesture(on:)` picked `.first` `UIPanGestureRecognizer` without
excluding it — since the built-in one is installed before the custom one
is ever added, every enable/disable call was silently toggling the
*wrong* gesture, and the real move gesture never actually turned on.
Extensive theorizing about gesture-recognizer arbitration and
`isSelectable` timing (see below) was real and worth keeping, but this
identity-filter bug was the actual, sole reason move never worked across
every earlier attempt. Fixed by explicitly excluding
`textView.panGestureRecognizer` by reference (`!==`), not just by type.

**Word selection is deliberately not UITextView's built-in double-tap/
hold-to-select**, even though that would normally be the obvious choice.
`isSelectable = true` at rest was tried first, gated behind
`require(toFail:)` against the native double-tap/long-press gestures so
a plain single tap wouldn't misfire as the start of a double-tap. That
introduced the standard system double-tap disambiguation delay on every
single tap, which broke the natural "tap to select, then immediately
drag" gesture — the drag could begin before the delayed tap gesture had
even resolved, at which point the object was never selected in the
first place. The fix: `isSelectable` stays `false` at rest and during
whole-object (bordered) selection — full exclusivity for the custom tap/
pan gestures, no native gesture ever present to race against.
Word/range selection is instead driven by two custom gestures
(`UITapGestureRecognizer(numberOfTapsRequired: 2)` and
`UILongPressGestureRecognizer`) resolving the tapped word via
`WordBoundaryFinder` (pure, `NSString.enumerateSubstrings(.byWords)`),
then setting `isSelectable = true` and `selectedRange` explicitly —
UITextView's own selection handles, drag-to-extend, and Copy/Look Up
menu all still work natively from that point on, since `isSelectable`
being true is what actually drives them; only *how the initial word gets
picked* is custom. `isSelectable` is turned back off the moment the
selection clears (`clearActiveWordSelection`), restoring the "no
competing gesture at rest" invariant.

**The floating style/delete toolbar (`TextObjectToolbar`) is fixed at
the top-center of the screen**, not anchored to the selection — an
anchored version sat directly over the word being edited and jumped
position on every selection or scroll change, which read as cluttered.
It's a `UIHostingController` added directly to the screen's root
`UIViewController.view` (found via `UIView.parentViewController`,
climbing the responder chain) rather than to `pageContainer`, so its
position is independent of canvas pan/zoom and it renders above
everything by virtue of being the last-added direct subview at that
level — which also means a tap on it is hit-tested to it directly and
never reaches `pageContainer`'s own tap-outside-to-deselect gesture, so
that gesture no longer needs an explicit toolbar-frame exclusion check.

**Replacing text is pencil-driven, not a typed popover.** An earlier
`TextReplaceBox` (a small floating text field) was built, then dropped
per direct product direction: select a word (double-tap/hold, as above),
then write anywhere on the page with the Apple Pencil — the *next*
handwriting recognized through the normal auto-convert pipeline replaces
the selected range instead of becoming a new text object
(`Coordinator.activeWordSelection`, consumed once in
`applyRecognizedText`). This reuses the existing recognition pipeline
entirely; the only change is where the recognized text goes.

### Defaults: Noteworthy Bold and dotted pages

`TextStyle.default` is `.noteworthy` at `.bold` (Noteworthy has no
regular weight — only Light and Bold ship on-device), and new
notebooks default to `PageStyle.dotted`, both changed from this
project's original Chalkboard SE / blank defaults per direct product
preference rather than a bug fix.

## Phase 14: image insertion, and drawing ink actually on top of an image

`ImageObject` (`Core/Models/`) + `ImageObjectStore` (`Core/Services/`)
follow the exact `RecognizedTextObject`/`RecognizedTextStore` precedent
from Phase 13 rather than inventing a shared "canvas item" abstraction —
strokes, shapes, text, and now images remain four separate, parallel
mechanisms in this codebase, not variants of one sum type; unifying them
would be a bigger architectural change than any single phase has called
for. `ImageGeometry` (`Features/Images/`) is a plain, UIKit-free
`CGRect`-based struct mirroring `ShapeFit+Geometry`'s pure translate/
resize math, kept separately unit-testable the same way.

**The key design fork, and why images sit *below* `canvasView` while
converted text sits *above* it:** `RecognizedTextView` (Phase 13) solves
"let the Pencil draw near/under converted text" by sitting above
`canvasView` and passing Pencil touches through in `hitTest` — but that
means ink drawn "through" a text view's frame is actually landing on
`canvasView`, which is *behind* the text, i.e. ink renders underneath
the glyphs, not over them. That's fine for text (nobody expects to draw
literally on top of letters), but Phase 14 explicitly requires ink to be
visually paintable *on top of* an inserted image. Doing that with the
text-view trick would need the opposite of a passthrough — compositing
canvasView's ink above a view that's already above canvasView, which
isn't how UIKit layering works.

The fix: `ImageObjectView`'s image sits **below** `canvasView` in
`pageContainer` (`pageContainer.insertSubview(imageView,
belowSubview: canvasView)`), not above it like text. `canvasView` is
already transparent and already the frontmost content layer, so ink
composites on top of the image for free — no hit-test passthrough
needed for drawing at all. The tradeoff this creates: the image view can
never receive touches directly, since `canvasView` sits above it and is
hit-tested first for anything in that region. Tap-to-select is resolved
by frame-checking against `imageStore.imageObjects` inside the existing
shared `handleDeselectTap` gesture on `pageContainer` (which already
receives every tap regardless of what's hit-tested beneath it, the same
way it already excludes the shape/text selection chrome), rather than by
a gesture recognizer on the image view itself. Move and resize, once
selected, reuse `ShapeSelectionOverlayView` completely as-is (a second,
independently-owned instance) — it was already pure geometry/gesture
chrome with no shape-specific logic, driven entirely through its
`onMove`/`onResize`/`onGestureEnded` closures against a `boundingBox`,
which is exactly what an image's frame is too. That overlay is added as
a `pageContainer` subview only while an image is selected, so it's
naturally topmost and receives finger drags normally.

Resize is aspect-ratio-locked (`ImageGeometry.resized`) — a free-form
drag-to-resize, the model `ShapeFit+Geometry` uses for rectangles/
ellipses, would silently distort photos, which a plain corner handle
doesn't visually warn against.

**Deliberately not attempted:** making ink strokes drawn over an image
move together with it when the image itself is dragged. There's no
precedent for "moving one visual thing drags unrelated ink with it"
anywhere in this codebase (dragging a selected shape or text object
never carries along nearby ink either), and building stroke-to-image
attachment tracking would be new, unscoped machinery. "Ink stays
visually and positionally associated with the image" is satisfied by
both living in the same `pageContainer` coordinate space (so panning/
zooming the page moves them together, automatically) and by ink
compositing visually on top per the above — not by ink following the
image around when the image alone is repositioned.

Insertion uses `PhotosPicker` (PhotosUI, SwiftUI-native) for the photo
library and `.fileImporter` for Files — both run out-of-process and
need no `NSPhotoLibraryUsageDescription` entry, unlike the older
`PHPickerViewController`/direct `PHAsset` access this could otherwise
have required.

A `PhotosPicker` placed directly as `Menu` content doesn't reliably
present on tap — `Menu` items are expected to be simple actions, and
`PhotosPicker`'s own presentation logic doesn't fire through that. Fixed
by driving it from a plain `Button` inside the menu that flips an
`isPresentingPhotosPicker` boolean, with `.photosPicker(isPresented:)`
attached to the screen itself (`CanvasScreen.swift`) rather than nested
inside the menu.

## Shape selection: tap-to-deselect, and the bounding-box vs. geometry vs. re-entrancy bug

A shape (line/rectangle/ellipse/arrow), once auto-selected on snap,
sometimes couldn't be deselected by tapping elsewhere on the page —
tapping repeatedly did nothing. Two distinct, real bugs were involved,
and fixing only the first (though a genuine improvement) did not
resolve the reported symptom:

**Bug 1 — bounding box too generous for open shapes.**
`handleDeselectTap`'s tap-exclusion check compared the tap location
against the selected shape's full bounding box. For a rectangle or
ellipse that's fine — the box roughly matches the visible shape. For a
diagonal line or arrow, though, `ShapeFit.boundingBox` spans the two
endpoints, which for a long diagonal can cover most of the page even
though the visible ink is a thin stroke — so nearly any "tap elsewhere"
still registered as "tapping the shape." Fixed with `ShapeFit.isNear`
(`ShapeFit+Selection.swift`) and `ShapeGeometry`
(`ShapeGeometry.swift`): closed shapes (rectangle/ellipse) use
point-in-polygon against the shape's own outline, open shapes
(line/arrow) use distance-to-polyline with a small tolerance — both
generic, driven entirely by `ShapePathBuilder.controlPointLocations`, so
every current and future `ShapeFit` case gets correct hit-testing with
no shape-specific math of its own. The resize handle itself is excluded
via its own small frame (`ShapeSelectionOverlayView
.resizeHandleFrameInSuperview`), separately from the shape-geometry
check, since the handle sits outside the shape's visible outline by
design.

**Bug 2 — the actual dominant cause: a missing re-entrancy guard.**
Fixing bug 1 did not resolve the user's repeated real-device retesting
of the exact same symptom, which is what made this a genuine "the fix
should work but doesn't" case — the same situation the Phase 11 writeup
above describes, and resolved the same way: on-device `os.Logger`
diagnostics, not another guess. The logs showed `select()` being called
repeatedly on its own, with no tap in between. Cause: `attemptSnap`
writes the freshly-classified stroke into `canvasView.drawing` without
the `isApplyingSelectionUpdate` guard that every *other* similar write
in `PencilCanvasView.swift` already uses (`applySelectionUpdate` sets it
correctly). That unguarded write re-triggers PencilKit's own
`canvasViewDrawingDidChange` delegate callback, which reschedules
another snap attempt — this time on the now-mathematically-perfect
shape, which trivially reclassifies as the same shape again, calls
`select()` again, and writes the drawing again: an unguarded ~0.4s loop
that silently re-selected the shape shortly after any deselect tap,
forever, until something changed the selected stroke's identity out
from under the pending retry (which is exactly what resizing or drawing
new ink did — not a real fix, just an accidental way of breaking one
iteration of the loop). Fixed by wrapping that write in
`isApplyingSelectionUpdate = true/false` and additionally inserting the
newly-snapped stroke's own ID into `snapEvaluatedStrokeIDs` (previously
only the pre-snap original stroke's ID was ever recorded there) as a
second, defensive guard against re-evaluating an already-snapped shape.
