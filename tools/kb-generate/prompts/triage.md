TRIAGE BATCH. For each condition below, decide whether it makes a good Rounds case and tag it.

A good case topic is a diagnosis a student can reach by interviewing a patient, examining them and ordering tests. Not good: broad categories ("Bone Diseases"), care topics ("Caregivers", "Treatment"), wellness topics ("Body Weight"), or things with no patient presentation.

Use only these values:
- organ_systems: cardiovascular, respiratory, gastrointestinal, renal (kidney and urinary), nervous, endocrine (includes metabolic and nutritional), blood (blood and immune, includes infections that are mainly systemic), musculoskeletal (bones, joints AND skin; the app shows it as "MSK & skin"), reproductive (includes pregnancy and breast), behavioral (psychiatric and substance use). There is no separate skin, eye, ENT or infectious system: pick the closest of these.
- clerkships: internalMedicine, surgery, pediatrics, obgyn, psychiatry, familyMedicine, neurology, emergency, clinicalPsychology (conditions a psychologist assesses and treats with therapy in an outpatient intake: mood, anxiety, trauma, substance use, eating, sleep, neurodevelopmental, cognitive decline; never a medical emergency or a condition that needs medical workup to diagnose).

Pick primary_clerkship as the rotation where students most often meet it; secondary_clerkships are other rotations where it is a realistic case.

Return a JSON object: {"results": [{"id": "<id as given>", "triage": <triage object>}]} with one result per condition, in order.

Triage object schema:
{schema}

Example triage object:
{example}

Conditions:
{conditions}
