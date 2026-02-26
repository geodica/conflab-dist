---
title: Registration Gate
---

# Registration Gate

The registration gate controls whether new users can create accounts on your Conflab instance.

## How It Works

When `registration_enabled` is set to **off**:

- The `/register` page redirects to `/sign-in`
- User registration validation fails with "registration is currently closed"
- Existing users can still sign in normally
- Invite-based access still works for existing users joining flabs

When `registration_enabled` is set to **on** (the default):

- New users can register with email/password or magic link
- The registration page is fully accessible

## Toggling Registration

1. Go to [Admin Settings](/app/help/admin/settings)
2. Find the `registration_enabled` setting
3. Click the toggle to switch it on or off

The change takes effect immediately (within 5 seconds due to config caching).

## Use Cases

- **Private instances** — disable registration and manually create accounts for your team
- **Beta periods** — enable registration temporarily, then close it
- **Invite-only access** — disable public registration but share invite links with specific people
