-- Writes profiles for the core conditions in the cloud ahead of time, so students don't wait for them.
--
-- Until now a profile was written only when a student first asked for its topic (prefetch.ts), one
-- condition at a time. This queues every core condition that has no profile yet
-- (tools/kb-import/core_conditions.json: what a US student is expected to work up, by clerkship),
-- and a pg_cron job starts a few of them every two minutes through prepare-profile, which then
-- chains its own stages. The scheduler starts work only off-peak (DeepSeek bills half then) and
-- stops for the day once model spend passes its own cap, which sits below the edge functions'
-- daily budget so students always keep headroom.
--
-- prepare-profile accepts only the service role key, so the scheduler reads it and the project URL
-- from Vault. Add both once in the SQL editor; until then the scheduler does nothing:
--   select vault.create_secret('https://mpyxaefnytviwnjuqtbu.supabase.co', 'project_url');
--   select vault.create_secret('<service role key>', 'service_role_key');

create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

-- Batch jobs are marked so the scheduler starts only these; on-demand jobs keep their own flow.
insert into private.profile_jobs (slug, requested_by)
select c.slug, 'core-batch'
from (values
  ('heart-attack'),
  ('unstable-angina'),
  ('angina'),
  ('heart-failure'),
  ('atrial-fibrillation'),
  ('aortic-dissection'),
  ('endocarditis'),
  ('aortic-stenosis'),
  ('hypertensive-emergency'),
  ('pulmonary-embolism'),
  ('deep-vein-thrombosis'),
  ('pneumonia'),
  ('copd'),
  ('asthma'),
  ('sepsis'),
  ('diabetic-ketoacidosis'),
  ('hyperosmolar-hyperglycemic-state'),
  ('hypoglycemia'),
  ('hyperthyroidism'),
  ('hypothyroidism'),
  ('addison-disease'),
  ('hyponatremia'),
  ('hyperkalemia'),
  ('hypercalcemia'),
  ('acute-kidney-injury'),
  ('chronic-kidney-disease'),
  ('nephrotic-syndrome'),
  ('glomerulonephritis'),
  ('upper-gastrointestinal-hemorrhage'),
  ('cirrhosis'),
  ('pancreatitis'),
  ('inflammatory-bowel-disease'),
  ('iron-deficiency-anemia'),
  ('sickle-cell-disease'),
  ('lupus'),
  ('rheumatoid-arthritis'),
  ('gout'),
  ('tuberculosis'),
  ('hiv'),
  ('cellulitis'),
  ('anaphylaxis'),
  ('appendicitis'),
  ('acute-cholecystitis'),
  ('choledocholithiasis'),
  ('intestinal-obstruction'),
  ('diverticulitis'),
  ('peptic-ulcer'),
  ('acute-mesenteric-ischemia'),
  ('hernia'),
  ('abdominal-aortic-aneurysm'),
  ('acute-limb-ischemia'),
  ('compartment-syndrome'),
  ('testicular-torsion'),
  ('kidney-stones'),
  ('breast-cancer'),
  ('colorectal-cancer'),
  ('necrotizing-fasciitis'),
  ('burns'),
  ('bronchiolitis'),
  ('croup'),
  ('epiglottitis'),
  ('kawasaki-disease'),
  ('intussusception'),
  ('pyloric-stenosis'),
  ('febrile-seizure'),
  ('meningitis'),
  ('acute-otitis-media'),
  ('streptococcal-pharyngitis'),
  ('hand-foot-and-mouth-disease'),
  ('measles'),
  ('neonatal-jaundice'),
  ('diabetes-type-1'),
  ('asthma-in-children'),
  ('attention-deficit-hyperactivity-disorder'),
  ('autism-spectrum-disorder'),
  ('child-abuse'),
  ('henoch-schonlein-purpura'),
  ('gastroenteritis'),
  ('ectopic-pregnancy'),
  ('preeclampsia'),
  ('placental-abruption'),
  ('placenta-previa'),
  ('postpartum-hemorrhage'),
  ('diabetes-and-pregnancy'),
  ('hyperemesis-gravidarum'),
  ('miscarriage'),
  ('preterm-labor'),
  ('ovarian-torsion'),
  ('pelvic-inflammatory-disease'),
  ('endometriosis'),
  ('polycystic-ovary-syndrome'),
  ('uterine-fibroids'),
  ('ovarian-cancer'),
  ('cervical-cancer'),
  ('bacterial-vaginosis'),
  ('major-depressive-disorder'),
  ('bipolar-disorder'),
  ('schizophrenia'),
  ('anxiety'),
  ('panic-disorder'),
  ('post-traumatic-stress-disorder'),
  ('obsessive-compulsive-disorder'),
  ('opioid-use-disorder'),
  ('opioid-overdose'),
  ('delirium'),
  ('eating-disorders'),
  ('suicidal-ideation'),
  ('neuroleptic-malignant-syndrome'),
  ('serotonin-syndrome'),
  ('high-blood-pressure'),
  ('diabetes-type-2'),
  ('back-pain'),
  ('acute-bronchitis'),
  ('sinusitis'),
  ('urinary-tract-infection'),
  ('osteoarthritis'),
  ('osteoporosis'),
  ('gerd'),
  ('irritable-bowel-syndrome'),
  ('hay-fever'),
  ('eczema'),
  ('acne'),
  ('enlarged-prostate-bph'),
  ('tobacco-use-disorder'),
  ('ischemic-stroke'),
  ('transient-ischemic-attack'),
  ('hemorrhagic-stroke'),
  ('migraine'),
  ('headache'),
  ('epilepsy'),
  ('status-epilepticus'),
  ('guillain-barre-syndrome'),
  ('myasthenia-gravis'),
  ('multiple-sclerosis'),
  ('spinal-cord-compression'),
  ('acetaminophen-poisoning'),
  ('carbon-monoxide-poisoning'),
  ('heat-illness'),
  ('hypothermia'),
  ('septic-shock'),
  ('tension-pneumothorax'),
  ('acute-asthma-exacerbation'),
  ('traumatic-brain-injury'),
  ('concussion'),
  ('hip-fracture'),
  ('angioedema'),
  ('upper-airway-obstruction'),
  ('drowning'),
  ('animal-bites'),
  ('psoriasis'),
  ('rosacea'),
  ('allergic-contact-dermatitis'),
  ('dandruff-cradle-cap-and-other-scalp-conditions'),
  ('hives'),
  ('impetigo'),
  ('shingles'),
  ('tinea-infections'),
  ('tinea-versicolor'),
  ('scabies'),
  ('molluscum-contagiosum'),
  ('warts'),
  ('melanoma'),
  ('basal-cell-carcinoma'),
  ('squamous-cell-carcinoma-of-skin'),
  ('actinic-keratosis'),
  ('seborrheic-keratosis'),
  ('stevens-johnson-syndrome'),
  ('toxic-epidermal-necrolysis'),
  ('erythema-multiforme'),
  ('pityriasis-rosea'),
  ('lichen-planus'),
  ('hidradenitis-suppurativa'),
  ('vitiligo'),
  ('hair-loss'),
  ('folliculitis'),
  ('pemphigus'),
  ('neonatal-respiratory-distress-syndrome'),
  ('transient-tachypnea-of-the-newborn'),
  ('meconium-aspiration-syndrome'),
  ('neonatal-sepsis'),
  ('necrotizing-enterocolitis'),
  ('neonatal-hypoglycemia'),
  ('neonatal-abstinence-syndrome'),
  ('hypoxic-ischemic-encephalopathy'),
  ('bronchopulmonary-dysplasia'),
  ('retinopathy-of-prematurity'),
  ('intraventricular-hemorrhage-of-newborn'),
  ('congenital-hypothyroidism'),
  ('hirschsprung-disease'),
  ('esophageal-atresia'),
  ('congenital-diaphragmatic-hernia'),
  ('gastroschisis'),
  ('developmental-dysplasia-of-the-hip'),
  ('neonatal-herpes-simplex'),
  ('congenital-cytomegalovirus-infection'),
  ('ophthalmia-neonatorum'),
  ('kwashiorkor'),
  ('marasmus'),
  ('scurvy'),
  ('beriberi'),
  ('wernicke-encephalopathy'),
  ('vitamin-b12-deficiency'),
  ('folate-deficiency-anemia'),
  ('pellagra'),
  ('vitamin-a-deficiency'),
  ('vitamin-k-deficiency-bleeding'),
  ('zinc-deficiency'),
  ('refeeding-syndrome'),
  ('short-bowel-syndrome'),
  ('failure-to-thrive'),
  ('acute-angle-closure-glaucoma'),
  ('primary-open-angle-glaucoma'),
  ('central-retinal-artery-occlusion'),
  ('central-retinal-vein-occlusion'),
  ('retinal-detachment'),
  ('bacterial-conjunctivitis'),
  ('corneal-abrasion'),
  ('hordeolum'),
  ('chalazion'),
  ('orbital-cellulitis'),
  ('anterior-uveitis'),
  ('optic-neuritis'),
  ('macular-degeneration'),
  ('diabetic-eye-problems'),
  ('normal-pressure-hydrocephalus'),
  ('fecal-impaction'),
  ('autosomal-dominant-polycystic-kidney-disease'),
  ('iga-nephropathy'),
  ('minimal-change-disease'),
  ('membranous-nephropathy'),
  ('renal-tubular-acidosis'),
  ('hypernatremia'),
  ('hypomagnesemia'),
  ('rhabdomyolysis'),
  ('contrast-induced-nephropathy'),
  ('renal-artery-stenosis'),
  ('drug-allergy'),
  ('penicillin-allergy'),
  ('hereditary-angioedema'),
  ('common-variable-immunodeficiency'),
  ('selective-iga-deficiency'),
  ('allergic-conjunctivitis'),
  ('serum-sickness'),
  ('epididymitis'),
  ('acute-pyelonephritis'),
  ('acute-prostatitis'),
  ('bladder-cancer'),
  ('renal-cell-carcinoma'),
  ('acute-urinary-retention'),
  ('hydronephrosis'),
  ('varicocele'),
  ('hydrocele'),
  ('phimosis'),
  ('cryptorchidism'),
  ('neurogenic-bladder')
) as core (slug)
join private.conditions c using (slug)
where c.case_suitable
  and not exists (select 1 from private.condition_profiles p where p.slug = c.slug)
on conflict (slug) do nothing;

-- Starts batch jobs until max_running are in flight. A job counts as in flight while a call holds
-- it (locked within prepare-profile's 4-minute stale limit) or just after it queued its next stage
-- and kicked itself. Returns how many it started.
create function private.advance_profile_batch(max_running integer, daily_cap_usd numeric)
returns integer
language plpgsql
volatile
set search_path = ''
as $$
declare
  url text;
  key text;
  busy integer;
  started integer := 0;
  job record;
  utc timestamp := now() at time zone 'utc';
begin
  -- DeepSeek peak hours (UTC, Monday to Friday): 01:00-04:00 and 06:00-10:00.
  if extract(isodow from utc) <= 5
     and (extract(hour from utc) between 1 and 3 or extract(hour from utc) between 6 and 9) then
    return 0;
  end if;
  if private.llm_spend_today() >= daily_cap_usd then
    return 0;
  end if;

  select decrypted_secret into url from vault.decrypted_secrets where name = 'project_url';
  select decrypted_secret into key from vault.decrypted_secrets where name = 'service_role_key';
  if url is null or key is null then
    raise notice 'advance_profile_batch: add project_url and service_role_key to Vault';
    return 0;
  end if;

  select count(*) into busy from private.profile_jobs
  where requested_by = 'core-batch'
    and ((status = 'running' and locked_at > now() - interval '4 minutes')
      or (status = 'queued' and updated_at > now() - interval '2 minutes'));

  for job in
    select slug from private.profile_jobs
    where requested_by = 'core-batch'
      and ((status = 'queued' and updated_at <= now() - interval '2 minutes')
        or (status = 'running' and locked_at < now() - interval '4 minutes'))
    order by stage desc, created_at
    limit greatest(max_running - busy, 0)
  loop
    perform net.http_post(
      url := url || '/functions/v1/prepare-profile',
      headers := jsonb_build_object('Authorization', 'Bearer ' || key, 'Content-Type', 'application/json'),
      body := jsonb_build_object('slug', job.slug)
    );
    started := started + 1;
  end loop;
  return started;
end;
$$;

revoke all on function private.advance_profile_batch(integer, numeric) from public, anon, authenticated;

-- Three at a time, and at most $10 of model spend per UTC day (the edge functions' default cap is $25).
select cron.schedule('core-profile-batch', '*/2 * * * *', $cron$select private.advance_profile_batch(3, 10)$cron$);
