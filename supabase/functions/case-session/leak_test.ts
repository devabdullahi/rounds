import { assertEquals } from "jsr:@std/assert@1";
import { namedDiagnoses } from "./leak.ts";

const cases: [string, string[], string[]][] = [
  ["The doctor said it might be my appendix.", ["Appendicitis"], []],
  ["Is this appendicitis?", ["Acute appendicitis", "Appendicitis"], ["Appendicitis"]],
  ["My last doctor called it an MI.", ["Myocardial infarction", "MI"], ["MI"]],
  ["Could it be a PE?", ["Pulmonary embolism", "PE"], ["PE"]],
  ["I worry about a DVT in my leg.", ["Deep vein thrombosis", "DVT"], ["DVT"]],
  ["I walk as much as I can and do PE at school.", ["Aortic stenosis", "AS"], []],
  ["It's my copd again.", ["COPD"], ["COPD"]],
  ["Mike says hi.", ["MI"], []],
  ["I typed it up.", ["PE"], []],
];

for (const [reply, names, want] of cases) {
  Deno.test(`leak check: ${JSON.stringify(reply)}`, () => assertEquals(namedDiagnoses(reply, names), want));
}
