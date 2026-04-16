---
title: Registration Gate
---

# Registration Gate

The registration gate controls whether new users can create accounts on your Conflab instance. It is a single runtime setting (`registration_enabled`) evaluated at two points: the `/register` route and the user-creation validator.

## How It Works

When `registration_enabled` is `off`:

- The `/register` route redirects to `/sign-in`.
- The user-creation validator (`Conflab.Accounts.User.Validations.RegistrationOpen`) rejects submissions with the message "registration is currently closed".
- Existing users can still sign in normally.
- Invite-based access still works for existing users joining flabs.

When `registration_enabled` is `on` (the default):

- New users can register with email and password or magic link.
- The registration page is fully accessible.

The setting is read live through `Conflab.RuntimeConfig.enabled?("registration_enabled")`. Both the route redirect and the validator hit the same cached value.

## Toggling Registration

1. Go to [Runtime Settings](/app/help/admin/settings).
2. Find `registration_enabled` in the table.
3. Click the toggle to switch it on or off.

The change takes effect within the cache TTL (5 seconds, default).

## Use Cases

- **Private instances.** Disable registration and manually create accounts for your team.
- **Beta periods.** Enable registration temporarily, then close it.
- **Invite-only access.** Disable public registration while still allowing existing users to invite each other via flab invite codes.

## Related

- [Runtime Settings](/app/help/admin/settings) -- the full list of seeded settings.
- [Creating an Account](/app/help/getting-started/creating-account) -- the user-facing sign-up flow.
