-- Real chest X-ray assets.
--
-- private.scan_assets holds one row per curated NIH ChestX-ray14 image: which finding it shows,
-- the side and zone from a radiologist box, and the vision-gate verdict. Those labels sit next to
-- the answer key, so the table lives in `private` and only the service role (edge functions) reads
-- it. The JPEGs live in the private `scans` bucket with no Storage policies for anon or
-- authenticated; the app only ever receives a short-lived signed URL minted by an edge function.

create table private.scan_assets (
  id uuid primary key default gen_random_uuid(),
  object_name text not null unique,
  finding text not null check (finding in (
    'normal', 'pneumothorax', 'opacity', 'nodule_mass', 'fracture',
    'effusion', 'atelectasis', 'cardiomegaly', 'edema', 'emphysema')),
  side text check (side in ('left', 'right')),
  zone text check (zone in ('upper', 'middle', 'lower')),
  view text not null check (view in ('PA', 'AP')),
  age int not null,
  sex text not null check (sex in ('female', 'male')),
  report text not null,
  label_source text not null check (label_source in ('nih_bbox', 'google_four', 'google_all')),
  source_image text not null,
  gate jsonb not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

comment on table private.scan_assets is 'Curated real chest X-rays and their expert labels. Service role only; never exposed to the app.';

create index scan_assets_finding_active_idx on private.scan_assets (finding, active);

alter table private.scan_assets enable row level security;
revoke all on private.scan_assets from anon, authenticated;
grant all on private.scan_assets to service_role;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('scans', 'scans', false, 1048576, array['image/jpeg'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;
