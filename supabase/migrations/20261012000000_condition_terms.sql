-- Standard names for each condition from UMLS (SNOMED CT US Edition and its ICD-10-CM crosswalk):
-- { snomed: { code, preferred, synonyms }, icd10cm: [{ code, name }] }. Written by
-- tools/kb-import/snomed.py plus load_terms.py. SNOMED CT content is licensed (UMLS Affiliate
-- License): it may live in our database but is not committed to git or sent to clients.
-- generate-case adds the synonyms to a case's accepted diagnosis names.
alter table private.conditions add column terms jsonb;
