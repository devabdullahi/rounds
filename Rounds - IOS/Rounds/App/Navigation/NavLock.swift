import SwiftUI

extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
        // iOS 26 also pops on a swipe anywhere in the content, not just from the edge.
        if #available(iOS 26.0, *) { interactiveContentPopGestureRecognizer?.delegate = self }
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1 && !NavLock.isLocked
    }
}

/// Past a point of no return (submitted diagnosis) swipe-back is off. Set from the case's
/// navigation path, not per screen: per-screen appear/disappear pairs overlap during a push, and
/// the screen being left would unlock the one arriving.
enum NavLock {
    nonisolated(unsafe) static var isLocked = false
}
