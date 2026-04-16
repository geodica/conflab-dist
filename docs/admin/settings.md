---
title: Runtime Settings
---

# Runtime Settings

The **Admin** area at `/app/admin` lets administrators manage runtime configuration without redeploying the application. Only users with the **admin** or **superadmin** role can access it.

## Accessing the Admin Area

1. Click your avatar in the top-right corner.
2. Select **Admin** from the dropdown menu.
3. You land on the Admin **Overview** page.

If you are not an admin, you are redirected to the dashboard.

## Admin 2.0 Navigation

The Admin area is organised into seven sections:

| Section      | Path                      | Purpose                                             |
| ------------ | ------------------------- | --------------------------------------------------- |
| Overview     | `/app/admin`              | At-a-glance view of users, entries, pending items.  |
| Moderation   | `/app/admin/moderation`   | Review pending / flagged Catalog entries.           |
| Users        | `/app/admin/users`        | List, filter, and manage user accounts.             |
| Settings     | `/app/admin/settings`     | Runtime configuration (this page).                  |
| Integrations | `/app/admin/integrations` | Slack workspace bindings + other external surfaces. |
| Crawl        | `/app/admin/crawl`        | Crawl sources for the content pipeline.             |
| Curation     | `/app/admin/curation`     | Curator tools for the content pipeline.             |

Each section has its own docs page:

- [Moderation](/app/help/admin/moderation)
- [User Management](/app/help/admin/users)
- [Registration Gate](/app/help/admin/registration)
- [Slack Integration](/app/help/admin/slack-integration)
- [Content Pipeline (Crawl + Curation)](/app/help/admin/content-pipeline)

## The Settings Page

The Settings page displays every runtime configuration key as a table row. Boolean keys render as toggle switches; text keys render as inputs with a **Save** button.

### Boolean Settings

Boolean settings (values `on` / `off`) show a toggle. Click it to flip the setting. Changes take effect immediately.

### Text Settings

Text settings show an input field with the current value and a **Save** button. Edit the value and click Save to apply.

## How Runtime Config Works

Runtime settings are key-value pairs stored in PostgreSQL. Reads go through a `:persistent_term` cache with a 5-second TTL, so toggles propagate to all BEAM nodes within seconds.

Default values are seeded on application startup. Changing a setting in the admin UI overrides the default; the original default is not lost and is restored if the setting is deleted from the database.

Seeding source: `config :conflab, :runtime_config` in `config/config.exs`.

## Seeded Settings

The shipping defaults are:

| Key                     | Type    | Default | Purpose                                                                                |
| ----------------------- | ------- | ------- | -------------------------------------------------------------------------------------- |
| `registration_enabled`  | Boolean | `on`    | Whether new users can register. See [Registration Gate](/app/help/admin/registration). |
| `slack_enabled`         | Boolean | `on`    | Whether the Slack Bridge runs when `SLACK_APP_TOKEN` is set.                           |
| `stealth_enabled`       | Boolean | `on`    | Whether the stealth auth path is active (invite-gated preview flow).                   |
| `catalog_crawl_enabled` | Boolean | `off`   | Whether the Catalog crawler runs on schedule.                                          |
| `lensify_enabled`       | Boolean | `off`   | Whether the Lensify admin tool is available.                                           |
| `rate_limit.review`     | Integer | `20`    | Maximum reviews a user can create per day.                                             |
| `rate_limit.flag`       | Integer | `50`    | Maximum flags a user can raise per day.                                                |
| `rate_limit.publish`    | Integer | `10`    | Maximum Catalog entries a user can publish per day.                                    |
| `flag_threshold.entry`  | Integer | `5`     | Flags required before an entry auto-hides for re-review.                               |
| `flag_threshold.review` | Integer | `3`     | Flags required before a review auto-hides for re-review.                               |

Additional settings may appear over time. Keys not in this table are safe to edit through the admin UI but have no documented semantics here; check the module that reads the setting for behaviour.

## Programmatic Access

From Elixir:

```elixir
Conflab.RuntimeConfig.get("registration_enabled")     # "on" or "off"
Conflab.RuntimeConfig.enabled?("slack_enabled")        # true or false
Conflab.RuntimeConfig.set("rate_limit.publish", "15")  # :ok
Conflab.RuntimeConfig.toggle("lensify_enabled", true)  # :ok
```

The service module lives at `Conflab.RuntimeConfig`; the Ash domain is `Conflab.Core.RuntimeConfig`.

## Related

- [Registration Gate](/app/help/admin/registration) -- uses `registration_enabled`.
- [Moderation](/app/help/admin/moderation) -- uses `flag_threshold.*`.
- [Slack Integration](/app/help/admin/slack-integration) -- uses `slack_enabled`.
- [Content Pipeline](/app/help/admin/content-pipeline) -- uses `catalog_crawl_enabled` and `lensify_enabled`.
