import { useEffect, useState } from 'react';
import { useSeen, usePrefersReducedMotion } from '../motion.js';

/* ANIMATION STORYBOARD · The one proof number
 *    0ms   section enters view; the number starts at 0
 *    0ms   counts up to the target (1400ms, ease-out, so it settles instead of stopping)
 * Reduced motion and no script: the final number, still. The prerendered page shows the target. */
const TIMING = { count: 1400 };

export default function CountUp({ to, suffix = '' }) {
  const [ref, seen] = useSeen(0.15);
  const reduced = usePrefersReducedMotion();
  const [n, setN] = useState(to);
  useEffect(() => {
    if (!seen || reduced) { setN(to); return; }
    let raf;
    const t0 = performance.now();
    const tick = (t) => {
      const p = Math.min(1, (t - t0) / TIMING.count);
      setN(Math.round(to * (1 - Math.pow(1 - p, 3))));
      if (p < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [seen, reduced, to]);
  return <b ref={ref} className="count" aria-label={`${to}${suffix}`}>{n.toLocaleString('en-US')}{suffix}</b>;
}
