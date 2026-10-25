-- "Why did you download Rounds?" joins the onboarding answers (2026-10-25). One of the app's
-- DownloadReason values; older builds leave it null. Students may insert it with the rest of their
-- answers (column grant), as with the other answer columns; reading stays service-role only.

alter table public.onboarding_answers
  add column download_reason text
    check (download_reason in ('confidence', 'differentials', 'rotations', 'exams'));

grant insert (download_reason) on public.onboarding_answers to authenticated;
