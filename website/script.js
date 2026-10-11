/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Rounds website
 *
 * Tuning: open the page with ?tune on a local server (localhost / 127.0.0.1) or from a
 * file for live dials and a scrubbable hero timeline (tune.js, DialKit). Copy tuned values
 * back into TIMING / SPRING / ECG below. Deployed, ?tune does nothing.
 *
 * HERO (on load)
 *     0ms   ECG traces start sweeping (continuous, paused off-screen)
 *   100ms   eyebrow rises, y 14 → 0
 *   180ms   headline lines slide up from their masks (stagger 110ms)
 *   520ms   lede, buttons, note rise (stagger 80ms)
 *   420ms   phone rises, y 40 → 0, scale 0.97 → 1 (spring); the app recording plays
 *           (real screen capture, looping, paused whenever it's off-screen)
 *
 * SCROLL (each plays once, when 25% is in view)
 *   patient copy     rows rise (stagger 90ms)
 *   debrief phone    lifts in, then its recording starts
 *   case path        ECG line draws (1600ms); each step pops as the line reaches it
 *   hero phone       tilts toward the pointer, max 5° (desktop, fine pointer only)
 *   flashcards       deck lifts → flips at 900ms → "Knew it" at 2600ms →
 *                    card swipes away at 3000ms, next card steps up
 *
 * Reduced motion: everything rests in its final state; ECG is drawn still; recordings
 * show their last frame with a Play button instead of autoplaying.
 * ───────────────────────────────────────────────────────── */

const TIMING = {
  eyebrow:      100,   // eyebrow rises
  headline:     180,   // first headline line slides up
  headlineStep: 110,   // gap between headline lines
  phone:        420,   // phone rises
  lede:         520,   // lede, buttons, note start
  ledeStep:     80,    // gap between them
  revealStep:   90,    // stagger for scroll-revealed rows
  pathDraw:     1600,  // case-path line draws across
  pathStep:     110,   // stagger between steps where the path runs vertically (phones)
  deckFlip:     900,   // flashcard flips after the deck lands
  deckKnew:     2600,  // "Knew it" lights up
  deckAdvance:  3000,  // card swipes away, next card steps up
};

/* Springs, Motion-style: how long it looks, and how much it overshoots. Compiled into CSS
 * linear() curves at load, so every CSS transition moves on a real spring. */
const SPRING = {
  main:  { visualDuration: 0.7,  bounce: 0.18 },  // reveals, phone, deck, notes
  quick: { visualDuration: 0.28, bounce: 0.3 },   // buttons and small presses
};

const TILT = {
  maxDegrees: 5,       // phone tilt at the screen edge
  follow: 0.08,        // how quickly the tilt catches the pointer (0…1 per frame)
};

const ECG = {
  bpm: 72,             // heart rate the traces beat at
  sweep: 0.22,         // fraction of the width one beat spans
  ambientInk: "#029957",
  lineWidth: 2,
  fade: 0.35,          // fraction of the width behind the pen that fades out
  gap: 16,             // blank px ahead of the pen, where the old trace is wiped
};

const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
/* Tuning loads third-party code from a CDN, so it's for local work only: a visitor adding ?tune
 * to the live URL gets the normal page. */
const LOCAL_HOSTS = ["localhost", "127.0.0.1", "[::1]"];
const isLocal = location.protocol === "file:" || LOCAL_HOSTS.includes(location.hostname);
const tuning = isLocal && new URLSearchParams(location.search).has("tune");
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, reduceMotion ? 0 : ms));

/* ── Springs → CSS ─────────────────────────────────────── */

/* Simulates a unit spring (0 → 1) and returns its settle time and a CSS linear() curve.
 * Takes a time spring ({ visualDuration, bounce }) or a physics one ({ stiffness, damping, mass }). */
function springCurve(config) {
  const mass = config.mass ?? 1;
  let stiffness = config.stiffness, damping = config.damping;
  if (stiffness == null) {
    const root = (2 * Math.PI) / (config.visualDuration * 1.2);
    stiffness = root * root;
    damping = 2 * Math.min(1, Math.max(0.05, 1 - config.bounce)) * Math.sqrt(stiffness);
  }
  damping ??= 10;
  const dt = 1 / 240;
  let x = 0, v = 0, t = 0, still = 0;
  const samples = [0];
  while (t < 4) {
    v += ((stiffness * (1 - x) - damping * v) / mass) * dt;
    x += v * dt;
    t += dt;
    samples.push(x);
    still = Math.abs(1 - x) < 0.001 && Math.abs(v) < 0.01 ? still + dt : 0;
    if (still > 0.05) break;
  }
  const points = 48;
  const curve = Array.from({ length: points + 1 }, (_, i) => {
    const value = samples[Math.round((i / points) * (samples.length - 1))];
    return Number(value.toFixed(4));
  });
  curve[points] = 1;
  return { duration: Math.round(t * 1000), css: `linear(${curve.join(", ")})` };
}

function applySprings() {
  if (!CSS.supports("transition-timing-function", "linear(0, 1)")) return;
  const style = document.documentElement.style;
  for (const [name, config] of Object.entries(SPRING)) {
    const { duration, css } = springCurve(config);
    style.setProperty(`--spring-${name}`, css);
    style.setProperty(`--spring-${name}-dur`, `${duration}ms`);
  }
}

/* ── ECG: one PQRST beat as a function of phase 0…1 ─────── */

function beat(t) {
  const bump = (center, width, height) => height * Math.exp(-((t - center) ** 2) / (2 * width ** 2));
  return (
    bump(0.18, 0.025, 0.12) +   // P wave
    bump(0.30, 0.008, -0.12) +  // Q
    bump(0.33, 0.010, 1.0) +    // R
    bump(0.36, 0.010, -0.28) +  // S
    bump(0.58, 0.045, 0.22)     // T wave
  );
}

function startECG(canvas) {
  const ctx = canvas.getContext("2d");
  const ink = ECG.ambientInk;
  const faded = `${ink}1a`;   // the ink at 10%, for the oldest part of the trace
  let width = 0, height = 0, visible = true, last = performance.now(), pen = 0, frame = 0;

  function resize() {
    const ratio = Math.min(window.devicePixelRatio || 1, 2);
    width = canvas.clientWidth;
    height = canvas.clientHeight;
    canvas.width = Math.round(width * ratio);
    canvas.height = Math.round(height * ratio);
    ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
  }

  const y = (x) => {
    const phase = ((x / width) / ECG.sweep) % 1;
    return height * 0.62 - beat(phase) * height * 0.5;
  };

  function drawStill() {
    ctx.clearRect(0, 0, width, height);
    ctx.beginPath();
    for (let x = 0; x <= width; x += 1) x === 0 ? ctx.moveTo(x, y(x)) : ctx.lineTo(x, y(x));
    ctx.strokeStyle = ink;
    ctx.lineWidth = ECG.lineWidth;
    ctx.lineJoin = "round";
    ctx.stroke();
  }

  // A monitor sweep: the pen moves right, the trace behind it fades, the gap ahead is blank.
  function draw(now) {
    frame = requestAnimationFrame(draw);
    if (!visible || document.hidden) { last = now; return; }
    const dt = Math.min(now - last, 50) / 1000;
    last = now;
    const beatWidth = width * ECG.sweep;
    pen = (pen + beatWidth * (ECG.bpm / 60) * dt) % width;

    ctx.clearRect(0, 0, width, height);
    ctx.lineWidth = ECG.lineWidth;
    ctx.lineJoin = "round";
    // Two strokes per frame: the fresh trace up to the pen, and the older wrapped trace after
    // the blank gap. Each fades with distance behind the pen through one gradient.
    const tail = width * ECG.fade;
    const stroke = (from, to, penAt) => {
      if (to - from < 2) return;
      const fade = ctx.createLinearGradient(penAt - tail, 0, penAt, 0);
      fade.addColorStop(0, faded);
      fade.addColorStop(1, ink);
      ctx.strokeStyle = fade;
      ctx.beginPath();
      ctx.moveTo(from, y(from));
      for (let x = from + 2; x < to; x += 2) ctx.lineTo(x, y(x));
      ctx.lineTo(to, y(to));
      ctx.stroke();
    };
    stroke(0, pen, pen);
    stroke(pen + ECG.gap, width, pen + width);
    ctx.fillStyle = ink;
    ctx.beginPath();
    ctx.arc(pen, y(pen), 3, 0, Math.PI * 2);
    ctx.fill();
  }

  resize();
  window.addEventListener("resize", () => { resize(); if (reduceMotion) drawStill(); });
  if (reduceMotion) { drawStill(); return; }
  new IntersectionObserver(([entry]) => { visible = entry.isIntersecting; }).observe(canvas);
  frame = requestAnimationFrame(draw);
}

/* ── Hero ──────────────────────────────────────────────── */

async function playHero() {
  const hero = document.querySelector(".hero");
  const set = (selector, delay) => hero.querySelectorAll(selector).forEach((el) => el.style.setProperty("--d", `${delay}ms`));
  set('[data-hero="eyebrow"]', TIMING.eyebrow);
  hero.querySelectorAll("h1 .line > span").forEach((el, i) => el.style.setProperty("--d", `${TIMING.headline + i * TIMING.headlineStep}ms`));
  set('[data-hero="phone"]', TIMING.phone);
  ["lede", "ctas", "note"].forEach((name, i) => set(`[data-hero="${name}"]`, TIMING.lede + i * TIMING.ledeStep));
  requestAnimationFrame(() => hero.classList.add("is-in"));
}

/* ── Scroll reveals ────────────────────────────────────── */

function onceInView(el, play, threshold = 0.25) {
  new IntersectionObserver((entries, observer) => {
    if (!entries[0].isIntersecting) return;
    observer.disconnect();
    play(el);
  }, { threshold }).observe(el);
}

function setupReveals() {
  // Rows that share a parent stagger together.
  const groups = new Map();
  document.querySelectorAll("[data-reveal]").forEach((el) => {
    const key = el.closest("section, footer") || document.body;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(el);
  });
  groups.forEach((els) => els.forEach((el, i) => {
    el.style.setProperty("--d", `${(i % 6) * TIMING.revealStep}ms`);
    onceInView(el, (node) => node.classList.add("is-in"), 0.2);
  }));

  const path = document.querySelector("[data-path]");
  if (path) {
    const line = path.querySelector("path");
    path.style.setProperty("--len", Math.ceil(line.getTotalLength()));
    // Each step pops when the drawing line reaches it, not on a fixed stagger.
    const box = path.getBoundingClientRect();
    const across = getComputedStyle(path.querySelector(".path__line")).display !== "none";
    path.querySelectorAll("li").forEach((el, i) => {
      const reach = (el.getBoundingClientRect().left - box.left) / box.width;
      el.style.setProperty("--d", `${across ? Math.round(reach * TIMING.pathDraw * 0.7) : i * TIMING.pathStep}ms`);
    });
    onceInView(path, (el) => el.classList.add("is-in"));
  }
}

/* ── Flashcards ────────────────────────────────────────── */

let replayDeck = () => {};

function setupDeck() {
  const deck = document.querySelector("[data-deck]");
  if (!deck) return;
  const card = deck.querySelector("[data-flip]");
  const knew = deck.querySelector("[data-knew]");
  let autoplay = true;

  const flip = (flipped) => {
    card.classList.toggle("is-flipped", flipped);
    card.setAttribute("aria-pressed", String(flipped));
  };
  // A tap takes over from the demo: the visitor flips it themselves from then on.
  card.addEventListener("click", () => {
    autoplay = false;
    flip(!card.classList.contains("is-flipped"));
  });

  const play = async (el) => {
    el.classList.add("is-in");
    if (reduceMotion) return;
    await wait(TIMING.deckFlip);
    if (!autoplay) return;
    flip(true);
    await wait(TIMING.deckKnew - TIMING.deckFlip);
    if (!autoplay) return;
    knew.classList.add("is-pressed");
    await wait(TIMING.deckAdvance - TIMING.deckKnew);
    if (!autoplay) return;
    el.classList.add("is-advanced");
    knew.classList.remove("is-pressed");
  };
  onceInView(deck, play, 0.4);

  replayDeck = () => {
    autoplay = true;
    deck.classList.remove("is-advanced");
    knew.classList.remove("is-pressed");
    flip(false);
    setTimeout(() => play(deck), 700);
  };
}

/* ── App recordings ─────────────────────────────────────── */

/* Recordings play only while on screen (no decoding off-screen). With reduced motion they
 * don't autoplay: the poster (last frame) shows, with a Play button. */
function setupVideos() {
  document.querySelectorAll("[data-video]").forEach((video) => {
    const button = video.parentElement.querySelector("[data-play]");
    if (reduceMotion) {
      video.removeAttribute("loop");
      button.hidden = false;
      button.addEventListener("click", () => { button.hidden = true; video.play(); });
      video.addEventListener("ended", () => { button.hidden = false; });
      return;
    }
    new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) video.play().catch(() => { button.hidden = false; });
      else video.pause();
    }, { threshold: 0.35 }).observe(video);
    button.addEventListener("click", () => { button.hidden = true; video.play(); });
  });
}

/* ── Phone tilt ─────────────────────────────────────────── */

function setupTilt() {
  const phone = document.querySelector('[data-hero="phone"]');
  if (!phone || reduceMotion || !window.matchMedia("(hover: hover) and (pointer: fine)").matches) return;
  let target = { x: 0, y: 0 }, now = { x: 0, y: 0 }, frame = 0, ready = false;
  // Follow the pointer only once the phone has landed, and without its entrance transition,
  // so the tilt tracks the pointer directly instead of springing behind it.
  setTimeout(() => {
    phone.style.transition = "opacity 600ms ease";
    ready = true;
  }, TIMING.phone + 1200);
  const step = () => {
    now.x += (target.x - now.x) * TILT.follow;
    now.y += (target.y - now.y) * TILT.follow;
    phone.style.setProperty("--tilt-x", `${now.y.toFixed(2)}deg`);
    phone.style.setProperty("--tilt-y", `${now.x.toFixed(2)}deg`);
    frame = Math.abs(target.x - now.x) + Math.abs(target.y - now.y) > 0.01 ? requestAnimationFrame(step) : 0;
  };
  window.addEventListener("pointermove", (event) => {
    if (!ready) return;
    target = {
      x: ((event.clientX / innerWidth) - 0.5) * 2 * TILT.maxDegrees,
      y: -((event.clientY / innerHeight) - 0.5) * 2 * TILT.maxDegrees,
    };
    if (!frame) frame = requestAnimationFrame(step);
  }, { passive: true });
}

/* ── Top bar and sign-up ───────────────────────────────── */

function setupTopbar() {
  const bar = document.querySelector(".topbar");
  const update = () => bar.classList.toggle("is-scrolled", window.scrollY > 8);
  update();
  window.addEventListener("scroll", update, { passive: true });
}

applySprings();
document.querySelectorAll("[data-ecg]").forEach(startECG);
setupTopbar();
setupReveals();
setupDeck();
setupTilt();
setupVideos();

// The tuning page drives the hero from a scrubbable timeline instead. Only it needs the
// internals, so they're exposed on window only while tuning.
if (tuning) {
  window.Rounds = { TIMING, SPRING, ECG, TILT, springCurve, applySprings, playHero, replayDeck: () => replayDeck() };
  const load = (tag, attrs) => new Promise((resolve, reject) => {
    const el = Object.assign(document.createElement(tag), attrs, { onload: resolve, onerror: reject });
    document.head.append(el);
  });
  // Pinned to an exact version. TODO: add `integrity: "sha384-…"` to both CDN loads once the
  // hashes can be computed (they need the files: `curl -s URL | openssl dgst -sha384 -binary | base64`).
  Promise.all([
    load("link", { rel: "stylesheet", href: "https://unpkg.com/dialkit@2.0.0/dist/vanilla/styles.css", crossOrigin: "anonymous" }),
    load("script", { src: "https://unpkg.com/dialkit@2.0.0/dist/vanilla/browser.global.js", crossOrigin: "anonymous" }),
  ]).then(() => load("script", { src: "./tune.js" }));
} else {
  playHero();
}

// Setup finished: the CSS safety net that reveals content when this script fails can stand down.
document.documentElement.classList.add("ready");
