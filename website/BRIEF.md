# Rounds website brief

A one-page marketing site for Rounds. It's an advertisement: sell the experience, keep feature copy short, and let real app recordings do the explaining. This brief describes the page as shipped (`index.html`, `styles.css`, `script.js`).

## The product in one line

**Rounds puts a fictional patient on your phone.** US medical students interview the patient, examine, order tests, commit to a diagnosis, and get graded.

- **Audience:** US medical students, MS1–MS4.
- **Goal of the page:** "I want to try this." Primary action: **Join the launch list**. The app isn't on the App Store yet, so there's no store badge.

## Rules

- Footer: "For training only. All patients are fictional. Not medical advice."
- Never write "USMLE", "NCLEX", "UWorld", "NBME" or "AMBOSS".
- **Never use orange.** Warnings are red.
- **Light mode only** (`color-scheme: light`). The accent is the app's green.
- The site sells two things: the **AI patient** and **flashcards**. No badges, rewards, streaks or Siri.

## Look and feel

**"A clinical monitor that grades you."** Modern, calm, confident, with boldness in one or two places only.

- **Signature motif:** a live **ECG trace** sweeping behind the hero and the final call to action.
- **Real app recordings** (`media/*.mp4`, with JPEG posters) in clean iPhone frames. The interview recording shows the monitor at **HR 87 · BP 113/73 · SpO₂ 97%**; copy that mentions vitals must match it.
- **Buttons:** capsule-shaped, vivid accent gradient, white text.
- Lots of whitespace and large type. No purple gradient hero, no emoji icons, not everything centred.
- Icons are Phosphor (regular), inlined as an SVG sprite. The favicon is the app's brand mark in the accent green.

### Colours (light only, from the app)

| Token | Value | Use |
|---|---|---|
| `--bg` | `#F5F6FB` | Page background |
| `--surface` | `#FFFFFF` | Cards, panels |
| `--ink` | `#161929` | Text |
| `--muted` | `#5F6271` | Secondary text (darkened from the app for 4.5:1 on `--bg`) |
| `--accent` | `#029957` | Buttons, ECG, brand mark |
| `--accent-deep` | `#017A45` | Accent as text (5.0:1 on `--bg`) |
| `--warn` | `#E5011A` | "From your mistakes", missed items |
| `--info` | `#0482C0` | SpO₂ |

### Type

- **Headlines:** Schibsted Grotesk, 700–800 weight, tight letter-spacing.
- **Body:** Hanken Grotesk.
- **Numbers and vitals:** JetBrains Mono.
- All three from Google Fonts.

## Sections

1. **Hero**
   - Eyebrow: "AI patients for US med students".
   - Headline: **"Interview the patient. Commit to the diagnosis."**
   - Lede: a fictional patient on your phone; ask anything, order the tests you'd really order, name the diagnosis, get graded by your attending.
   - Buttons: **Join the launch list** · **Meet the patient**. Note: "Coming to iPhone · Built for MS1–MS4".
   - Visual: the interview recording in a phone, ECG behind it.

2. **The patient** ("Knows only what a real patient would.")
   - Three points: talk, don't click · examine and order tests (CBC, BMP, mg/dL) · commit, then get graded.
   - The debrief recording (score, diagnosis, rating change, attending's notes, a missed red flag).
   - Case path: **Interview → Examine → Order tests → Diagnose → Debrief**, drawn as an ECG line.
   - Topic chips: hundreds of conditions, by specialty or organ system.

3. **Flashcards** ("Every miss becomes a card.")
   - An animated deck: a card from your mistakes flips to its answer, "Knew it" lights, the next card steps up. Tapping takes over.
   - Three sources: from your mistakes · from your notes · from any topic.

4. **Final call to action**
   - "Your next patient is waiting." Email field and **Join the launch list**. Until `SIGNUP_ENDPOINT` in `script.js` is set, the form says sign-ups open soon instead of pretending to save.

5. **Footer**
   - Brand, disclaimer, © 2026 Rounds.

## Motion

The storyboard and timing constants are at the top of `script.js`.

- **One page-load moment:** the ECG sweeps, the eyebrow and headline rise, the phone springs up and its recording plays.
- **On scroll, once:** rows rise, the debrief phone lifts in, the case path draws, the deck plays its flip.
- Recordings play only while on screen.
- **Reduced motion:** final states, a still ECG, and recordings show a Play button instead of autoplaying.
- If `script.js` fails, a CSS fallback reveals the content after 2s.
- `?tune` loads DialKit dials (`tune.js`), on localhost or a local file only.

## Done means

- Looks right at 390px (phone) and 1440px (desktop).
- No horizontal scrolling. Text passes 4.5:1 contrast.
- Lighthouse scores 90 or higher. Posters stay under ~160 KB.
- The launch-list form posts to a real backend before going live.
