import { useMemo, useState } from 'react';
import { useSeen, usePrefersReducedMotion } from '../motion.js';

/* "When is your exam?" in miniature: pick a month and a pace, and the weeks and graded cases add
 * up the way they do in the app. Bars grow in turn (60ms apart, ease-out) whenever the pick changes. */
function upcomingMonths(n = 6) {
  const now = new Date();
  return Array.from({ length: n }, (_, k) => new Date(now.getFullYear(), now.getMonth() + k + 1, 15));
}

export default function PlanDemo() {
  const months = useMemo(() => upcomingMonths(), []);
  const [m, setM] = useState(1);
  const [pace, setPace] = useState(2);
  const [ref, seen] = useSeen(0.3);
  const reduced = usePrefersReducedMotion();
  const weeks = Math.max(1, Math.round((months[m] - new Date()) / (7 * 864e5)));
  const bars = Math.min(weeks, 16);
  return (
    <div ref={ref} className="plan">
      <div className="months" role="radiogroup" aria-label="Exam month">
        {months.map((d, k) => (
          <button key={k} type="button" role="radio" aria-checked={k === m} className={k === m ? 'on' : ''} onClick={() => setM(k)}>
            {d.toLocaleString('en-US', { month: 'short' })}
          </button>
        ))}
      </div>
      <div className="plan-num"><b>{weeks}</b> <span>weeks to go</span></div>
      <div className="bars" aria-hidden="true" key={`${m}-${bars}`}>
        {Array.from({ length: bars }, (_, k) => (
          <span key={k} className={`b ${k === 0 ? 'now' : ''} ${seen && !reduced ? 'grow' : ''}`}
            style={{ height: `${30 + (k * 70) / Math.max(bars - 1, 1)}%`, animationDelay: `${k * 60}ms` }} />
        ))}
      </div>
      <div className="pace">
        <span>Patients a day</span>
        {[1, 2, 3, 5].map((p) => (
          <button key={p} type="button" aria-pressed={p === pace} className={p === pace ? 'on' : ''} onClick={() => setPace(p)}>{p}</button>
        ))}
      </div>
      <p className="plan-out"><b>{weeks * 7 * pace}</b> graded cases by test day.</p>
    </div>
  );
}
