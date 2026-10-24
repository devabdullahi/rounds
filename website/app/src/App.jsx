import CaseDemo from './components/CaseDemo.jsx';
import Ecg from './components/Ecg.jsx';
import Flashcards from './components/Flashcards.jsx';
import HeldPhone from './components/HeldPhone.jsx';
import Icon from './components/Icon.jsx';
import Phone from './components/Phone.jsx';
import PlanDemo from './components/PlanDemo.jsx';
import ReadyTabs from './components/ReadyTabs.jsx';
import StoreBadge from './components/StoreBadge.jsx';
import CountUp from './components/CountUp.jsx';
import { useSeen } from './motion.js';

/* One page whose only conversion is getting the app: the store badge is the hero's action and the
 * closing section's action, nothing else competes with it. In between, sections answer a skeptic's
 * questions in order: is it real (one number), what do I get (outcome tabs), what's it like
 * (feature grid), how does it work (a case to try, which doubles as an app walkthrough), what else
 * is in it (debrief, cards, plan), is it for me (rotations), and the leftover doubts (FAQ).
 * Every section is readable before any script runs; motion only adds the entrance (Reveal). */

function Reveal({ children, as: Tag = 'div', className = '', delay = 0 }) {
  const [ref, seen] = useSeen(0.15);
  return (
    <Tag ref={ref} className={`reveal ${seen ? 'in' : ''} ${className}`} style={{ transitionDelay: `${delay}ms` }}>
      {children}
    </Tag>
  );
}

function Mark({ size = 26 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" aria-hidden="true">
      <path fill="#029957" d="M9 3.5h6a1 1 0 0 1 1 1V8h3.5a1 1 0 0 1 1 1v6a1 1 0 0 1-1 1H16v3.5a1 1 0 0 1-1 1H9a1 1 0 0 1-1-1V16H4.5a1 1 0 0 1-1-1V9a1 1 0 0 1 1-1H8V4.5a1 1 0 0 1 1-1z" />
      <circle cx="12" cy="12" r="2.2" fill="#fff" />
    </svg>
  );
}

/** What makes a practice case feel real, then why it's safe to rely on. */
const FEEL = [
  { icon: 'mic', title: 'Talk or type', body: 'Ask out loud like a real encounter, or type. The patient answers in their own words.' },
  { icon: 'users', title: 'Patients who act like patients', body: 'They answer what you ask and nothing more. Nobody hands you the diagnosis.' },
  { icon: 'hand', title: 'Examine and order tests', body: 'Choose the exam, order labs and imaging, and read results in US units.' },
  { icon: 'shield', title: 'Safe to be wrong', body: 'Every patient is fictional, so the missed diagnosis happens here, not on the wards.' },
  { icon: 'book', title: 'Built on reference data', body: 'Conditions and drugs come from public data from the U.S. National Library of Medicine and openFDA.' },
  { icon: 'lock', title: 'Yours to delete', body: 'No ads, no tracking across other apps. Delete your account and its data from inside the app.' },
];
const FEEL_GROUPS = [
  { title: 'Like the real thing', items: FEEL.slice(0, 3) },
  { title: 'Safe to rely on', items: FEEL.slice(3) },
];

/** What a student does in the app at each step of a case. */
const STEPS = [
  { n: '01', title: 'Ask', body: 'Tap the mic and take the history in your own words.' },
  { n: '02', title: 'Examine', body: 'Pick the exam maneuvers. Findings land on the chart.' },
  { n: '03', title: 'Test', body: 'Order the labs and imaging you’d really order.' },
  { n: '04', title: 'Diagnose', body: 'Commit to a diagnosis and open your graded debrief.' },
];

/** The rotations students can filter cases by (the app's Clerkship list). */
const ROTATIONS = ['Internal Medicine', 'Surgery', 'Pediatrics', 'OB/GYN', 'Psychiatry', 'Family Medicine', 'Neurology', 'Emergency Medicine', 'Dermatology'];

const FAQ = [
  { q: 'Who is Rounds for?', a: 'US medical students, MS1 to MS4, getting ready for rotations, OSCEs and shelf or board exams. Anyone else who wants to practice is welcome too.' },
  { q: 'Are the patients real?', a: 'No. Every patient is fictional, written for practice. Never enter real patient information.' },
  { q: 'How is a case graded?', a: 'On the whole workup: the history you took, the exam, the tests you ordered and your diagnosis. The debrief shows the points for each part and what you missed.' },
  { q: 'Do I have to talk out loud?', a: 'No. Ask out loud like a real encounter, or type. Both work.' },
  { q: 'Is it medical advice?', a: 'No. Rounds is for training only. The patients, grades and feedback are written by AI and can be wrong, so check what you learn against your coursework.' },
  { q: 'What happens to my data?', a: 'No ads, no tracking across other apps, and you can delete your account and its data from inside the app at any time. The privacy policy has the details.' },
];

export default function App() {
  return (
    <>
      <header className="nav">
        <div className="wrap nav-in">
          <a href="#top" className="brand" aria-label="Rounds home"><Mark /> Rounds</a>
          <nav aria-label="Sections">
            <a href="#case">Try a case</a>
            <a href="#debrief">The debrief</a>
            <a href="#rotations">Rotations</a>
            <a href="#faq">FAQ</a>
          </nav>
          <a className="btn sm dark" href="#get">Get the app</a>
        </div>
      </header>

      <main id="main">
        <section className="hero" id="top">
          <div className="wrap hero-copy">
            <h1>Practice the hard calls before they’re real.</h1>
            <p className="lede">A fictional patient on your iPhone for US medical students. Take the history, make the call, and get graded like an attending would.</p>
            <StoreBadge />
          </div>
          <HeldPhone />
        </section>

        <section className="mission" aria-labelledby="mission-h">
          <div className="wrap mission-in">
            <Reveal className="mission-copy">
              <h2 id="mission-h">Clinical practice for every student and every rotation.</h2>
              <p>The patient you need to see, at whatever hour you’re studying, without waiting for a standardized patient or a shift.</p>
            </Reveal>
            <Reveal delay={120} className="big-num">
              <CountUp to={860} suffix="+" />
              <span>conditions to work up, from strep throat to aortic dissection, across 25 rotations and specialties.</span>
            </Reveal>
          </div>
        </section>

        <section className="band alt" id="ready">
          <div className="wrap stack">
            <Reveal className="stack-head">
              <h2>This is what being ready looks like.</h2>
            </Reveal>
            <Reveal delay={120}><ReadyTabs /></Reveal>
          </div>
        </section>

        <section className="band" id="feel">
          <div className="wrap feel-wrap">
            <Reveal className="feel-head">
              <h2>You’ll forget it’s practice.</h2>
              <p>It plays like a real encounter, and it’s built so you can trust it.</p>
            </Reveal>
            <div className="feel">
              {FEEL_GROUPS.map((g) => (
                <Reveal key={g.title} className="feel-group">
                  <h3 className="feel-title">{g.title}</h3>
                  <ul>
                    {g.items.map((f) => (
                      <li key={f.title}>
                        <Icon name={f.icon} size={22} />
                        <div><b>{f.title}</b><p>{f.body}</p></div>
                      </li>
                    ))}
                  </ul>
                </Reveal>
              ))}
            </div>
          </div>
        </section>

        <section className="band alt" id="case">
          <div className="wrap stack">
            <Reveal className="stack-head">
              <h2>It’s your patient.</h2>
              <p>Like a standardized patient encounter, except it’s on your phone at 2 a.m. and the only one grading you is the debrief.</p>
            </Reveal>
            <ol className="steps">
              {STEPS.map((s, k) => (
                <Reveal as="li" key={s.n} delay={k * 80}>
                  <span className="step-n">{s.n}</span>
                  <h3>{s.title}</h3>
                  <p>{s.body}</p>
                </Reveal>
              ))}
            </ol>
            <div className="split try">
              <Reveal className="split-copy">
                <h3 className="try-h">Try one right here.</h3>
                <p>Dana, 24, has had a sore throat for two days. Ask, examine, test, then make the call. Everything you learn lands on her chart.</p>
              </Reveal>
              <Reveal delay={120}><CaseDemo /></Reveal>
            </div>
          </div>
        </section>

        <section className="band" id="debrief">
          <div className="wrap split reverse">
            <Reveal className="split-copy">
              <h2>Graded on the whole workup.</h2>
              <div className="points">
                <div><Icon name="target" size={22} /><b>History, exam, tests, diagnosis</b><span>Points for each part, so you see where your score came from.</span></div>
                <div><Icon name="stethoscope" size={22} /><b>Tips for your exam</b><span>Step 2 CK next best steps, OSCE key questions, Step 1 complications.</span></div>
                <div><Icon name="cards" size={22} /><b>Misses become flashcards</b><span>The thing you forgot is the next thing you review.</span></div>
              </div>
            </Reveal>
            <Reveal delay={120} className="center">
              <Phone video="media/debrief.mp4" poster="media/debrief.jpg" label="Recording of a graded debrief in Rounds" />
            </Reveal>
          </div>
        </section>

        <section className="band alt" id="cards">
          <div className="wrap split">
            <Reveal className="center"><Flashcards /></Reveal>
            <Reveal delay={120} className="split-copy">
              <h2>Every miss becomes a card.</h2>
              <p>Cards from your mistakes, from your own notes, or from any topic. Tap the card to flip it.</p>
            </Reveal>
          </div>
        </section>

        <section className="band" id="plan">
          <div className="wrap split reverse">
            <Reveal className="split-copy">
              <h2>Know how many cases stand between you and test day.</h2>
              <p>Pick your exam month and your pace. Rounds counts the weeks and keeps you on it, a couple of patients at a time.</p>
            </Reveal>
            <Reveal delay={120}><PlanDemo /></Reveal>
          </div>
        </section>

        <section className="band alt" id="rotations">
          <div className="wrap stack">
            <Reveal className="stack-head">
              <h2>Find your next rotation.</h2>
              <p>Made for US medical school: US units, US guidelines, MS1 to MS4. Pick a rotation, a body system or a care setting.</p>
            </Reveal>
            <Reveal delay={100}>
              <ul className="rots">
                {ROTATIONS.map((r) => <li key={r}>{r}</li>)}
              </ul>
              <p className="rots-more">Plus 16 body systems, and a filter for clinic or hospital patients.</p>
              <p className="rots-note">iPhone only for now. Not on iPhone? <a href="mailto:tryroundsapp@gmail.com?subject=Rounds%20updates">Get updates by email</a>.</p>
            </Reveal>
          </div>
        </section>

        <section className="band" id="faq">
          <div className="wrap faq">
            <Reveal className="split-copy">
              <h2>Before your first patient.</h2>
            </Reveal>
            <div className="faq-list">
              {FAQ.map((f) => (
                <details key={f.q}>
                  <summary>{f.q}<span aria-hidden="true" className="plus" /></summary>
                  <p>{f.a}</p>
                </details>
              ))}
            </div>
          </div>
        </section>

        <section className="final" id="get">
          <div className="wrap final-in">
            <h2>Your next patient is waiting.</h2>
            <p>Get Rounds on your iPhone and take your first case.</p>
            <StoreBadge />
          </div>
          <Ecg className="final-ecg" />
        </section>
      </main>

      <footer className="foot">
        <div className="wrap foot-in">
          <span className="brand"><Mark size={22} /> Rounds</span>
          <span>For training only. All patients are fictional. Not medical advice.</span>
          <span><a href="privacy.html">Privacy</a> · <a href="terms.html">Terms</a> · <a href="mailto:tryroundsapp@gmail.com">Support</a> · © 2026 Rounds</span>
        </div>
        <div className="wrap legal-notes">
          <p><b>Medical disclaimer.</b> Rounds is an educational simulation for medical students. Every patient, case, finding, test result, grade and piece of feedback is fictional and written with AI, and may be inaccurate or out of date. Nothing on this site or in the app is medical advice, a diagnosis or a treatment recommendation, and it must not be used to diagnose or treat any real person, including yourself. Rounds is not responsible for any diagnosis, treatment or other decision made about a real person. In an emergency, call 911.</p>
          <p>Rounds is not a medical device and has not been reviewed by the FDA. It is not affiliated with or endorsed by any medical school, licensing board or examining organization, and its scores don't predict exam results.</p>
          <p>This product uses publicly available data from the U.S. National Library of Medicine (NLM), National Institutes of Health, Department of Health and Human Services, and drug labeling from openFDA. NLM and the FDA are not responsible for the product and do not endorse or recommend this or any other product.</p>
        </div>
      </footer>
    </>
  );
}
