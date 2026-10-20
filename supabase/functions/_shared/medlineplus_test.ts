import { assert, assertEquals } from "jsr:@std/assert@1";
import { connectTopics, fits, pickTopic, plainText } from "./medlineplus.ts";

Deno.test("a topic fits when it shares a meaningful word with the condition's names", () => {
  assert(fits("Kidney Infection (Pyelonephritis)", ["Pyelonephritis"]));
  assert(fits("Migraine", ["Migraine headache"]));
  // "Kidney Diseases" is a broader page, and "infection" alone isn't a match.
  assert(!fits("Kidney Diseases", ["Pyelonephritis"]));
  assert(!fits("Urinary Tract Infections", ["Kidney infection"]));
});

const feed = { feed: { entry: [
  { title: { _value: "Kidney Diseases" }, link: [{ href: "https://medlineplus.gov/kidneydiseases.html" }], summary: { _value: "<p>You have two kidneys&amp;more.</p>" } },
  { title: { _value: "Kidney Infection (Pyelonephritis)" }, link: [{ href: "https://www.niddk.nih.gov/x" }], summary: { _value: "An overview of kidney infection." } },
] } };

Deno.test("Connect's feed reads as topics with plain-text summaries", () => {
  const topics = connectTopics(feed);
  assertEquals(topics.map((t) => [t.title, t.medlineplus]), [["Kidney Diseases", true], ["Kidney Infection (Pyelonephritis)", false]]);
  assertEquals(topics[0].summary, "You have two kidneys&more.");
});

Deno.test("the topic that fits wins over a broader MedlinePlus page", () => {
  assertEquals(pickTopic(connectTopics(feed), ["Pyelonephritis"])?.title, "Kidney Infection (Pyelonephritis)");
  assertEquals(pickTopic(connectTopics(feed), ["Gout"]), null);
});

Deno.test("HTML and entities come out of summaries", () => {
  assertEquals(plainText("<p>Pain &lt;b&gt; <b>here</b></p>"), "Pain here");
});
