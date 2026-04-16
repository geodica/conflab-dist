---
title: User Management
---

# User Management

The **Users** page at `/app/admin/users` is where admins list, filter, and manage user accounts. Only users with the **admin** or **superadmin** role can access it.

## Accessing the Page

From the admin area (`/app/admin`), click **Users** in the left navigation. The page loads the full user list with filtering and pagination.

## The User Table

Each row represents one user account. Visible columns:

- **Handle** -- the user's `@username`.
- **Email** -- registered email address.
- **Role** -- one of `user`, `admin`, `superadmin`.
- **Created at** -- registration timestamp.
- **Last active** -- most recent sign-in or API activity.
- **Status** -- active, suspended, or deleted.
- **Actions** -- inline controls for role changes, suspension, and deletion.

## Filtering

The filter row above the table accepts:

- **Text search** -- matches handle and email.
- **Role filter** -- show only `user`, `admin`, or `superadmin` accounts.
- **Status filter** -- active / suspended / deleted.

Filter state is reflected in the URL so filtered views are linkable.

## Role Management

A user's role controls what they can do. The three roles:

| Role         | Can do                                                                              |
| ------------ | ----------------------------------------------------------------------------------- |
| `user`       | Participate in flabs, publish to the Catalog, fork and rate entries.                |
| `admin`      | Everything a user can do, plus moderate entries, manage other users, edit settings. |
| `superadmin` | Everything an admin can do, plus elevate other users to admin.                      |

Role changes are recorded in the admin audit log. Only a `superadmin` can create another `superadmin`.

From a user row, admins can:

- **Elevate to admin** (superadmin only).
- **Demote to user** (admin or superadmin).
- **Remove role** back to user.

## Suspension

Admins can suspend a user account without deleting it. A suspended account:

- Cannot sign in.
- Is hidden from flab participant lists (their historical messages remain).
- Cannot publish, fork, like, rate, or report.
- Has existing Catalog entries marked as `pending` for re-review.

Suspension is reversible. The user can be reinstated at any time. Suspension is the tool for "stop now, decide later"; deletion is for "this account is done".

## Deletion

Deletion is permanent. A deleted user:

- Has their profile anonymised (handle nulled, email removed).
- Has their Catalog entries set to `rejected`, preserving provenance for forks but removing them from public view.
- Has their API keys revoked.
- Cannot be restored.

The UI requires explicit confirmation before deletion proceeds.

## Audit Log

Every user-management action (role change, suspension, deletion, unsuspension) is logged with:

- Acting admin identity.
- Target user identity.
- Action taken.
- Previous state.
- New state.
- Timestamp.

The log is visible at the bottom of the Users page (superadmin only).

## The `RequireAdmin` Plug

All admin routes are protected by the `ConflabWeb.Plugs.RequireAdmin` plug, which enforces role checks on every request. Non-admin users hitting any `/app/admin/*` route are redirected to the dashboard.

## Related

- [Runtime Settings](/app/help/admin/settings) -- admin area navigation and the broader settings catalogue.
- [Moderation](/app/help/admin/moderation) -- content-side moderator actions.
- [Registration Gate](/app/help/admin/registration) -- controlling new account creation.
