import { useEffect, useRef } from 'react';
import { usePrefersReducedMotion } from '../motion.js';
import Phone from './Phone.jsx';

/* ANIMATION STORYBOARD · Hero, "raise to wake" (scroll-linked; lift runs 0 → 1)
 *   lift 0.00   the hand rests low, tipped back 10° and rolled 3° around the wrist, scale 0.92;
 *               the screen is asleep on the lock screen (9:41)
 *   lift → 1    the doctor lifts it: rises, uprights and unrolls around the wrist, scale → 1
 *   lift .15–.45  a Rounds notification drops in: "New patient: Maya Ellison, 31"
 *   lift .60–.90  unlock: the lock screen zooms past and fades, the live case settles up from 0.94
 *               (the screen lags the hand, the way a phone wakes once it's raised)
 *   progress eases out, so the lift settles instead of stopping dead
 * Reduced motion and no script: lifted, unlocked, still.
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

/** The asleep phone: a lock screen whose one notification is the next patient. Decorative; the
 * notification's words match the recording underneath, so the unlock lands on that same case. */
function LockScreen() {
  return (
    <div className="lock" aria-hidden="true">
      <div className="lock-clock">
        <span className="lock-date">Friday, October 24</span>
        <span className="lock-time">9:41</span>
      </div>
      <div className="lock-note">
        <span className="lock-app"><Mark /></span>
        <span className="lock-body">
          <span className="lock-top"><b>Rounds</b><span>now</span></span>
          <b>New patient: Maya Ellison, 31</b>
          <span>Sore in her mouth for four days. She’s ready when you are.</span>
        </span>
      </div>
    </div>
  );
}

function Mark() {
  return (
    <svg viewBox="0 0 24 24" width="100%" height="100%">
      <path fill="#fff" d="M9 3.5h6a1 1 0 0 1 1 1V8h3.5a1 1 0 0 1 1 1v6a1 1 0 0 1-1 1H16v3.5a1 1 0 0 1-1 1H9a1 1 0 0 1-1-1V16H4.5a1 1 0 0 1-1-1V9a1 1 0 0 1 1-1H8V4.5a1 1 0 0 1 1-1z" />
    </svg>
  );
}

export default function HeldPhone() {
  const reduced = usePrefersReducedMotion();
  const stage = useRef(null);

  useEffect(() => {
    const el = stage.current;
    if (!el) return;
    if (reduced) { el.style.setProperty('--lift', '1'); return; }
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
            <LockScreen />
          </div>
          <img src="media/hand-v2.webp" srcSet="media/hand-v2-1120.webp 1120w, media/hand-v2.webp 1680w" sizes="(max-width: 900px) 270vw, 104vw"
            width="1680" height="921" alt="A gloved doctor's hand holding an iPhone running Rounds" />
        </div>
      </div>
    </div>
  );
}
