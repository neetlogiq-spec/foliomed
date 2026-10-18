# Database smoke tests

Runs the migration on a throwaway local Postgres (no Docker needed) and
checks row-level security, cascades and the RPCs with two fake users.

```bash
initdb -D /tmp/fm-pg -U postgres -A trust
pg_ctl -D /tmp/fm-pg -o "-p 54329 -k /tmp -c listen_addresses=''" start
P="psql -h /tmp -p 54329 -U postgres -v ON_ERROR_STOP=1"
$P -f supabase/tests/00_supabase_stub.sql
$P -f supabase/migrations/20261019000000_initial_schema.sql
$P -f supabase/tests/10_rls_smoke.sql
pg_ctl -D /tmp/fm-pg stop && rm -rf /tmp/fm-pg
```

Expected: non-members see 0 rows, joining with an unknown code returns
false, only the creator can delete a ward, deleting a ward cascades and
clears members' `ward_ids`, and `delete_my_account()` removes the user.
