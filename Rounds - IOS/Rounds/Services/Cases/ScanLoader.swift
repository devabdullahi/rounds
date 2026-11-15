import UIKit

/// Downloads a scan for the reading room. Its own short timeout, because a dead or expired link
/// should turn into "Try again" in seconds, not after the system's minute-long default.
enum ScanLoader {
    enum Failure: Error { case notAnImage }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    static func image(at url: URL) async throws -> UIImage {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { throw Failure.notAnImage }
        guard let image = UIImage(data: data) else { throw Failure.notAnImage }
        return image
    }
}
