import Foundation
import Testing
@testable import Rounds

@Suite("MedlinePlus health topics")
struct MedlinePlusHealthTopicsTests {
    private let reply = """
    <?xml version="1.0" encoding="UTF-8"?>
    <nlmSearchResult><list num="57" start="0" per="2">
      <document rank="0" url="https://medlineplus.gov/heartattack.html">
        <content name="title">&lt;span class="qt2"&gt;Heart Attack&lt;/span&gt;</content>
        <content name="altTitle">MI</content>
        <content name="FullSummary">What is a &lt;span class="qt2"&gt;heart attack&lt;/span&gt;?&lt;p&gt;A heart attack happens when blood flow to the heart suddenly becomes blocked. Without the blood coming in, the heart can't get oxygen. If not treated quickly, the heart muscle begins to die.&lt;/p&gt;</content>
      </document>
      <document rank="1" url="https://medlineplus.gov/coronaryarterydisease.html">
        <content name="title">Coronary Artery Disease</content>
        <content name="FullSummary">Coronary artery disease is the most common type of heart disease.</content>
      </document>
    </list></nlmSearchResult>
    """

    @Test func readsPagesInRankOrderWithoutHighlightMarkup() {
        let topics = MedlinePlusHealthTopics.topics(from: Data(reply.utf8))
        #expect(topics.map(\.title) == ["Heart Attack", "Coronary Artery Disease"])
        #expect(topics.first?.url.absoluteString == "https://medlineplus.gov/heartattack.html")
    }

    @Test func summarySkipsTheQuestionHeadingAndFitsARow() {
        let summary = MedlinePlusHealthTopics.topics(from: Data(reply.utf8)).first?.summary ?? ""
        #expect(summary.hasPrefix("A heart attack happens"))
        #expect(summary.count <= MedlinePlusHealthTopics.summaryLength + 1)
        #expect(!summary.contains("<"))
    }

    @Test func dropsLeadingQualifiersWhenRetrying() {
        #expect(MedlinePlusHealthTopics.queries(for: "Recurrent aphthous stomatitis") == ["Recurrent aphthous stomatitis", "aphthous stomatitis"])
        #expect(MedlinePlusHealthTopics.queries(for: "Birthmarks") == ["Birthmarks"])
    }
}
