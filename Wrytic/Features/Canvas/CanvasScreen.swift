import SwiftUI
import PencilKit
import PhotosUI
import UniformTypeIdentifiers

struct CanvasScreen: View {
    let notebookID: Notebook.ID
    var store: NotebookStore
    var fontSettings: FontSettingsStore
    var recognitionSettings: RecognitionSettingsStore
    @State private var canvasView = PKCanvasView()
    @State private var textStore = RecognizedTextStore()
    @State private var imageStore = ImageObjectStore()
    @State private var pendingImageInsertion: UIImage?
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var isPresentingPhotosPicker = false
    @State private var isPresentingFileImporter = false

    private var notebook: Notebook? {
        store.notebooks.first { $0.id == notebookID }
    }

    var body: some View {
        PencilCanvasView(
            canvasView: $canvasView,
            pageStyle: notebook?.pageStyle ?? .dotted,
            fontSettings: fontSettings,
            recognitionSettings: recognitionSettings,
            textStore: textStore,
            imageStore: imageStore,
            pendingImageInsertion: $pendingImageInsertion
        )
            .ignoresSafeArea()
            .navigationTitle(notebook?.name ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("canvasScreen")
            .toolbar {
                ToolbarItem {
                    Menu {
                        ForEach(PageStyle.allCases) { style in
                            Button(style.displayName) {
                                store.updateStyle(for: notebookID, style: style)
                            }
                        }
                    } label: {
                        Label("Page Style", systemImage: "square.grid.2x2")
                    }
                    .accessibilityIdentifier("pageStyleMenu")
                }
                ToolbarItem {
                    Menu {
                        // A PhotosPicker placed directly as Menu content
                        // doesn't reliably present on tap — Menu items are
                        // expected to be simple actions, and PhotosPicker's
                        // own presentation logic doesn't fire through that.
                        // Driving it from a plain Button + isPresented
                        // binding on the screen itself is what actually
                        // works.
                        Button {
                            isPresentingPhotosPicker = true
                        } label: {
                            Label("Photo Library", systemImage: "photo")
                        }
                        Button {
                            isPresentingFileImporter = true
                        } label: {
                            Label("Files", systemImage: "folder")
                        }
                    } label: {
                        Label("Insert Image", systemImage: "photo.badge.plus")
                    }
                    .accessibilityIdentifier("insertImageMenu")
                }
            }
            .photosPicker(isPresented: $isPresentingPhotosPicker, selection: $photosPickerItem, matching: .images)
            .onChange(of: photosPickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        pendingImageInsertion = image
                    }
                    photosPickerItem = nil
                }
            }
            .fileImporter(isPresented: $isPresentingFileImporter, allowedContentTypes: [.image]) { result in
                guard let url = try? result.get() else { return }
                let didAccess = url.startAccessingSecurityScopedResource()
                defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    pendingImageInsertion = image
                }
            }
    }
}
