import UIKit

extension UIView {
    var parentViewController: UIViewController? {
        sequence(first: self, next: { $0.next }).first { $0 is UIViewController } as? UIViewController
    }
}
