---
title: Moderation
---

# Moderation

The **Moderation** page at `/app/admin/moderation` is the admin workspace for reviewing Catalog entries, acting on flags, and keeping user-generated content on the rails. Moderator actions are auditable; every decision is recorded.

## Who Can Moderate

Only users with the **admin** or **superadmin** role can access `/app/admin/moderation`. Regular users can **flag** entries and reviews, but flags route to the moderation queue rather than applying instant effects.

## Moderation States

Every Catalog entry has a `moderation_status` attribute. The lifecycle:

| State      | Meaning                                                            |
| ---------- | ------------------------------------------------------------------ |
| `pending`  | Published but not yet reviewed. Not visible to the public surface. |
| `approved` | Reviewed and publicly surfaced.                                    |
| `rejected` | Reviewed and not surfaced. Still visible to the author.            |

Transitions are moderator-driven. A new public entry starts as `pending`; a moderator advances it to `approved` or `rejected`. An approved entry can later be re-reviewed and moved back to `pending` or `rejected` if something changes.

The `Conflab.Catalog.Entry.Preparations.ApprovedOnly` preparation enforces visibility: any read action that runs through `ApprovedOnly` filters out non-`approved` entries. The public Catalog at `/lsd` and feeds always go through `ApprovedOnly`. The authenticated Catalog surfaces entries the caller can see (their own entries regardless of state, plus any `approved` + `public` entries).

## The Moderation Queue

The page shows entries that need attention, grouped by urgency:

- **Flagged.** Entries that have received one or more user flags. Shows the flag count, the reasons given, and the reporters.
- **Pending.** Recently published entries awaiting first-pass review.
- **Auto-hidden.** Entries that crossed the `flag_threshold.entry` setting and were temporarily hidden for re-review.

Each row shows: entry title, author, published timestamp, current state, flag count, quick actions.

## Moderator Actions

For each queued entry, moderators can:

- **Approve** -- move the entry to `approved`. It becomes publicly visible.
- **Reject** -- move the entry to `rejected`. It stays visible to the author but is not surfaced publicly.
- **Return to Pending** -- move an approved entry back for further review.
- **Resolve flags** -- mark all open flags as handled without changing the entry state.
- **View details** -- open the full entry detail page for context.
- **Contact author** -- send a message to the author through their primary flab or email.

Actions are logged with moderator identity, entry ID, previous state, new state, and timestamp. The log is visible at the bottom of the Moderation page (admin only).

## Flag Thresholds

Two thresholds, both configurable via [Runtime Settings](/app/help/admin/settings):

| Key                     | Default | Purpose                                                |
| ----------------------- | ------- | ------------------------------------------------------ |
| `flag_threshold.entry`  | `5`     | Entry flags before auto-hide and re-queue for review.  |
| `flag_threshold.review` | `3`     | Review flags before auto-hide and re-queue for review. |

Raising a threshold makes the platform more permissive before auto-hides; lowering makes it more aggressive.

## Rate Limits

Users are rate-limited on moderation-adjacent actions:

| Key                  | Default | Purpose                             |
| -------------------- | ------- | ----------------------------------- |
| `rate_limit.flag`    | `50`    | Flags a user can raise per day.     |
| `rate_limit.review`  | `20`    | Reviews a user can post per day.    |
| `rate_limit.publish` | `10`    | Entries a user can publish per day. |

Limits prevent individual users from overwhelming the moderation queue or the Catalog with a burst of content.

## Reports from the Public Surface

Anonymous visitors on `/lsd` cannot flag or report directly. The public surface only shows `approved` + `public` entries; anything problematic on the public surface is by definition something a moderator has already approved. Anonymous visitors can report issues by signing in or by emailing support. Once signed in, the standard flag flow applies.

## Related

- [Runtime Settings](/app/help/admin/settings) -- threshold and rate-limit configuration.
- [The Catalog](/app/help/concepts/catalog) -- visibility and moderation in context.
- [Using the Catalog](/app/help/using-conflab/catalog) -- the user-side Report flow.
