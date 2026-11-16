#!/usr/bin/env bash
# Applies new migrations and deploys edge functions to the palpo-staging project (TestFlight
# testers). Production is untouched. Run this before the production deploy, then test in a
# "Rounds Staging" TestFlight build.
#
#   supabase/deploy-staging.sh                 # migrations + every function
#   supabase/deploy-staging.sh case-session    # migrations + just these functions
#
# Needs supabase/staging.env (git-ignored) with SUPABASE_DB_PASSWORD for the staging database.
set -euo pipefail
cd "$(dirname "$0")/.."
REF=cwceoydoxoejdbmvakya
# shellcheck disable=SC1091
source supabase/staging.env
supabase db push --db-url "postgresql://postgres.$REF:$SUPABASE_DB_PASSWORD@aws-0-us-east-1.pooler.supabase.com:5432/postgres"
supabase functions deploy --project-ref "$REF" "$@"
