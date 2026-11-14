// A real chest X-ray for the case, picked before the case is written so every word about the film
// (its report, the side of the exam findings) is true to the picture. The library is a private table
// of expert-labeled images (_shared/scans.ts holds the matching rules). A scan only adds a picture:
// when nothing fits, or the library can't be read, the case keeps its text-only study.
import type { CasePlan, PlannedTest } from "../_shared/casegen.ts";
import { chooseScan, isChestXray, type ScanAsset, scanFinding, type ScanWant, sideHint } from "../_shared/scans.ts";
import { scanCandidates, seenScans } from "./stores.ts";

/** Profile findings that say what's absent ("No pneumothorax", "Normal early on") describe no
 *  picture; only positive ones choose the image. */
const NEGATIVE_FINDING = /^\s*(no|normal|without|absent)\b/i;

/** Findings that cover both lungs or the whole heart: the image has no side, so the case asks for none. */
const SIDELESS = new Set(["normal", "edema", "emphysema", "cardiomegaly"]);

/** The plan's chest X-ray and the image it calls for, or null when it has no chest X-ray or its
 *  findings aren't a class the library covers. */
export function scanWant(plan: CasePlan): { test: PlannedTest; want: ScanWant } | null {
  const test = plan.tests.find((t) => t.kind === "study" && isChestXray(t.name));
  if (!test) return null;
  const positive = (test.findings ?? []).filter((f) => !NEGATIVE_FINDING.test(f));
  const finding = scanFinding(positive);
  if (!finding) return null;
  const exam = plan.exam.filter((f) => f.present).map((f) => f.finding);
  const side = SIDELESS.has(finding) ? null : sideHint([...positive, ...exam]);
  return { test, want: { finding, side, age: plan.age, sex: plan.sex === "F" ? "female" : "male" } };
}

/**
 * The plan with the image attached: the chest X-ray's findings become the image's report, sentence
 * by sentence, and the report is kept to be used word for word. Exam findings written "on the
 * affected side" name the image's side. Unchanged when there's no image, no chest X-ray, or the
 * report would name the diagnosis (`banned`, the template's leak words).
 */
export function applyScan(plan: CasePlan, asset: ScanAsset | null, banned: string[]): CasePlan {
  if (!asset) return plan;
  const report = asset.report.toLowerCase();
  if (banned.some((w) => report.includes(w))) return plan;
  const index = plan.tests.findIndex((t) => t.kind === "study" && isChestXray(t.name));
  if (index < 0) return plan;
  const tests = [...plan.tests];
  tests[index] = {
    ...tests[index],
    findings: asset.report.split(/(?<=\.)\s+/).map((s) => s.trim()).filter(Boolean),
    abnormal: asset.finding !== "normal",
    scan_report: asset.report,
    scan_asset_id: asset.id,
  };
  const side = asset.side;
  const exam = side ? plan.exam.map((f) => ({ ...f, finding: f.finding.replace(/\baffected side\b/gi, `${side} side`) })) : plan.exam;
  return { ...plan, tests, exam };
}

/** Picks and attaches an image the student hasn't seen, when one fits. Never fails the case. */
export async function attachScan(plan: CasePlan, userId: string, banned: string[], rng: () => number): Promise<CasePlan> {
  const wanted = scanWant(plan);
  if (!wanted) return plan;
  try {
    const candidates = await scanCandidates(wanted.want.finding);
    if (!candidates.length) return plan;
    return applyScan(plan, chooseScan(candidates, wanted.want, await seenScans(userId), rng), banned);
  } catch (error) {
    console.error("generate-case: scan lookup failed", (error as Error).message.slice(0, 200));
    return plan;
  }
}
