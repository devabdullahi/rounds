import { useOnScreen, usePrefersReducedMotion } from '../motion.js';

/* The brand's signature: a live ECG trace sweeping behind a section.
 * Motion: the trace draws left to right, then a soft "scan" glow travels it forever (6s, linear,
 * an endless loop), paused off screen. Reduced motion: the drawn trace, still. */
const BEAT = 'h110 l6 -6 l6 6 h12 l4 5 l7 -32 l7 40 l5 -13 h16 l8 -8 l8 8 h41';

export default function Ecg({ className = '' }) {
  const [ref, on] = useOnScreen();
  const reduced = usePrefersReducedMotion();
  const d = `M0 30 ${BEAT} ${BEAT} ${BEAT} ${BEAT}`;
  return (
    <svg ref={ref} className={`ecg ${className} ${on && !reduced ? 'live' : ''}`} viewBox="0 0 960 60" preserveAspectRatio="none" aria-hidden="true">
      <path d={d} className="ecg-base" pathLength="1" />
      <path d={d} className="ecg-scan" pathLength="1" />
    </svg>
  );
}
