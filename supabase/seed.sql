-- Local development seed: one scripted case (Bed B4) and a sample flashcard deck.
-- Sample content written for the screens phase; clinician review pending.

insert into public.cases (id, specialty, patient_name, age, sex, quote, complaint, vitals, budget, minutes, published)
values (
  'B4', 'Cardiology', 'Mark Reyes', 54, 'M',
  'My chest has been hurting since this morning.',
  'Central chest pain that started about two hours ago while shoveling. Appears sweaty and anxious.',
  '{"hr": 104, "bp": "148/92", "spo2": 95, "rr": 20, "temp_f": 98.4, "pain": "7/10"}',
  600, 10, true
);

insert into private.case_content (case_id, facts, exam, tests, answer_key)
values (
  'B4',
  '[
    {"id": "onset", "label": "onset", "keywords": ["when", "start", "began", "onset", "how long"], "reply": "About two hours ago. I was out shoveling the driveway and it just came on.", "red_flag": false, "key_history": true},
    {"id": "site", "label": "radiation, site", "keywords": ["where", "radiat", "spread", "arm", "jaw"], "reply": "Right here, in the middle. It kinda goes down my left arm too, and up into my jaw.", "red_flag": false, "key_history": true},
    {"id": "character", "label": "character", "keywords": ["feel like", "describe", "crushing", "pressure", "sharp"], "reply": "Heavy. Like an elephant sitting on me. Not sharp.", "red_flag": false, "key_history": true},
    {"id": "associated", "label": "associated symptoms", "keywords": ["sweat", "nause", "sick", "breath", "dizz"], "reply": "I feel sick to my stomach and I''m sweating buckets. A bit short of breath.", "red_flag": false, "key_history": true},
    {"id": "risk", "label": "smoking, family history", "keywords": ["smok", "family", "father", "heart disease"], "reply": "About a pack a day, yeah. My dad had a heart attack at 60.", "red_flag": false, "key_history": true},
    {"id": "pmh", "label": "past history, meds", "keywords": ["medical history", "blood pressure", "medication", "pills"], "reply": "High blood pressure. I''m meant to take amlodipine but I forget a lot.", "red_flag": false, "key_history": true},
    {"id": "previous", "label": "previous episodes", "keywords": ["before", "previous", "first time"], "reply": "Some tightness walking uphill this past month. It went away when I stopped.", "red_flag": false, "key_history": true},
    {"id": "back", "label": "no back pain (dissection)", "keywords": ["back", "tear", "rip", "shoulder blade"], "reply": "No, nothing in my back. It''s not tearing, just heavy.", "red_flag": true, "key_history": false},
    {"id": "drugs", "label": "no cocaine", "keywords": ["cocaine", "drugs", "recreational"], "reply": "No, nothing like that. Couple of beers on the weekend.", "red_flag": true, "key_history": false}
  ]',
  '[
    {"id": "inspect", "title": "General inspection", "finding": "Pale, diaphoretic, clutching his chest. Speaking in full sentences.", "red_flag": false},
    {"id": "armbp", "title": "Compare arm blood pressures", "finding": "Right 148/92, left 146/90. No significant difference.", "red_flag": true},
    {"id": "heart", "title": "Auscultate heart", "finding": "Tachycardic, regular. Normal S1 and S2, no murmur or rub.", "red_flag": false},
    {"id": "lungs", "title": "Auscultate lungs", "finding": "Clear bilaterally. No crackles.", "red_flag": false},
    {"id": "pulses", "title": "Check peripheral pulses", "finding": "Radial and femoral pulses present and equal.", "red_flag": true},
    {"id": "legs", "title": "Examine calves", "finding": "No swelling or tenderness.", "red_flag": false}
  ]',
  '[
    {"id": "ecg", "name": "12-lead ECG", "cost": 25, "turnaround_s": 3, "result": "Sinus tachycardia 104. ST elevation in II, III, aVF with reciprocal depression in I, aVL.", "abnormal": true, "delays_care_min": 0},
    {"id": "trop", "name": "Troponin (hs)", "cost": 45, "turnaround_s": 6, "result": "312 ng/L (ref < 14). Markedly raised.", "abnormal": true, "delays_care_min": 0},
    {"id": "cxr", "name": "Chest X-ray", "cost": 80, "turnaround_s": 5, "result": "Normal mediastinal width. Clear lung fields. No pneumothorax.", "abnormal": false, "delays_care_min": 0},
    {"id": "fbc", "name": "CBC, BMP", "cost": 30, "turnaround_s": 5, "result": "Hgb 14.2 g/dL, WBC 9.1, K 4.1, creatinine 1.0 mg/dL. Unremarkable.", "abnormal": false, "delays_care_min": 0},
    {"id": "ctpa", "name": "CT pulmonary angiogram", "cost": 900, "turnaround_s": 8, "result": "No pulmonary embolism. Delayed reperfusion by 25 minutes.", "abnormal": false, "delays_care_min": 25}
  ]',
  '{
    "diagnosis": "Inferior STEMI",
    "accepted": ["stemi", "st elevation", "myocardial infarction", "heart attack", "acute coronary"],
    "plan_keywords": ["aspirin", "pci", "cath", "reperfusion", "thromboly", "cardiology"],
    "red_flags": ["back", "drugs", "armbp", "pulses"],
    "differential": ["Aortic dissection", "Pulmonary embolism", "Pericarditis"]
  }'
);

insert into public.flashcards (user_id, deck, topic, front, back) values
  (null, 'Cardiology', 'ECG', 'ST elevation in II, III and aVF points to which territory?', 'Inferior wall. Usually the right coronary artery.'),
  (null, 'Cardiology', 'Red flags', 'Tearing chest pain radiating to the back. What must you rule out?', 'Aortic dissection. Compare arm blood pressures before giving antiplatelets.'),
  (null, 'Cardiology', 'Biomarkers', 'Which troponin rise defines myocardial injury?', 'Any value above the 99th percentile upper reference limit.'),
  (null, 'Cardiology', 'Management', 'First-line reperfusion for STEMI within 12 hours?', 'Primary PCI, if it can be done within 120 minutes of first medical contact.'),
  (null, 'Cardiology', 'Exam', 'Pericardial friction rub is best heard how?', 'Patient leaning forward, breath held in expiration, left sternal edge.'),
  (null, 'Cardiology', 'Pharmacology', 'Why avoid beta-blockers in cocaine chest pain?', 'Unopposed alpha stimulation can worsen coronary vasospasm.'),
  (null, 'Cardiology', 'PE', 'Wells score above 4 for PE. Next test?', 'CT pulmonary angiogram (D-dimer only helps when probability is low).'),
  (null, 'Cardiology', 'Heart failure', 'Four drug pillars for HFrEF?', 'ACE-I/ARNI, beta-blocker, MRA, SGLT2 inhibitor.');
