# Real scans: going to the radiologist

Date: 2026-11-13 · Status: approved by the owner (plan agreed between Claude and Codex, then approved)

## Intent

Students reading a text line like "right lower lobe consolidation" don't learn to read films. Palpo should
show a **real chest X-ray** when a student orders one, the way a clerkship student walks down to radiology:
the scan on top, the radiologist's report underneath. It makes cases feel real and teaches pattern
recognition, without turning Palpo into an image quiz bank.

## Goals

- Ordering a chest X-ray in a case can open a **"Going to the radiologist"** view: real image on top
  (pinch-zoom, pan, full screen), the written report below.
- The image, the report and the rest of the case agree (side, location, finding).
- Every other imaging order (CT, ultrasound, MRI, non-chest X-rays) and every chest X-ray without a fitting
  image keeps today's text-only result.
- Ships behind a server switch that is **off by default**.

## Non-goals (MVP)

- No "what do you see?" step before the report, no image-reading score, no grading change.
- No modalities other than chest X-ray; no ECG images.
- No dataset other than NIH ChestX-ray14.
- No user uploads, ever.

## Anti-goals (failure even if it works)

- An image that contradicts the report or the exam ("left" film, "right" report).
- Any leak of the diagnosis through the image: file names, URLs, EXIF/PNG text, dataset ids, labels.
- Students learning "got an image ⇒ abnormal" or memorizing one image per condition.
- Claiming the images are radiologist-reviewed or clinically validated, or implying NIH endorses Palpo.
- Presenting a real person's scan as the fictional patient's own scan.

## Constraints

- **Source and licence.** NIH ChestX-ray14 (NIH Clinical Center): NIH states there are no restrictions on
  using the images, with attribution: link to the NIH download site, cite Wang et al., *ChestX-ray8*,
  CVPR 2017, acknowledge the NIH Clinical Center as data provider. Not usable: Radiopaedia (BY-NC-SA),
  PadChest (research only), Indiana/Open-i (BY-NC-ND), MIMIC-CXR and VinDr (PhysioNet DUAs),
  CheXpert/MURA (Stanford research terms). DeepLesion terms are unclear: excluded.
- **Policy.** CLAUDE.md now allows publicly released, de-identified teaching images from a source whose
  terms allow paid-app use (this PR). Still never PHI, never user uploads.
- **No clinician reviewer.** Nobody clinically reviews content (owner rule). Accuracy comes from expert
  labels that already exist plus automated checks; the founder spot-checks a sample as a product check.
- Architecture rules in CLAUDE.md apply: RLS, `private` schema for answers, edge functions hold privileged
  logic, View → State → Services → Backend.

## Decided (owner + Claude/Codex)

1. **Library comes only from expert-labeled subsets.** Google's radiologist-adjudicated labels (4,374
   images: pneumothorax, airspace opacity, nodule/mass, fracture; plus 810 PA images labeled for all 14
   findings and normal/abnormal) and NIH's ~1,000 radiologist bounding boxes. NLP labels alone never
   qualify an image. Target 100–300 assets.
2. **Automated gate per asset.** A vision model describes the image without seeing the label; the asset is
   kept only if its description agrees with the label (finding and side/location). Assets whose side or
   location isn't established by the expert label/box are dropped. "Normal" only from an adjudicated
   normal label, never from NIH's "No Finding" alone. Image quality is checked after resizing.
3. **Image first.** During case generation, when the case has a chest X-ray and a fitting asset exists, the
   asset is chosen **before** the report and exam details are written (by finding, age band, sex, view).
   The report and any side-specific case facts (e.g. crackles at the right base) are derived from the
   asset's curated description. No size or extent words the label doesn't support. Report text is ours.
4. **Negatives get normals.** A chest X-ray that should be unremarkable in this case gets an adjudicated
   normal image, so an image never implies an abnormal result.
5. **Rotation.** Several assets per finding; pick one the student hasn't seen when possible.
6. **UX.** "Going to the radiologist": scan on top (zoom, pan, full screen), report below. Credit is a
   small subtitle directly under each scan (owner): *"Real de-identified teaching image · NIH Clinical
   Center"*, which also makes clear it isn't this patient's own scan. Tapping it shows the rest of NIH's
   attribution (link to the NIH download site, citation of Wang et al., CVPR 2017) — Claude's call, since
   NIH asks for the link and citation too. Designed on a claude.ai Design canvas before any Swift.
7. **Storage.** Images re-encoded server-side at import (≈1024 px, metadata stripped), named by random
   UUID, in a **private** Supabase Storage bucket. Labels, source ids and provenance live in a `private`
   table. The client only ever gets a short-lived signed URL, the caption and the report.
8. **Switch.** An edge-function secret (e.g. `REAL_SCANS`) defaults off; when off, nothing changes for
   anyone. The owner accepts NIH's stated terms as the basis (2026-11-13); no written confirmation from
   NIH is sought. The switch goes on once the library and screen are ready.

## Calls made after the builder check (Claude's, owner to check)

- **Every case with a chest X-ray is eligible**, not only chest conditions. A hypernatremia case's chest
  X-ray gets an adjudicated normal image; otherwise "got an image" would mean "chest diagnosis".
- **Selection ignores the switch.** The asset is chosen at generation time whether the switch is on or off,
  and the report is derived from it either way; the switch only gates the signed URL in `order` and
  resume. So queued ready cases and cases made now show images once it's on, with no backfill.
- **The image replaces the sampled chest X-ray findings.** Selection picks the case's primary chest X-ray
  finding, then the asset's curated description is the whole report. Findings the image can't show are
  dropped from the chest X-ray (they may still appear in other tests). If sampling leaves the chest X-ray
  empty, it gets a normal image.
- **Side check only for lateral findings.** Pneumothorax, opacity/consolidation, nodule/mass, fracture,
  effusion and atelectasis need an established side. Diffuse or bilateral findings (edema, emphysema,
  cardiomegaly) qualify from the 810-image all-findings set without one, and the gate checks the finding
  only. The report never invents a side for them.
- **The plan stops at the canvas for iOS.** Backend, import and tests are planned in full; the Swift
  screen is built only after the owner picks a canvas design.
- **Google's label terms are checked first.** The Google Cloud page's "License and attribution" text for
  the expert labels couldn't be confirmed online; it's read when the labels are downloaded through the
  form. If it restricts paid-app use, the library falls back to NIH's ~1,000 radiologist-boxed images
  (8 findings, all localized) and diffuse findings drop out of the MVP. If it requires credit, the credit
  joins the tap-through attribution under each scan.

## How it fits today's code (for the builder)

- Imaging today: `supabase/functions/_shared/casegen.ts` builds each study test from `profile.imaging`
  findings (sampled by frequency); the test lands in `private.case_content.tests`; `case-session` `order`
  returns `{result, abnormal, turnaround_s}`; `resume.ts` replays results; iOS shows them in
  `Screens/Case/TestsPanel.swift` via `TestResult`.
- The image link belongs with the test inside the case's private content (asset id only). `order` and
  resume add a freshly signed URL when the test has an asset and the switch is on.
- Import pipeline: a new tool under `tools/` (Python) that downloads the NIH subset, joins expert labels,
  runs the vision gate, re-encodes, uploads, and writes the asset rows. Raw dataset files stay out of git.
- Condition → finding mapping covers chest conditions only (pneumonia, pneumothorax incl. tension,
  pleural effusion, heart failure/pulmonary edema, COPD/emphysema, lung nodule/mass, rib fracture,
  atelectasis, cardiomegaly). Everything else stays text-only.
- Ready (pre-generated) cases and live cases both go through the same selection.

## Import budget and target (owner, 2026-11-13)

- No OpenAI cost cap: quality first. The vision gate uses the strongest GPT vision model available
  (today the one used for grading/profiles), may run several independent passes per image, and covers
  every candidate in the expert-labeled subsets.
- The import writes to the live cloud project (private bucket + asset rows). Each cloud step (bucket,
  migration, upload run) is announced before it runs, per CLAUDE.md. Nothing reaches students until the
  switch is on.

## Left to the builder

- Exact table/column names, the gate's prompt and pass count, signed URL lifetime, image format (JPEG vs HEIC) and size target, rotation bookkeeping,
  the `-screen` debug names, and how side-specific facts are threaded into exam generation.
- Tests: Deno tests for selection, report derivation, signed-URL gating (switch off ⇒ no URL; other
  user's attempt ⇒ 404); RLS denied-path tests for the new table; Swift Testing for the result mapping.

## Risks the owner accepts

- NIH's terms are an FAQ statement, not a formal licence naming paid-app redistribution; no counsel review.
- Expert labels + automated gate are not clinical validation; a wrong image can slip through.
- Images reach only iOS clients; nothing changes for students until the switch is on.
