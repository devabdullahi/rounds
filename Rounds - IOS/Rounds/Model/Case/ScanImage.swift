import Foundation

/// A real, openly licensed image that comes with an imaging result (a chest X-ray), with the
/// attribution the source's license asks us to show next to it.
struct ScanImage: Hashable, Sendable {
    let url: URL
    /// Who to credit, shown under the image.
    let credit: String
    /// How to cite the dataset the image comes from.
    let citation: String
    /// Where the image was published, for the "source" link.
    let sourceURL: URL
}
