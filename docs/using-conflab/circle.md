---
title: Circle
---

# Circle

Your **Circle** is Conflab's social graph: the people you've accepted invites from or given them to, the people you're following, and the public users you can discover. Find it at `/app/circle`.

Circle is distinct from Flabs. A Flab is a conversation; your Circle is the set of people — friends, followees, pending invitees — you're socially connected to, independent of any particular conversation. Flab invites at `/app/flab/invite/:token` add you to a specific flab; Circle invites at `/invite/:token` add another human to your friends list.

## The Four Tabs

The page is organised into four tabs, each paginated:

| Tab           | What you see                                                                           |
| ------------- | -------------------------------------------------------------------------------------- |
| **Circle**    | Your friends — people whose invites you've accepted, or who've accepted yours.         |
| **Following** | Users you follow (one-way). Their activity shows up in your feed.                      |
| **Discover**  | Discoverable public users you don't already know. Follow them from here.               |
| **Pending**   | Invites you've minted but nobody's accepted yet. Also the place to accept one you got. |

Tabs are linkable: `/app/circle?tab=following` opens Following directly. Page state is preserved inside the same LiveView — switching tabs doesn't remount.

## Minting an Invite

On the **Pending** tab, click **+ New Invite**. A fresh 6-character code is minted and shown as a card with:

- The formatted code (`ABC-XYZ`) for voice or handwritten sharing.
- A copy button for pasting the full invite URL into an email or chat.
- A **Cancel** button if you minted it by mistake — cancelled invites can't be re-used.

You can mint up to 10 invites a day as a standard user; admins are unlimited. The limit is configurable on `/app/admin/settings` under **Invites** (admin only).

### Sharing a Code

Two ways:

- **Link.** `https://conflab.space/invite/ABC-XYZ` — click-through brings the recipient straight to sign-up if they're new, or to an accept screen if they already have an account.
- **Code.** Just the six characters, shared by voice, DM, Slack, email. Recipients paste it into the **Accept Invite** form on their Circle → Pending tab.

The alphabet deliberately excludes `I`, `L`, `O`, `0`, and `1` so read-aloud or handwritten codes round-trip reliably. The hyphen in `ABC-XYZ` is for readability only — `ABC-XYZ`, `ABCXYZ`, and `abc xyz` all normalise to the same code.

## Accepting an Invite

Three ways to accept, all land in the same place:

### From a link

Click the invite URL (eg `https://conflab.space/invite/ABC-XYZ`).

- **Not signed in?** You land on a sign-up form pre-bound to that invite. Create your account, and the friendship is materialised the moment registration succeeds.
- **Already signed in?** You land on an accept card at `/app/circle/invite/:token`. Click **Accept** to add the inviter to your Circle, or **Decline** to go back without touching the invite.

### Pasted code, in-app

On the Circle → **Pending** tab, click **Accept Invite** next to **+ New Invite**. An inline card opens with a text input. Paste `ABC-XYZ` (or the full URL — the URL prefix is stripped automatically) and submit. If the code is valid and not your own, you're friends immediately; otherwise an inline error tells you what went wrong.

### From a sign-up form

Visit `/invite/:token/register` directly if you want to sign up using a specific invite.

## Following and Unfollowing

Following is one-way: you subscribe to someone's activity without requiring their acceptance. Discoverable users appear on the **Discover** tab; click **Follow** on any card to start following them, and they move to your **Following** tab. Click **Unfollow** on a Following card to stop.

Users control their own discoverability on `/app/account` — new users default to **not discoverable**, so opt in explicitly if you want to appear on other people's Discover tabs.

## Unfriending

Click **Unfriend** on a Circle card. This soft-deletes the friendship — it's reversible: if either of you accepts a new invite from the other, the old friendship is restored rather than a fresh record created, preserving any history.

## Cancelling an Invite

Click **Cancel** on a Pending-tab card. The invite transitions to `:expired`; the token is dead and can't be accepted. This does not affect any friendships already created from it.

## Pagination

All four tabs paginate at 20 items per page. Use the page numbers or next/previous buttons at the bottom of each tab. Page state is per-tab: switching tabs resets the page of the tab you're leaving.

## Related

- [Account Settings](/app/help/using-conflab/account) — toggle your discoverable flag there.
- [Flabs & Conversations](/app/help/using-conflab/flabs) — the `/app/flab/invite/:token` flow is separate from this one.
- [Registration Gate](/app/help/admin/registration) — how admins switch between open, invite-only, and closed registration modes.
