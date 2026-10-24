import { useState } from 'react';
import Icon from './Icon.jsx';

/* The page's centerpiece: a whole case in under a minute, the way the app runs one.
 * One layout for every step: the patient, a step rail, the chart that fills with every fact,
 * then three choices. Each answer opens under its choice; its fact lands in the chart.
 * Motion: answers and chips arrive with a calm ease-out (CSS: .reveal-in, .chip-in). */

const STEPS = [
  {
    key: 'ask', label: 'Ask', title: 'Ask Dana what’s going on', verb: 'Ask', quoted: true,
    options: [
      { icon: 'clock', label: 'When did it start?', answer: 'Two days ago. It really hurts to swallow.', fact: '2 days, painful swallowing' },
      { icon: 'thermometer', label: 'Any fever or cough?', answer: 'I’ve felt hot and shivery. No cough at all.', fact: 'Fever, no cough' },
      { icon: 'users', label: 'Anyone sick around you?', answer: 'My roommate had strep last week.', fact: 'Roommate had strep' },
    ],
  },
  {
    key: 'exam', label: 'Examine', title: 'Now examine her', verb: 'Check',
    options: [
      { icon: 'thermometer', label: 'Temperature', answer: '101.8 °F. She has a fever.', fact: '101.8 °F', abnormal: true },
      { icon: 'eye', label: 'Look in her throat', answer: 'Red, swollen tonsils with white patches.', fact: 'White patches on tonsils', abnormal: true },
      { icon: 'hand', label: 'Feel her neck', answer: 'Tender, swollen lymph nodes.', fact: 'Tender neck nodes', abnormal: true },
    ],
  },
  {
    key: 'tests', label: 'Test', title: 'Order a test', verb: 'Order',
    options: [
      { icon: 'flask', label: 'Rapid strep test', answer: 'Positive.', fact: 'Strep test +', abnormal: true },
      { icon: 'drop', label: 'Monospot', answer: 'Negative.', fact: 'Monospot −' },
      { icon: 'chart', label: 'CBC', answer: 'White count high: 13.1 ×10³/µL.', fact: 'WBC 13.1', abnormal: true },
    ],
  },
];
const DIAGNOSES = ['Strep throat', 'Viral sore throat', 'Mono'];
const ANSWER = 'Strep throat';

export default function CaseDemo() {
  const [step, setStep] = useState(0);
  const [picked, setPicked] = useState([[], [], []]);
  const [call, setCall] = useState(null);

  const facts = STEPS.flatMap((s, i) => picked[i].map((j) => ({ ...s.options[j], fresh: i === step })));
  const current = STEPS[step];
  const done = step < 3 ? picked[step].length === 3 : !!call;

  const pick = (j) => {
    if (picked[step].includes(j)) return;
    setPicked((p) => p.map((list, i) => (i === step ? [...list, j] : list)));
  };
  const restart = () => { setStep(0); setPicked([[], [], []]); setCall(null); };

  return (
    <div className="case">
      <div className="case-head">
        <span className="avatar" aria-hidden="true">DR</span>
        <div>
          <b>Dana, 24</b>
          <span>Sore throat for two days</span>
        </div>
        <span className="case-tag">Fictional patient</span>
      </div>

      <ol className="rail" aria-label="Case steps">
        {['Ask', 'Examine', 'Test', 'Diagnose'].map((s, i) => (
          <li key={s} className={i < step ? 'past' : i === step ? 'now' : ''} aria-current={i === step ? 'step' : undefined}>
            <span className="bar" />
            <span className="lbl">{i < step && <Icon name="check" size={12} />} {s}</span>
          </li>
        ))}
      </ol>

      <div className="chart" aria-live="polite">
        <div className="chart-top">
          <span>DANA’S CHART</span>
          <span>{facts.length} {facts.length === 1 ? 'fact' : 'facts'}</span>
        </div>
        {facts.length === 0 ? (
          <p className="chart-empty"><Icon name="arrowDown" size={16} /> Tap a question below. Every answer lands here.</p>
        ) : (
          <div className="chips">
            {facts.map((f) => (
              <span key={f.fact} className={`chip ${f.abnormal ? 'bad' : ''} ${f.fresh ? 'chip-in' : ''}`}>{f.fact}</span>
            ))}
          </div>
        )}
      </div>

      {step < 3 && (
        <div className="step" key={current.key}>
          <div className="step-top">
            <h3>{current.title}</h3>
            <span>{picked[step].length} of 3</span>
          </div>
          <div className="choices">
            {current.options.map((o, j) => {
              const on = picked[step].includes(j);
              return (
                <button key={o.label} type="button" className={`choice ${on ? 'on' : ''}`} onClick={() => pick(j)} aria-pressed={on}>
                  <span className="choice-row">
                    <span className="tile"><Icon name={o.icon} size={20} /></span>
                    <span className="choice-label">{o.label}</span>
                    <span className="pill">{on ? <Icon name="check" size={14} /> : current.verb}</span>
                  </span>
                  {on && <span className={`answer reveal-in ${o.abnormal ? 'bad' : ''}`}>{current.quoted ? `“${o.answer}”` : o.answer}</span>}
                </button>
              );
            })}
          </div>
        </div>
      )}

      {step === 3 && !call && (
        <div className="step">
          <div className="step-top"><h3>What does Dana have?</h3></div>
          <div className="choices">
            {DIAGNOSES.map((d) => (
              <button key={d} type="button" className="choice" onClick={() => setCall(d)}>
                <span className="choice-row"><span className="choice-label">{d}</span><span className="radio" /></span>
              </button>
            ))}
          </div>
        </div>
      )}

      {call && (
        <div className="debrief reveal-in" role="status">
          <div className="score">
            <svg viewBox="0 0 120 120" aria-hidden="true">
              <circle cx="60" cy="60" r="48" className="ring-track" />
              <circle cx="60" cy="60" r="48" className="ring-fill" style={{ strokeDashoffset: 302 * (1 - (call === ANSWER ? 0.82 : 0.61)) }} />
            </svg>
            <div><b>{call === ANSWER ? 82 : 61}</b><span>out of 100</span></div>
          </div>
          <div className="debrief-text">
            <span className="muted">Diagnosis</span>
            <b className="dx">{ANSWER}</b>
            <span className={call === ANSWER ? 'ok' : 'miss'}>
              {call === ANSWER ? <><Icon name="check" size={14} /> Your call was right</> : `You said ${call}. Fever, no cough and white patches point to strep.`}
            </span>
            <span className="fix"><b>One thing to fix:</b> ask about allergies before you treat. In the app, misses like this become flashcards.</span>
          </div>
        </div>
      )}

      <div className="case-foot">
        {step < 3 ? (
          <button type="button" className="btn" disabled={!done} onClick={() => setStep(step + 1)}>
            {['Examine Dana', 'Order tests', 'Make the call'][step]}
          </button>
        ) : (
          <button type="button" className="btn ghost" onClick={restart}>Start over</button>
        )}
      </div>
    </div>
  );
}
