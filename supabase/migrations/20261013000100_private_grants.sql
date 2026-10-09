-- Explicit revokes on private tables created after the initial schema.
--
-- The initial schema revoked access to every private table that existed then, and the app roles
-- have no usage on the schema, so these were already unreachable. Revoking per table keeps them
-- closed even if schema usage is ever granted by mistake, and says so where someone will look.

revoke all on private.condition_profiles from public, anon, authenticated;
revoke all on private.conditions         from public, anon, authenticated;
revoke all on private.profile_jobs       from public, anon, authenticated;
revoke all on private.term_checks        from public, anon, authenticated;
revoke all on private.usage              from public, anon, authenticated;
