TRIAGE BATCH. For each condition below, decide whether it makes a good Rounds case and tag it.

A good case topic is a diagnosis a student can reach by interviewing a patient, examining them and ordering tests. Not good: broad categories ("Bone Diseases"), care topics ("Caregivers", "Treatment"), wellness topics ("Body Weight"), or things with no patient presentation.

Use only these values:
- organ_systems: cardiovascular, respiratory, gastrointestinal, renal (kidney and urinary), nervous, endocrine (includes metabolic and nutritional), blood (blood disorders, includes infections that are mainly systemic), immune (allergy, immunodeficiency and autoimmune disease without one main organ), musculoskeletal (bones, joints, muscles and connective tissue), skin (skin, hair and nails), eye, ent (ear, nose, sinuses, throat and voice), reproductive (includes pregnancy and breast), behavioral (psychiatric and substance use). There is no separate infectious system: pick the organ the infection is in.
- clerkships: internalMedicine, surgery, pediatrics, obgyn, psychiatry, familyMedicine, neurology, emergency, clinicalPsychology (conditions a psychologist assesses and treats with therapy in an outpatient intake: mood, anxiety, trauma, substance use, eating, sleep, neurodevelopmental, cognitive decline; never a medical emergency or a condition that needs medical workup to diagnose). dermatology (conditions whose main problem shows on the skin, hair or nails, diagnosed by looking at and describing lesions).

Pick primary_clerkship as the rotation where students most often meet it; secondary_clerkships are other rotations where it is a realistic case.

Return a JSON object: {"results": [{"id": "<id as given>", "triage": <triage object>}]} with one result per condition, in order.

Triage object schema:
{schema}

Example triage object:
{example}

Conditions:
{conditions}
