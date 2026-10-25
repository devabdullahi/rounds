import { useEffect, useRef } from 'react';
import { usePrefersReducedMotion } from '../motion.js';
import Phone from './Phone.jsx';

/* ANIMATION STORYBOARD · Hero, the doctor lifts the phone (scroll-linked; lift runs 0 → 1)
 *   lift 0.00   the hand rests low, tipped back 10° and rolled 3° around the wrist, scale 0.92;
 *               the app recording is already playing on the screen
 *   lift → 1    the doctor lifts it: rises, uprights and unrolls around the wrist, scale → 1
 *   progress eases out, so the lift settles instead of stopping dead
 * Phones (≤ 900px wide), reduced motion and no script: lifted and still, so the video is always
 * watchable without stopping the scroll at a particular angle (2026-10-25).
 * The scene is one photo (gloved hand, phone, chart and score cards) whose screen is cut out;
 * the real app recording plays behind that hole, so the hand holds the live app.
 * Scroll work stays off React: one rAF per scroll event writes a single CSS variable. */
const LIFT = {
  distance: 0.85,  // fraction of the viewport height scrolled to finish the lift
  rise: 14,        // % of the scene's own height it starts below its resting place
  tilt: 10,        // degrees tipped back at the start
  scale: 0.92,     // starting scale
  roll: -3,        // degrees rolled around the wrist at the start
};

/** Where the screen hole sits in media/hand-v2.webp (1680 × 921): center, size, tilt (the photo is straightened so the phone is upright). */
const SCREEN = { cx: 846.2 / 1680, cy: 388 / 921, w: 328 / 1680, h: 704 / 921, tilt: 0 };

export default function HeldPhone() {
  const reduced = usePrefersReducedMotion();
  const stage = useRef(null);

  useEffect(() => {
    const el = stage.current;
    if (!el) return;
    // On a phone the tilt made the video hard to watch mid-scroll; it stays lifted there.
    if (reduced || window.matchMedia('(max-width: 900px)').matches) { el.style.setProperty('--lift', '1'); return; }
    let raf = 0;
    const update = () => {
      raf = 0;
      const p = Math.min(1, Math.max(0, window.scrollY / (window.innerHeight * LIFT.distance)));
      el.style.setProperty('--lift', String(1 - Math.pow(1 - p, 3)));
    };
    const onScroll = () => { if (!raf) raf = requestAnimationFrame(update); };
    update();
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll);
    return () => {
      window.removeEventListener('scroll', onScroll);
      window.removeEventListener('resize', onScroll);
      cancelAnimationFrame(raf);
    };
  }, [reduced]);

  const pct = (v) => `${v * 100}%`;
  return (
    <div className="held">
      <div ref={stage} className="held-stage"
        style={{ '--rise': `${LIFT.rise}%`, '--tilt': `${LIFT.tilt}deg`, '--roll': `${LIFT.roll}deg`, '--from-scale': LIFT.scale }}>
        <div className="held-scene">
          <div className="held-screen" style={{ left: pct(SCREEN.cx), top: pct(SCREEN.cy), width: pct(SCREEN.w), height: pct(SCREEN.h), transform: `translate(-50%, -50%) rotate(${SCREEN.tilt}deg)` }}>
            <Phone bare video="media/interview.mp4" poster="media/interview.jpg" label="Recording of a student interviewing a patient in Rounds" />
          </div>
          <img src="media/hand-v2.webp" srcSet="media/hand-v2-1120.webp 1120w, media/hand-v2.webp 1680w" sizes="(max-width: 900px) 270vw, 104vw"
            width="1680" height="921" alt="A gloved doctor's hand holding an iPhone running Rounds" />
        </div>
      </div>
    </div>
  );
}
