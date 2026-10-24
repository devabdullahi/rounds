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
        #expect(MedlinePlusHealthTopics.queries(for: "Recurrent aphthous stomatitis") == ["Recurrent aphthous stomatitis", "aphthous stomatitis", "stomatitis"])
        #expect(MedlinePlusHealthTopics.queries(for: "Streptococcal pharyngitis") == ["Streptococcal pharyngitis", "pharyngitis"])
        #expect(MedlinePlusHealthTopics.queries(for: "Birthmarks") == ["Birthmarks"])
    }

    /// Shaped like the real reply for "aphthous stomatitis": MedlinePlus ranks Fever first.
    private let looseReply = """
    <?xml version="1.0" encoding="UTF-8"?>
    <nlmSearchResult><list num="3" start="0" per="5">
      <document rank="0" url="https://medlineplus.gov/fever.html">
        <content name="title">Fever</content>
        <content name="altTitle">Pyrexia</content>
        <content name="FullSummary">A fever is a body temperature that is higher than normal.</content>
      </document>
      <document rank="1" url="https://medlineplus.gov/cankersores.html">
        <content name="title">Canker Sores</content>
        <content name="altTitle">Aphthous Ulcers</content>
        <content name="FullSummary">Canker sores are small, round sores in your mouth.</content>
      </document>
      <document rank="2" url="https://medlineplus.gov/mouthdisorders.html">
        <content name="title">Mouth Disorders</content>
        <content name="FullSummary">Your mouth is one of the most important parts of your body.</content>
      </document>
    </list></nlmSearchResult>
    """

    @Test func keepsOnlyPagesAboutTheDiagnosis() {
        let topics = MedlinePlusHealthTopics.topics(from: Data(looseReply.utf8), matching: "Recurrent aphthous stomatitis")
        #expect(topics.map(\.title) == ["Canker Sores"])
    }

    @Test("relevance comes from distinctive words, not qualifiers", arguments: [
        ("Normal pressure hydrocephalus", "Hydrocephalus", [String](), "", true),
        ("Streptococcal pharyngitis", "Sore Throat", ["Pharyngitis"], "", true),
        ("Recurrent aphthous stomatitis", "Fever", ["Pyrexia"], "A fever is a body temperature.", false),
        ("Acute disease", "Anything", [String](), "", true),
    ])
    func relevance(term: String, title: String, alts: [String], summary: String, relevant: Bool) {
        #expect(MedlinePlusHealthTopics.isRelevant(title: title, altTitles: alts, summary: summary, to: term) == relevant)
    }
}
