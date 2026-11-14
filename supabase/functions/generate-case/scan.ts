// A real chest X-ray for the case, picked before the case is written so every word about the film
// (its report, the side of the exam findings) is true to the picture. The library is a private table
// of expert-labeled images (_shared/scans.ts holds the matching rules). A scan only adds a picture:
// when nothing fits, or the library can't be read, the case keeps its text-only study.
import type { CasePlan, PlannedTest } from "../_shared/casegen.ts";
import {
  chooseScan,
  isChestXray,
  isPositiveFinding,
  preferredView,
  type ScanAsset,
  scanFinding,
  type ScanWant,
  sideHint,
  ZONED_FINDINGS,
  zoneHint,
} from "../_shared/scans.ts";
import { scanCandidates, seenScans } from "./stores.ts";

/** Findings that cover both lungs or the whole heart: the image has no side, so the case asks for none. */
const SIDELESS = new Set(["normal", "edema", "emphysema", "cardiomegaly"]);

/** Library images of lateral findings show one side; a case whose film is bilateral gets none. */
const BILATERAL = /\bbilateral\b|\bboth\b/i;

/** Exam findings about the chest. Only these can say which lung is involved: "right heart strain"
 *  or "right upper quadrant tenderness" name a side, but not the side of the film. */
const CHEST_EXAM = /chest|lung|breath|pleur|thora|crackle|wheez|percussion|costophrenic|\bbases?\b/i;

/** Symptoms that place the problem in the chest wall or pleura (pleuritic pain on one side). */
const CHEST_SYMPTOM = /chest|pleuritic|\bribs?\b/i;

/** The plan's chest X-ray and the image it calls for, or null when it has no chest X-ray, its
 *  findings aren't one class the library covers, or a lateral finding is on both sides. */
export function scanWant(plan: CasePlan): { test: PlannedTest; want: ScanWant } | null {
  const test = plan.tests.find((t) => t.kind === "study" && isChestXray(t.name));
  if (!test) return null;
  const findings = test.findings ?? [];
  const finding = scanFinding(findings);
  if (!finding) return null;
  const positive = findings.filter(isPositiveFinding);
  const lateral = !SIDELESS.has(finding);
  if (lateral && positive.some((f) => BILATERAL.test(f))) return null;
  const exam = plan.exam.filter((f) => f.present && CHEST_EXAM.test(`${f.region} ${f.finding}`)).map((f) => f.finding);
  const symptoms = plan.symptomsPresent.filter((s) => CHEST_SYMPTOM.test(s));
  const texts = [...positive, ...exam, ...symptoms];
  const side = lateral ? sideHint(texts) : null;
  const zone = ZONED_FINDINGS.has(finding) ? zoneHint(texts) : null;
  return {
    test,
    want: { finding, side, zone, view: preferredView(test.name), age: plan.age, sex: plan.sex === "F" ? "female" : "male" },
  };
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
    const message = error instanceof Error ? error.message : String(error);
    console.error("generate-case: scan lookup failed", message.slice(0, 200));
    return plan;
  }
}
