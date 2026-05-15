# conflab v0.5.5

_Released 2026-05-15_

Pre-launch hardening release on top of v0.5.4's parity-audit work. Three steel threads land together: a public two-stage opt-in waitlist (`/waitlist`) with admin-side admission, a 14-index DB audit across eight tables (sized for real-user load rather than developer-laptop load), and a project-wide migration of 74 datetime columns from `timestamp without time zone` to `timestamptz` (closing the BST cast-shift class of bugs by construction). Plus an in-session diversion: a superadmin-only role-edit dropdown at `/app/admin/users` that closes a privilege-escalation gap in the existing `:admin_update` Ash action.

Five new migrations apply server-side on `scripts/deploy`. No conflab CLI / daemon wire-protocol changes; no breaking changes to lens, shape, or run semantics.

## Added

### Public waitlist (ST0115)

`/waitlist` is now live -- a prospective user enters an email, receives a confirmation code, confirms via emailed link, and joins the queue. Admins admit confirmed entries from `/app/admin/waitlist`, which dispatches a magic-link email that bypasses the registration gate (admitted email = guaranteed access regardless of `registration_mode`).

- New `Conflab.Accounts.WaitlistEntry` Ash resource with five-state lifecycle: `:unconfirmed` -> `:confirmed` -> `:admitted` (plus `:cancelled` and a re-join path for `:cancelled` / expired entries).
- Public `WaitlistController` (Phoenix controller, not LiveView) for join + confirm flows so the surface works without JS.
- Admin `WaitlistLive` with status filter, manual admit, manual cancel, kebab-menu per-row actions.
- Magic-link admit gate: `Conflab.Accounts.User.Changes.CheckRegistrationForNewUser` now short-circuits on `:admitted` waitlist email regardless of `registration_mode`. The gate is refactored to a four-branch `gate_decision/1` that surfaces all three "allow" paths (admitted, existing user, open mode) without nested case.
- Per-IP rate limiting on `/waitlist` POSTs via `Hammer`.
- All confirmation codes are 8-character base32; expiry is 24h; re-mint via `:regenerate_code`.

### Database index audit (ST0116)

14 new indexes across 8 tables. Sized for the access patterns the admin LiveViews + public waitlist confirm + catalog browse + notification bell + chat participant lookups actually issue, rather than for a developer-laptop's row counts. Four migrations, concurrently-safe on tables that are or will grow:

- `users`: `(role, inserted_at)` and `(email_active, role)` for admin UsersLive sort + filter.
- `waitlist_entries`: `(status, inserted_at)` and `(confirmation_code)` for queue listing + confirm.
- `api_keys`: `(user_id, last_used_at DESC NULLS LAST)` for the API key recency surface.
- `catalog_entries`: five indexes covering the four catalog browse axes (search across `name`/`description`, `(kind, status, inserted_at)`, `(author_user_id, inserted_at)`, `(forked_from_id)`, plus a GIN index on `tags` for tag filters).
- `notifications`: `(user_id, read_at)` and `(user_id, inserted_at DESC)` for the bell unread-count and recent list.
- `agent_stack_entries`: `(crystallized_at)` for the stack-decay sort.
- `participants`: `(flab_id, agent_handle)` and `(user_id, flab_id)` for chat participant lookups.

The aggregate-source-table indexing for the catalog stat-sort axes (`recent_import_count`, `stat_avg_rating`, `stat_download_count`, `stat_like_count`) is deferred -- those are Ash aggregates not columns, and their underlying tables aren't large enough to warrant index work yet.

### Timestamp timezone migration (ST0117)

All 74 datetime columns across 31 tables migrated from `timestamp without time zone` to `timestamp with time zone` (`timestamptz`) in a single migration. Schema is now timezone-correct independent of session-TZ configuration, closing the class of bugs where `Ash.Query.filter(column < ^utc_datetime)` would silently miscompare under a non-UTC session timezone (eg BST during summer).

The previous belt-and-suspenders fix from this release window (`fix(db): pin Postgrex session timezone to UTC`, `678dfabb`) remains in place as defence-in-depth; removing either alone is now safe but removing both would re-open the cast-shift gap.

Per-resource discipline: every Ash resource declares `migration_types confirmed_at: :timestamptz, ...` for its datetime attributes, so the schema is generated correctly going forward and `mix ash.codegen` will produce timestamptz columns for any new datetime attributes without manual intervention.

### Superadmin role-edit dropdown (diversion)

`/app/admin/users` now renders a role-select dropdown for superadmin viewers (badge-only for admin viewers), with a 2-step confirm via the canonical `ConfirmAction` function component. The new `:update_role` Ash action is gated by a superadmin-only policy bypass; the existing `:admin_update` action's `:role` field is removed, closing a privilege-escalation gap where any admin could promote themselves or another admin to superadmin.

Behavioural change worth flagging: admins can no longer set roles. Only superadmin (via `update_role`) can change a user's role. The `Verified publisher` toggle on UsersLive is unaffected and remains admin-accessible.

### Plans page polish

`/app/plans` cards now show `£TBC` for Pro / Team / Enterprise (Free stays at `£0`), with a centred "Paid plans coming soon" notice and a `mailto:plans@conflab.space` contact link. Per-card lens/theme counts are now correct -- previously all four cards displayed the same count regardless of which plan's slug they represented.

## Migration notes

`scripts/deploy` runs the release task which applies five new migrations against `conflab_prod` in order:

1. `20260515075429_add_waitlist_auth_indexes` -- waitlist + users + api_keys indexes.
2. `20260515082429_add_catalog_browse_indexes` -- catalog browse axes (`CONCURRENTLY`).
3. `20260515082759_add_notifications_stack_indexes` -- notifications bell + agent stack (`CONCURRENTLY`).
4. `20260515082906_add_participant_indexes` -- chat participant lookups (`CONCURRENTLY`).
5. `20260515092024_migrate_to_timestamptz` -- 74 `ALTER COLUMN ... TYPE timestamptz USING ... AT TIME ZONE 'UTC'` statements.

Migrations 2-4 use `CREATE INDEX CONCURRENTLY` so they don't block writes. Migration 5 is a single transaction; expected to be sub-second against the current row counts.

No conflab CLI / daemon / macOS-app wire-protocol changes. No breaking changes for clients on v0.5.4.

## Tests + verification

- `mix test` clean across the full suite.
- Critic-elixir review of the ST0115 surface (waitlist domain, web layer, email surfaces, change modules + matching tests): remediated three findings inline before close-out -- silent error rescue in `ensure_system_user!`, fragile text matching in `CatalogLiveTest`, Highlander helper extraction for the four-branch gate.
- `mix ash.codegen --check` clean against the timestamptz migration -- the schema matches the resource DSL with no drift.
- Postgrex session-TZ pin (`parameters: [timezone: "UTC"]`) verified in `dev` + `test` + `runtime` configs.

## Standing landmines (unchanged from v0.5.4)

- `brew unlink conflab` after `brew update` if local CLI builds stop reflecting `cargo build`.
- `CONFLAB_DISABLE_KEYCHAIN=1` for any test harness spawning `conflabd` under tmpdir HOME.
- `~/.conflab/db` is a separate git repo; pristine commands operate on it via the same Intent CLI rules.
- Tests that touch `~/.config/conflab/` MUST use the `TempHome` guard plus `#[serial_test::file_serial(home)]`.
- `scripts/flysql` runs ONE statement per invocation (Postgrex prepared protocol). No BEGIN/COMMIT bundles -- split multi-statement work into separate calls.

## Deferred to v0.6.x

- **Catalog stat-sort aggregate index follow-up** -- four catalog axes are Ash aggregates not columns; defer aggregate-source-table indexing until real prod slowness surfaces.
- **Tier 1c -- `router.self_identifiers` refresh on mid-run new flabs** (carried; vanishing impact post-v0.5.1).
- **ST0098 (Routines)** -- v0.6.x; needs design + WPs.
- **ST0097 (Output Destinations)** -- v0.6.x; needs design + WPs.
- **WhatsApp integration (ST0032)** -- independent of the v0.5.x line.
