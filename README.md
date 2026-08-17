# Wrytic

Write naturally on an iPad with Apple Pencil and have your handwriting
automatically recognized and rendered as editable text — no text field, no
"convert to text" button. The canvas behaves like paper; text appears on it
automatically a short moment after the Pencil lifts, in a selected font
(default: Chalkboard SE).

Alongside that core loop, Wrytic is a small, complete note-taking app with
the everyday tools people expect — and deliberately nothing beyond that.

## Status

🚧 Early development. See the Progress Checklist in the project's internal
build plan for current phase status.

## Features

- Automatic handwriting-to-editable-text conversion, powered by
  `PKStrokeRecognizer` (PencilKit, iPadOS 27+) — no manual "convert" step
- Pen, highlighter, and eraser tools with adjustable pen size and a color
  picker
- Pencil-only drawing; finger touches scroll/pan the page, never draw
- Insert images, resize/reposition them, and write or draw on top of them
- Draw-and-hold shape recognition (rough circle/rectangle/line snaps to a
  clean version)
- Lasso/selection tool to move handwritten strokes, converted text, and
  images together
- Page styles: blank, lined, dotted, and grid — per page or per notebook
- Offline-first with Firebase sync (Firestore + Cloud Storage +
  Authentication)
- PDF export (page or full notebook) — no PDF import/annotation
- Full-text search across recognized handwriting

**Explicitly out of scope:** PDF import/annotation, audio recording.

## Tech Stack

- Swift, SwiftUI
- PencilKit (`PKCanvasView`, `PKStrokeRecognizer`)
- SwiftData (local persistence)
- Firebase: Firestore, Cloud Storage, Authentication
- PDFKit (export)
- XCTest / Swift Testing, GitHub Actions CI

## Architecture

```text
Wrytic/
├── App/                    App entry point
├── Core/
│   ├── Models/              Domain models (notebook, page, stroke, text object, …)
│   ├── Services/             Cross-feature service protocols
│   ├── Utilities/
│   └── Extensions/
├── Features/
│   ├── Home/, Notebook/, Editor/, Canvas/
│   ├── DrawingTools/        Pen/highlighter/eraser, size, color
│   ├── Shapes/               Shape recognition
│   ├── Images/                Insert/resize/annotate
│   ├── Selection/            Lasso/move
│   ├── PageStyles/           Blank/lined/dotted/grid
│   ├── Recognition/          Handwriting-to-text pipeline
│   ├── Fonts/, Search/, Export/, Settings/
├── Persistence/              Local storage (SwiftData)
└── Sync/
    ├── Firebase/
    └── SyncEngine/           Offline-first sync + conflict resolution
```

Business logic, persistence, recognition, and sync are kept out of views —
see `docs/architecture.md` for details as architectural decisions are made.

## Requirements

- Xcode 27 (beta) or later
- iPadOS 27 SDK
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the
  `.xcodeproj` from `project.yml`

## Build Instructions

```bash
brew install xcodegen   # if not already installed
xcodegen generate
open Wrytic.xcodeproj
```

Build and run the `Wrytic` scheme on an iPadOS 27 simulator or a physical
iPad. Apple Pencil features (recognition, shape-assist, pressure) require a
physical iPad + Apple Pencil — the simulator cannot exercise these
faithfully.

## Firebase Setup

Cloud sync is optional for local-only use, but required for cross-device
sync (Phase 19+):

1. Create a new project at [console.firebase.google.com](https://console.firebase.google.com).
2. Enable **Firestore**, **Cloud Storage**, and **Authentication**
   (Email/Password provider).
3. Add an iOS app to the Firebase project with bundle identifier
   `com.wrytic.app` (or your own, if you've changed it).
4. Download the generated `GoogleService-Info.plist` and place it at
   `Wrytic/App/GoogleService-Info.plist`. **This file is gitignored and
   must never be committed** — see `GoogleService-Info.example.plist` for
   the expected shape with placeholder values.

## Screenshots

_(placeholder — screenshots will be added as the UI is built out)_

## License

MIT — see [LICENSE](LICENSE).
