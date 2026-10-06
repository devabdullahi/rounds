Describe who typically has this condition and how they present, from the patient's side.
- chief_complaints are in the patient's own words.
- hpi covers the classic presentation; associated_symptoms carry frequencies.
- pertinent_negatives are things usually absent whose presence would point elsewhere.
- ros lists only relevant systems.
- atypical covers populations where the presentation differs.
- Every symptom item (associated_symptoms, ros positives, chief_complaints) has a "term": its standard clinical name as SNOMED CT names it, one finding only, no qualifiers or context ("Nausea", "Hemoptysis", "Right lower quadrant pain"). "text" keeps the natural description.
- Medications in risk_medications are generic drug names as RxNorm lists them ("prednisone", "lisinopril").
