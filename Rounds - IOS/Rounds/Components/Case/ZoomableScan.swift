import SwiftUI
import UIKit

/// A scan that pinches, pans and double-taps inside its frame. The zoom lives with the caller so a
/// "reset" button elsewhere can put it back to fit.
struct ZoomableScan: View {
    let image: UIImage
    @Binding var zoom: ScanZoom
    var reduceMotion = false

    @State private var pinchBase: CGFloat?
    @State private var dragBase: CGSize?

    var body: some View {
        GeometryReader { geo in
            let film = ScanZoom.fitted(image.size, in: geo.size)
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(zoom.scale)
                .offset(zoom.offset)
                .contentShape(Rectangle())
                .gesture(pinch(film: film, in: geo.size).simultaneously(with: pan(film: film, in: geo.size)))
                .onTapGesture(count: 2) { change { zoom = zoom.toggled() } }
        }
        .clipped()
        .accessibilityElement()
        .accessibilityAddTraits(.isImage)
    }

    private func pinch(film: CGSize, in size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let base = pinchBase ?? zoom.scale
                pinchBase = base
                zoom.scale = ScanZoom.scale(base, pinched: value.magnification)
                zoom.offset = ScanZoom.clamp(zoom.offset, scale: zoom.scale, film: film, in: size)
            }
            .onEnded { _ in pinchBase = nil }
    }

    private func pan(film: CGSize, in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard zoom.scale > 1 else { return }
                let base = dragBase ?? zoom.offset
                dragBase = base
                let moved = CGSize(width: base.width + value.translation.width, height: base.height + value.translation.height)
                zoom.offset = ScanZoom.clamp(moved, scale: zoom.scale, film: film, in: size)
            }
            .onEnded { _ in dragBase = nil }
    }

    private func change(_ body: () -> Void) {
        if reduceMotion { body() } else { withAnimation(Springs.slide, body) }
    }
}
