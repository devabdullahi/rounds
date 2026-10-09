/* Tuning surface for the Rounds site. Loaded only with ?tune (see script.js), never for visitors.
 *
 * - "Rounds" panel (DialKit): ECG, springs, flashcard timing, tilt, accent.
 * - "Hero" timeline (DialKit): the hero entrance, scrubbable.
 *
 * When something feels right, use the panel's Copy button (or read the timeline clips) and
 * move the numbers into TIMING / SPRING / ECG / TILT in script.js. This file changes nothing
 * on its own once removed. */
(function () {
  const { createDialRoot, createDialKit, createDialTimeline, createDialTimelineRoot } = window.DialKit;
  const R = window.Rounds;
  const root = document.documentElement;
  const sec = (ms) => ms / 1000;

  /* ── Live dials ─────────────────────────────────────── */

  createDialRoot({ position: "top-right", theme: "light", defaultOpen: true });
  const dials = createDialKit("Rounds", {
    ecg: {
      bpm: [R.ECG.bpm, 40, 140, 1],
      beatWidth: [R.ECG.sweep, 0.1, 0.5, 0.01],
      lineWidth: [R.ECG.lineWidth, 1, 4, 0.1],
      heroOpacity: [0.5, 0, 1, 0.05],
    },
    springs: {
      main: { type: "spring", ...R.SPRING.main },
      quick: { type: "spring", ...R.SPRING.quick },
    },
    deck: {
      _collapsed: true,
      flipAt: [R.TIMING.deckFlip, 200, 3000, 50],
      knewAt: [R.TIMING.deckKnew, 500, 5000, 50],
      advanceAt: [R.TIMING.deckAdvance, 500, 6000, 50],
      replay: { type: "action", label: "Replay flashcards" },
    },
    tilt: {
      _collapsed: true,
      maxDegrees: [R.TILT.maxDegrees, 0, 15, 0.5],
      follow: [R.TILT.follow, 0.01, 0.3, 0.01],
    },
    accent: "#029957",
  }, {
    persist: true,
    onAction: (path) => { if (path === "deck.replay") R.replayDeck(); },
  });

  // DialKit transitions can come back as a time spring, a physics spring, or an easing curve.
  function applyTransition(name, t) {
    if (t.type === "easing") {
      root.style.setProperty(`--spring-${name}`, `cubic-bezier(${t.ease.join(", ")})`);
      root.style.setProperty(`--spring-${name}-dur`, `${Math.round(t.duration * 1000)}ms`);
      return;
    }
    const { duration, css } = R.springCurve(t);
    root.style.setProperty(`--spring-${name}`, css);
    root.style.setProperty(`--spring-${name}-dur`, `${duration}ms`);
  }

  dials.subscribe((v) => {
    R.ECG.bpm = v.ecg.bpm;
    R.ECG.sweep = v.ecg.beatWidth;
    R.ECG.lineWidth = v.ecg.lineWidth;
    document.querySelectorAll('[data-ecg="ambient"].hero__ecg').forEach((c) => { c.style.opacity = v.ecg.heroOpacity; });
    applyTransition("main", v.springs.main);
    applyTransition("quick", v.springs.quick);
    R.TIMING.deckFlip = v.deck.flipAt;
    R.TIMING.deckKnew = v.deck.knewAt;
    R.TIMING.deckAdvance = v.deck.advanceAt;
    R.TILT.maxDegrees = v.tilt.maxDegrees;
    R.TILT.follow = v.tilt.follow;
    root.style.setProperty("--accent", v.accent);
  });

  /* ── Hero timeline ──────────────────────────────────── */

  const hero = document.querySelector(".hero");
  const el = (name) => hero.querySelector(`[data-hero="${name}"]`);
  const lines = [...hero.querySelectorAll("h1 .line > span")];

  // The timeline owns these elements while tuning, so their CSS transitions step aside.
  const style = document.createElement("style");
  style.textContent = `.hero [data-hero], .hero h1 .line > span { transition: none !important; }`;
  document.head.append(style);

  const spring = { type: "spring", ...R.SPRING.main };
  const rise = (at, y) => ({ at, from: { y, opacity: 0 }, to: { y: 0, opacity: 1 }, transition: spring });
  const T = R.TIMING;

  createDialTimelineRoot({ theme: "light" });
  const timeline = createDialTimeline("Hero", {
    eyebrow: rise(sec(T.eyebrow), 14),
    headline1: { at: sec(T.headline), from: { y: 105 }, to: { y: 0 }, transition: { type: "easing", duration: 0.9, ease: [0.16, 1, 0.3, 1] } },
    headline2: { at: sec(T.headline + T.headlineStep), from: { y: 105 }, to: { y: 0 }, transition: { type: "easing", duration: 0.9, ease: [0.16, 1, 0.3, 1] } },
    phone: { at: sec(T.phone), from: { y: 40, scale: 0.97, opacity: 0 }, to: { y: 0, scale: 1, opacity: 1 }, transition: spring },
    lede: rise(sec(T.lede), 14),
    ctas: rise(sec(T.lede + T.ledeStep), 14),
    note: rise(sec(T.lede + 2 * T.ledeStep), 14),
  });

  const place = (node, v, extra = "") => {
    node.style.opacity = v.opacity ?? 1;
    node.style.transform = `translateY(${v.y}px)${v.scale != null ? ` scale(${v.scale})` : ""}${extra}`;
  };

  timeline.subscribe((v) => {
    place(el("eyebrow"), v.eyebrow.current);
    lines[0].style.transform = `translateY(${v.headline1.current.y}%)`;
    lines[1].style.transform = `translateY(${v.headline2.current.y}%)`;
    place(el("phone"), v.phone.current, " perspective(1600px) rotateX(var(--tilt-x)) rotateY(var(--tilt-y))");
    place(el("lede"), v.lede.current);
    place(el("ctas"), v.ctas.current);
    place(el("note"), v.note.current);
  });
  timeline.play();
  // The recording plays on its own while tuning, as it does for visitors.
  el("phone").querySelector("video")?.play().catch(() => {});
})();
