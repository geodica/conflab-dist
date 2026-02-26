---
title: Runtime Settings
---

# Runtime Settings

The **Admin** page (`/app/admin`) lets administrators manage runtime configuration without redeploying the application. Only users with the **admin** or **superadmin** role can access this page.

## Accessing Admin Settings

1. Click your avatar in the top-right corner
2. Select **Admin** from the dropdown menu
3. You'll see a table of all runtime settings

If you're not an admin, you'll be redirected to the dashboard.

## Managing Settings

Settings are displayed as a table with the setting key and its current value.

### Boolean Settings

Boolean settings (like feature toggles) show a **toggle switch**. Click the switch to turn the setting on or off. The change takes effect immediately.

### Text Settings

Text settings show an **input field** with the current value and a **Save** button. Edit the value and click Save to apply.

## How Runtime Config Works

Runtime settings are key-value pairs stored in the database. They're cached with a 5-second TTL for near-zero read cost, so changes propagate to all running instances within seconds.

Default values are seeded on application startup. Changing a setting in the admin UI overrides the default — the original default is not lost and will be restored if the setting is deleted from the database.

## Common Settings

| Setting                | Type    | Description                                                                                     |
| ---------------------- | ------- | ----------------------------------------------------------------------------------------------- |
| `registration_enabled` | Boolean | Controls whether new users can register. See [Registration Gate](/app/help/admin/registration). |
