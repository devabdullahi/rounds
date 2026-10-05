-- ───────────────────────────── topic availability ─────────────────────────────

-- How many conditions each clerkship and organ system can draw from, for the focus pickers.
-- Counts only: no condition names leave the private schema.
create function public.topic_counts()
returns table (kind text, topic text, conditions integer)
language sql
stable
security definer
set search_path = ''
as $$
  select 'rotation', c, count(*)::integer
  from private.condition_profiles p, unnest(p.clerkships) c
  where p.validation = 'passed' and p.review <> 'rejected'
  group by c
  union all
  select 'system', s, count(*)::integer
  from private.condition_profiles p, unnest(p.organ_systems) s
  where p.validation = 'passed' and p.review <> 'rejected'
  group by s;
$$;

revoke execute on function public.topic_counts() from public, anon;
grant execute on function public.topic_counts() to authenticated;
