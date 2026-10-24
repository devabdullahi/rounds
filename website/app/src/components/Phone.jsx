import { useEffect, useRef } from 'react';
import { useOnScreen, usePrefersReducedMotion } from '../motion.js';

/* A real app recording in a clean iPhone frame. It plays only while on screen; with reduced motion
 * it shows the poster and a play button instead. `bare` drops the frame, for a screen inside a photo. */
export default function Phone({ video, poster, label, bare = false }) {
  const [ref, on] = useOnScreen();
  const reduced = usePrefersReducedMotion();
  const vid = useRef(null);
  useEffect(() => {
    const v = vid.current;
    if (!v || reduced) return;
    if (on) v.play().catch(() => {}); else v.pause();
  }, [on, reduced]);
  return (
    <figure ref={ref} className={bare ? 'phone bare' : 'phone'}>
      <video ref={vid} src={video} poster={poster} muted loop playsInline preload="none" controls={reduced}
        aria-label={label} width="300" height="650" />
    </figure>
  );
}
