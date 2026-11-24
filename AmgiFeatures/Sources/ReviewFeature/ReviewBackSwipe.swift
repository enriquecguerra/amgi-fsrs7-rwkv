#if canImport(UIKit)
import SwiftUI
import UIKit

/// Recognizes a rightward swipe from the iPhone's left screen edge.
struct ReviewBackSwipe: UIGestureRecognizerRepresentable {
    let isEnabled: Bool
    let onDismiss: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIScreenEdgePanGestureRecognizer {
        let recognizer = UIScreenEdgePanGestureRecognizer()
        recognizer.edges = .left
        recognizer.maximumNumberOfTouches = 1
        recognizer.cancelsTouchesInView = true
        recognizer.isEnabled = isEnabled
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UIScreenEdgePanGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIScreenEdgePanGestureRecognizer, context: Context) {
        guard isEnabled, recognizer.state == .ended else { return }
        let drag = recognizer.translation(in: nil)
        guard drag.x >= 64, drag.x > abs(drag.y) else { return }
        onDismiss()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let edgePan = recognizer as? UIScreenEdgePanGestureRecognizer else { return false }
            let velocity = edgePan.velocity(in: nil)
            return velocity.x > abs(velocity.y)
        }

        func gestureRecognizer(
            _ recognizer: UIGestureRecognizer,
            shouldBeRequiredToFailBy other: UIGestureRecognizer
        ) -> Bool {
            // Give the edge swipe priority over the card's scroll view.
            guard let scrollView = other.view as? UIScrollView else { return false }
            return other === scrollView.panGestureRecognizer
        }
    }
}
#endif
