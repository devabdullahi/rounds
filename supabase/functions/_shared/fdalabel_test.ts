import { assert, assertEquals } from "jsr:@std/assert@1";
import { ingredients, labelLines, mentionsAsUse, readLabel } from "./fdalabel.ts";

Deno.test("RxClass salt and hydrate entries collapse to one ingredient each", () => {
  assertEquals(
    ingredients(["moxifloxacin", "moxifloxacin hydrochloride monohydrate", "levofloxacin anhydrous", "ciprofloxacin lactate", "fosfomycin sodium", "ciprofloxacin", "azilsartan medoxomil", "amiloride ,"]),
    ["moxifloxacin", "levofloxacin", "ciprofloxacin", "fosfomycin", "azilsartan", "amiloride"],
  );
});

const cipro = {
  openfda: { route: ["ORAL"] },
  indications_and_usage: ["1 INDICATIONS AND USAGE Ciprofloxacin is indicated for ... Complicated Urinary Tract Infections and Pyelonephritis ( 1.11 )"],
  dosage_and_administration: ["Adult Dosage Guidelines Infection Dose Frequency Duration ... Complicated UTI and Pyelonephritis 500 mg every 12 hours 7 to 14 days Chronic Bacterial Prostatitis 500mg every 12 hours 28 days"],
  boxed_warning: ["WARNING: SERIOUS ADVERSE REACTIONS INCLUDING TENDINITIS, TENDON RUPTURE Fluoroquinolones, including ciprofloxacin, have been associated with..."],
};

Deno.test("a label that lists the condition gives its dose line, route and boxed warning", () => {
  const f = readLabel("ciprofloxacin", cipro, ["Pyelonephritis"]);
  assert(f.indicated);
  assertEquals(f.routes, ["oral"]);
  assert(f.dose?.startsWith("Pyelonephritis 500 mg every 12 hours 7 to 14 days"), f.dose ?? "");
  assertEquals(f.boxed, "SERIOUS ADVERSE REACTIONS INCLUDING TENDINITIS, TENDON RUPTURE");
});

Deno.test("a label that doesn't name the condition says so and has no dose line", () => {
  const f = readLabel("cefiderocol", { openfda: { route: ["INTRAVENOUS"] }, indications_and_usage: ["Hospital-acquired pneumonia"] }, ["Pyelonephritis"]);
  assertEquals([f.indicated, f.dose, f.boxed], [false, null, null]);
  assertEquals(labelLines([f]), ["cefiderocol (intravenous); label doesn't name this condition"]);
});

Deno.test("a label that names the condition only to rule it out doesn't count as listing it", () => {
  const fosfomycin = "for uncomplicated urinary tract infections in women. fosfomycin granules is not indicated for the treatment of pyelonephritis or perinephric abscess.";
  assertEquals(mentionsAsUse(fosfomycin, "pyelonephritis"), false);
  assertEquals(mentionsAsUse("complicated urinary tract infections and pyelonephritis (1.11)", "pyelonephritis"), true);
});

Deno.test("the boxed warning's section heading isn't part of its headline", () => {
  const f = readLabel("x", { boxed_warning: ["BOXED WARNING SECTION WARNING: SERIOUS ADVERSE REACTIONS Fluoroquinolones have..."] }, []);
  assertEquals(f.boxed, "SERIOUS ADVERSE REACTIONS");
});

Deno.test("a boxed warning without a capitals headline gives its first sentence", () => {
  const f = readLabel("x", { boxed_warning: ["WARNING Abnormal elevation of serum potassium can occur. It is more likely in..."] }, []);
  assertEquals(f.boxed, "Abnormal elevation of serum potassium can occur.");
});

Deno.test("a WARNINGS heading is dropped too", () => {
  const f = readLabel("x", { boxed_warning: ["WARNINGS: Hyperkalemia: Abnormal elevation of serum potassium can occur."] }, []);
  assertEquals(f.boxed, "Hyperkalemia: Abnormal elevation of serum potassium can occur.");
});

Deno.test("form words and typos in label names collapse into the drug seen first", () => {
  assertEquals(ingredients(["ciprofloxacin", "ciprofolxacin", "ciprofloxacin tablets", "ciprofloxacin hcl", "levofloxacin", "hydrochlorothiazide", "hydrocodone"]),
    ["ciprofloxacin", "levofloxacin", "hydrochlorothiazide", "hydrocodone"]);
});
