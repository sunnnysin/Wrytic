import Foundation

/// Lets `CanvasScreen` render the lasso action bar as a plain SwiftUI
/// overlay while the coordinator owns what the buttons do.
@Observable
final class LassoActionsModel {
    var isVisible = false
    @ObservationIgnored var onDuplicate: () -> Void = {}
    @ObservationIgnored var onDelete: () -> Void = {}
}
