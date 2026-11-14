import Foundation
import Testing
@testable import Rounds

@Suite("Scan reply decoding")
struct ScanReplyDecodingTests {
    private func order(_ json: String) throws -> TestResult {
        try LiveCaseService.decodeOrderReply(from: Data(json.utf8))
    }

    private let scanJSON = """
    {"url": "https://example.com/scan.png", "credit": "NIH Clinical Center",
     "citation": "Wang et al. 2017", "source_url": "https://nihcc.app.box.com/v/ChestXray-NIHCC"}
    """

    @Test func orderReplyWithoutScanHasNoScan() throws {
        let r = try order(#"{"result": "Clear lungs.", "abnormal": false, "turnaround_s": 5}"#)
        #expect(r.text == "Clear lungs.")
        #expect(r.isAbnormal == false)
        #expect(r.scan == nil)
    }

    @Test func orderReplyWithScanMapsEveryField() throws {
        let r = try order(#"{"result": "Opacity.", "abnormal": true, "turnaround_s": 5, "scan": \#(scanJSON)}"#)
        let scan = try #require(r.scan)
        #expect(scan.url.absoluteString == "https://example.com/scan.png")
        #expect(scan.credit == "NIH Clinical Center")
        #expect(scan.citation == "Wang et al. 2017")
        #expect(scan.sourceURL.absoluteString == "https://nihcc.app.box.com/v/ChestXray-NIHCC")
    }

    @Test(arguments: ["", "not-a-url", "http://example.com/scan.png"])
    func badImageURLDropsTheScanButKeepsTheText(_ bad: String) throws {
        let json = """
        {"result": "Opacity.", "abnormal": true,
         "scan": {"url": "\(bad)", "credit": "c", "citation": "t", "source_url": "https://example.com/s"}}
        """
        let r = try order(json)
        #expect(r.text == "Opacity.")
        #expect(r.isAbnormal)
        #expect(r.scan == nil)
    }

    @Test func resumedOrderedTestsCarryTheirScan() throws {
        let json = """
        {"attempt": {"attempt_id": "a1", "exam_mode": false, "time_limit_minutes": null,
          "started_at": "2026-11-13T10:00:00+00:00", "transcript": [], "revealed_ids": [],
          "coverage": {"got": 0, "total": 1}, "examined": [], "hidden_tests": [],
          "ordered": [{"id": "cxr", "at": "2026-11-13T10:01:00+00:00", "result": "Opacity.", "abnormal": true, "scan": \(scanJSON)},
                      {"id": "cbc", "at": "2026-11-13T10:02:00+00:00", "result": "Normal.", "abnormal": false}]}}
        """
        let attempt = try #require(try LiveCaseService.decodeResumedAttempt(from: Data(json.utf8)))
        #expect(attempt.ordered.count == 2)
        #expect(attempt.ordered[0].result.scan?.credit == "NIH Clinical Center")
        #expect(attempt.ordered[1].result.scan == nil)
    }
}
