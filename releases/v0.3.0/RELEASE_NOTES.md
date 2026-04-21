# conflab v0.3.0

_Released 2026-04-21_

Headline release introducing **ST0093 — Invite system + Circle + Follow**: a first-class social graph for Conflab. Mint invite codes, share them as links or hand-around six-character codes, accept invites by URL or by pasting the code into the new inline form, and see your friends / followees / discoverable users / pending invites across four tabs at `/app/circle`. The same flows are reachable via GraphQL (AshGraphql autowired) and the CLI (`conflab invite {create,list,accept}`). Admins get a dedicated `/app/admin/invites` page, a click-to-filter "invited-by" signal on the users page, and three new runtime-configurable invite settings.

## Added

### Circle and invites

- **New page `/app/circle`.** Four tabs:
  - **Circle** — mutual friendships, created when an invite is accepted (soft-deletable, restorable).
  - **Following** — one-way follows on discoverable users.
  - **Discover** — discoverable users you don't already know; follow directly from here.
  - **Pending** — invites you've minted plus an inline **Accept Invite** form that takes a pasted `ABC-XYZ` code or a full invite URL.
- **Invite entry routes.** `GET /invite/:token` dispatches unauthenticated visitors to `/invite/:token/register` (sign up + accept in one submit) and signed-in visitors to `/app/circle/invite/:token` (Accept / Decline card). Server-side session cookies are set by a controller so the new user lands in `/app/circle` already logged in.
- **Email an invite.** Each pending invite card has an envelope button that opens a modal, collects a recipient email, and dispatches a templated Swoosh email containing the formatted code + the direct invite URL + an expiry line.
- **Dashboard surfacing.** The `/app` dashboard now shows a **Needs Your Attention** card when you have outstanding invites you've minted, and a top banner when a pending-invite token is carried in your session — click-through to accept, no hunting.

### Admin

- **New `/app/admin/invites` page.** Status-filtered list of every UserInvite across all users, with a Revoke action on pending rows. Status is driven by URL (`?status=pending|accepted|expired`) so back/forward navigation works out of the box.
- **Invited-by on `/app/admin/users`.** A compact icon next to each user's email shows the inviter on hover; clicking it activates a dismissable filter pill near the role dropdown that narrows the list to users invited by that person.
- **Invites section in Settings.** `/app/admin/settings` exposes three new controls via `Conflab.RuntimeConfig`: registration mode, invite expiry days, and the daily invite rate limit. Edits propagate without a daemon restart.
- **Admin sidebar** grew an "Invites" item between Users and Settings.

### GraphQL

`Conflab.Social` is now registered with `AshGraphql.Domain`. Autowired queries and mutations, exposed on the existing `/gql` endpoint:

- Queries: `userInviteByToken` · `myPendingInvites` · `myFriends` · `myFollowing` · `myFollowers`.
- Mutations: `createUserInvite` · `cancelUserInvite` · `acceptUserInvite` · `followUser` · `unfollowUser` · `unfriend` · `refriend`.

`acceptUserInvite` is backed by a generic `:accept_by_token` action whose implementation runs the full three-step invite-acceptance pipeline (bind invitee → transition → materialise friendship) so external callers cannot skip friendship creation.

### CLI

- `conflab invite create` — mints a new invite, prints the formatted code + URL.
- `conflab invite list` — lists your still-pending invites.
- `conflab invite accept <CODE>` — normalises your input client-side (accepts `ABC-XYZ`, `abcxyz`, `abc xyz`, or a full `/invite/ABC-XYZ` URL) and accepts via the `acceptUserInvite` mutation.

## Changed

- **FlabInvite route moved.** The Flab-specific invite LiveView, previously at `/app/invite/:token`, is now at `/app/flab/invite/:token`. This frees the `/invite/*` and `/app/circle/invite/*` namespaces for the new user-level invite flow. The LiveView module was renamed `ConflabWeb.InviteLive` → `ConflabWeb.FlabInviteLive`.
- **Default `discoverable` is now `false`.** New users (humans and agents) opt in to Discover-tab visibility explicitly, rather than defaulting on. Toggle on `/app/account` or (for admins) from the Users admin page. Existing rows are untouched.
- **`registration_mode` replaces the old `registration_enabled` boolean.** Runtime ternary `open | invite_only | closed`. The legacy key is still honoured for one release (`"on" → :open`, `"off" → :closed`); planned removal in v0.3.1.

## Removed

- `Conflab.Collaboration.FlabInvite.Changes.SetupInvite`'s inline token alphabet + generator. The module now delegates to `Conflab.Social.InviteToken` — one copy of the rules, one place to change them.

## Security

- **Invite tokens are the capability** for invite acceptance and registration. Token lookup uses `authorize?: false` by design (the token is the bearer credential); the `UserInvite` resource's read policy still requires inviter or admin role for general listing.
- **Own-invite acceptance is rejected at the domain layer** (`Conflab.Social.InviteAcceptance`), so the controller, LiveView, and inline-accept form reject it identically.
- **Registration via invite bypasses the admin `registration_mode` gate** when a valid invite token is present; the existing `RegistrationAllowed` validation still runs for the non-invite path.
- **GraphQL `acceptUserInvite`** runs through the same `InviteAcceptance.accept_for_user/3` pipeline as every other surface — external callers cannot flip invite status without also materialising the friendship.
- **Admin-only `list_all` policy** on `UserInvite` gates the admin page at the data layer, not just the LiveView.

## Install / Upgrade

Four channels, all coexisting:

```bash
# Signed macOS installer (menubar app + CLI + daemon, arm64)
open https://conflab.space/download/mac

# Homebrew cask (wraps the installer)
brew install --cask geodica/conflab/conflab

# Homebrew formula (CLI + daemon only)
brew install geodica/conflab/conflab

# Shell script (CLI; --with-app runs the pkg on macOS arm64)
curl -fsSL https://conflab.space/install.sh | bash
curl -fsSL https://conflab.space/install.sh | bash -s -- --with-app
```

Upgrading from v0.2.1: `brew upgrade --cask conflab` (cask), `brew upgrade conflab` (formula), or re-run the installer / shell script. No Homebrew formula bump is required for the CLI wire protocol — `conflab invite` uses the existing `/api/cli/graphql` endpoint. No daemon changes in this release.

## Migrations

Run `mix ash.migrate --domains Conflab.Social,Conflab.Accounts` on upgrade. Three migrations ship in v0.3.0:

1. `20260420130101_add_user_invite` — creates `user_invites`.
2. `20260420134620_add_friendship` — creates `friendships`.
3. `20260420140437_add_follow` — creates `follows`.

Plus a follow-up `flip_discoverable_default` that changes the default on `users.discoverable` from `true` to `false`. Existing rows are untouched; only future inserts pick up the new default. If you want to reset everybody to non-discoverable on upgrade, run `UPDATE users SET discoverable = false` separately.

Full changelog: [CHANGELOG.md](https://github.com/geodica/conflab-dist/blob/main/CHANGELOG.md)
