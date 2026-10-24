import { useState } from 'react';

/* The outcome before the features: what a student gets out of Rounds for each thing they're
 * preparing for. Tabs follow the WAI-ARIA tab pattern; arrow keys move between them. */
const TABS = [
  { key: 'wards', label: 'Wards', title: 'Walk onto the rotation having seen it before.',
    body: 'Pick your rotation and work up the patients you’ll meet there, from chest pain on medicine to belly pain on surgery.',
    app: 'Filter cases by rotation, body system or care setting.' },
  { key: 'osce', label: 'OSCEs', title: 'Take the history out loud.',
    body: 'Talk to the patient the way you would in a standardized patient encounter, and hear where you lose the thread.',
    app: 'The debrief lists the key questions you skipped.' },
  { key: 'shelf', label: 'Shelf exams', title: 'Reason through it, then lock it in.',
    body: 'Every case ends with a graded debrief, and what you missed comes back as flashcards until it sticks.',
    app: 'Misses turn into cards on their own.' },
  { key: 'boards', label: 'Step 1 & 2 CK', title: 'Connect the case to the question.',
    body: 'Each debrief adds next best steps, mechanisms and complications, so the patient you just saw becomes the vignette you’ll recognize.',
    app: 'Set your exam month and a pace; Rounds counts the cases to test day.' },
];

export default function ReadyTabs() {
  const [i, setI] = useState(0);
  const onKey = (e) => {
    const d = e.key === 'ArrowRight' ? 1 : e.key === 'ArrowLeft' ? -1 : 0;
    if (!d) return;
    e.preventDefault();
    const next = (i + d + TABS.length) % TABS.length;
    setI(next);
    document.getElementById(`tab-${TABS[next].key}`)?.focus();
  };
  const t = TABS[i];
  return (
    <div className="ready">
      <div className="ready-tabs" role="tablist" aria-label="What you're preparing for" onKeyDown={onKey}>
        {TABS.map((x, k) => (
          <button key={x.key} id={`tab-${x.key}`} type="button" role="tab" aria-selected={k === i} aria-controls="ready-panel"
            tabIndex={k === i ? 0 : -1} className={k === i ? 'on' : ''} onClick={() => setI(k)}>{x.label}</button>
        ))}
      </div>
      <div className="ready-panel reveal-in" key={t.key} id="ready-panel" role="tabpanel" aria-labelledby={`tab-${t.key}`}>
        <h3>{t.title}</h3>
        <p>{t.body}</p>
        <p className="ready-app"><b>In the app:</b> {t.app}</p>
      </div>
    </div>
  );
}
