import SwiftUI
import UIKit

extension PencilCanvasView.Coordinator {
    /// Always fixed at the top center of the screen, not anchored to the
    /// selection — an anchored toolbar sat directly over the word being
    /// edited (and moved every time the selection or scroll position
    /// changed), which read as cluttered and covered exactly the text
    /// being worked on.
    func showToolbar(for id: UUID, replaceRange: NSRange?, in pageContainer: UIView) {
        guard let hostViewController = pageContainer.parentViewController else { return }
        toolbarHostingController?.view.removeFromSuperview()
        toolbarHostingController?.removeFromParent()

        let binding = Binding<TextStyle>(
            get: { [weak self] in
                self?.currentStyle(for: id, range: replaceRange) ?? .default
            },
            set: { [weak self] newStyle in
                self?.applyStyleChange(newStyle, to: id, range: replaceRange)
            }
        )
        let toolbar = TextObjectToolbar(
            style: binding,
            onDelete: { [weak self] in
                if let replaceRange, replaceRange.length > 0 {
                    self?.deleteRange(replaceRange, in: id)
                } else {
                    self?.deleteTextObject(id: id)
                }
            }
        )
        let hosting = UIHostingController(rootView: toolbar)
        hosting.view.backgroundColor = .clear
        hostViewController.addChild(hosting)
        hostViewController.view.addSubview(hosting.view)
        hosting.didMove(toParent: hostViewController)
        let size = hosting.view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        hosting.view.frame = topCenterFrame(size: size, in: hostViewController.view)
        toolbarHostingController = hosting
        toolbarOwnerID = id
    }

    func hideToolbarIfOwned(by id: UUID) {
        guard toolbarOwnerID == id else { return }
        toolbarHostingController?.view.removeFromSuperview()
        toolbarHostingController?.removeFromParent()
        toolbarHostingController = nil
        toolbarOwnerID = nil
    }

    private func topCenterFrame(size: CGSize, in screen: UIView) -> CGRect {
        let topInset = screen.safeAreaInsets.top + 12
        let originX = (screen.bounds.width - size.width) / 2
        return CGRect(x: originX, y: topInset, width: size.width, height: size.height)
    }

    /// The style currently shown in the toolbar: an existing per-range
    /// override if `range` falls inside one, the object's base style
    /// otherwise — matches whatever `applyStyleChange` would treat this
    /// exact selection as already having.
    private func currentStyle(for id: UUID, range: NSRange?) -> TextStyle? {
        guard let object = textStore.textObjects.first(where: { $0.id == id }) else { return nil }
        guard let range, range.length > 0 else { return object.style }
        let probe = range.location
        if let match = object.styleRuns.first(where: {
            $0.range.location <= probe && probe < $0.range.location + $0.range.length
        }) {
            return match.style
        }
        return object.style
    }

    /// `range == nil` (whole-object selection) restyles the entire object
    /// and clears any per-word overrides; a non-empty `range` (a word/text
    /// selection) only restyles that range, recorded as a `TextRun`
    /// layered on top of the object's base style.
    private func applyStyleChange(_ style: TextStyle, to id: UUID, range: NSRange?) {
        guard var object = textStore.textObjects.first(where: { $0.id == id }),
              let textView = textViewsByID[id] else { return }

        if let range, range.length > 0 {
            let newRun = TextRun(range: range, style: style)
            object.styleRuns = TextRunMerger.applying(newRun, to: object.styleRuns)
        } else {
            object.style = style
            object.styleRuns = []
        }
        textStore.update(object)
        textView.attributedText = AttributedTextRenderer.render(object, using: availabilityService)
        if let range {
            textView.selectedRange = range
        }
        resizeToFitCurrentText(textView)
        syncBoundingBox(for: id, frame: textView.frame)
    }

    /// Deleting with something selected removes just that range (via an
    /// empty-string replace) instead of the whole object — selecting one
    /// word and hitting delete previously took the entire converted line
    /// with it.
    private func deleteRange(_ range: NSRange, in id: UUID) {
        guard let object = textStore.textObjects.first(where: { $0.id == id }) else { return }
        guard let updated = TextEditCommit.replacing(range: range, in: object, with: "") else {
            deleteTextObject(id: id)
            return
        }
        applyTextReplacement(updated, id: id)
    }

    func applyTextReplacement(_ updated: RecognizedTextObject, id: UUID) {
        textStore.update(updated)
        guard let textView = textViewsByID[id] else { return }
        textView.attributedText = AttributedTextRenderer.render(updated, using: availabilityService)
        textView.selectedRange = NSRange(location: 0, length: 0)
        textView.isSelectable = false
        resizeToFitCurrentText(textView)
        syncBoundingBox(for: id, frame: textView.frame)
        hideToolbarIfOwned(by: id)
    }
}
