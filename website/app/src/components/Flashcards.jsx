import { useEffect, useState } from 'react';
import { useOnScreen, usePrefersReducedMotion } from '../motion.js';
import Icon from './Icon.jsx';

/* Every miss becomes a card. The top card flips to its answer on tap (or on its own every 4s while
 * on screen), then the next card steps up. Flip: 500ms, ease-in-out, rotateY. */
const CARDS = [
  { from: 'From your misses', q: 'Sore throat and fever: what do you ask before giving penicillin?', a: 'Allergies. A penicillin allergy changes the antibiotic.' },
  { from: 'From your notes', q: 'Fever, no cough, tonsillar exudate, tender anterior nodes. What score?', a: 'Centor criteria: 4 points, so test for strep.' },
  { from: 'From any topic', q: 'Sudden worst headache of her life. First test?', a: 'Non-contrast head CT.' },
];

export default function Flashcards() {
  const [i, setI] = useState(0);
  const [flipped, setFlipped] = useState(false);
  const [ref, on] = useOnScreen();
  const reduced = usePrefersReducedMotion();
  const [touched, setTouched] = useState(false);

  useEffect(() => {
    if (!on || reduced || touched) return;
    const t = setInterval(() => {
      setFlipped((f) => {
        if (f) { setI((n) => (n + 1) % CARDS.length); return false; }
        return true;
      });
    }, 2600);
    return () => clearInterval(t);
  }, [on, reduced, touched]);

  const card = CARDS[i];
  const tap = () => {
    setTouched(true);
    if (flipped) { setFlipped(false); setI((n) => (n + 1) % CARDS.length); } else setFlipped(true);
  };
  return (
    <div ref={ref} className="deck">
      <div className="deck-back" aria-hidden="true" />
      <div className="deck-back two" aria-hidden="true" />
      <button type="button" className={`card ${flipped ? 'flipped' : ''}`} onClick={tap} aria-label={flipped ? `Answer: ${card.a}. Tap for the next card.` : `Question: ${card.q}. Tap to see the answer.`}>
        <span className="face front">
          <span className={`src ${i === 0 ? 'miss' : ''}`}>{card.from}</span>
          <b>{card.q}</b>
          <span className="hint">Tap to flip</span>
        </span>
        <span className="face back">
          <span className="src ok"><Icon name="check" size={14} /> Answer</span>
          <b>{card.a}</b>
          <span className="hint">Tap for the next card</span>
        </span>
      </button>
    </div>
  );
}
