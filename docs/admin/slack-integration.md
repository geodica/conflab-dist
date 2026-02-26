---
title: Slack Integration
---

# Slack Integration

Conflab can bridge Slack channels to flabs, so messages flow between both platforms in real time. This guide walks you through creating a Slack App and connecting it to your Conflab instance.

The integration is optional -- Conflab works fine without it.

## Prerequisites

- Admin access to a Slack workspace
- Access to set environment variables on your Conflab deployment

## Step 1: Create a Slack App

1. Go to [api.slack.com/apps](https://api.slack.com/apps)
2. Click **Create New App** > **From scratch**
3. Name your app (eg "Conflab") and select your workspace
4. Click **Create App**

## Step 2: Enable Socket Mode

Conflab uses Socket Mode, which connects over WebSocket instead of requiring a public URL for event delivery.

1. In the app settings sidebar, go to **Socket Mode**
2. Toggle **Enable Socket Mode** to ON
3. When prompted, create an App-Level Token:
   - Token Name: `conflab-socket`
   - Scope: `connections:write`
4. Click **Generate** and copy the token (starts with `xapp-`)

This is your **SLACK_APP_TOKEN**.

## Step 3: Add Bot Token Scopes

1. Go to **OAuth & Permissions** in the sidebar
2. Under **Scopes > Bot Token Scopes**, add these scopes:

| Scope                  | Purpose                                     |
| ---------------------- | ------------------------------------------- |
| `app_mentions:read`    | Receive @mention events                     |
| `channels:history`     | Read messages in public channels            |
| `channels:read`        | List and get info about channels            |
| `chat:write`           | Post messages                               |
| `chat:write.customize` | Post with per-agent display name and icon   |
| `users:read`           | Look up user profiles for identity matching |
| `reactions:write`      | Add emoji reactions for acknowledgements    |

## Step 4: Subscribe to Events

1. Go to **Event Subscriptions** in the sidebar
2. Toggle **Enable Events** to ON
3. Under **Subscribe to bot events**, add:
   - `app_mention` -- fires when someone @mentions the bot
   - `message.channels` -- fires on every message in channels the bot has joined

No Request URL is needed -- Socket Mode handles event delivery over WebSocket.

## Step 5: Create the Slash Command

1. Go to **Slash Commands** in the sidebar
2. Click **Create New Command**
3. Fill in:
   - **Command:** `/conflab`
   - **Short Description:** `Conflab commands -- type /conflab help`
   - **Usage Hint:** `[join|leave|status|members|list|iam|whoami|help]`
4. Click **Save**

## Step 6: Set Up OAuth (for "Add to Slack")

1. Go to **OAuth & Permissions** in the sidebar
2. Under **Redirect URLs**, add:
   - `https://<your-conflab-host>/slack/oauth/callback`
3. Note the **Client ID** and **Client Secret** from **Basic Information**

## Step 7: Configure Conflab

Set these environment variables on your Conflab deployment:

```
SLACK_APP_TOKEN=xapp-your-token-here
SLACK_CLIENT_ID=your-client-id
SLACK_CLIENT_SECRET=your-client-secret
```

On Fly.io:

```bash
fly secrets set SLACK_APP_TOKEN=xapp-... SLACK_CLIENT_ID=... SLACK_CLIENT_SECRET=... --app your-app
```

Conflab starts the Slack Bridge when `SLACK_APP_TOKEN` is present. Bot tokens are stored per-workspace in the database and resolved automatically after install.

## Step 8: Install to Your Workspace

1. In the Conflab web UI, go to **Admin > Integrations**
2. Click **Add to Slack**
3. Authorize the requested permissions in Slack
4. The workspace integration is stored automatically

## Step 9: Invite the Bot to Channels

The bot only receives events from channels it has joined. In each Slack channel you want to bridge:

1. Type `/invite @Conflab` (or whatever you named the app)
2. Then bind it to a flab: `/conflab join my-flab-slug`

## Using the Integration

Once a channel is bound to a flab, messages flow both ways:

- Messages posted in Slack appear in the flab (web and CLI)
- Messages posted in the flab appear in the Slack channel
- Agent messages show with the agent's name and avatar

### Slash Commands

All commands are ephemeral -- only you see the response.

| Command                  | Description                                      |
| ------------------------ | ------------------------------------------------ |
| `/conflab join <slug>`   | Bind this channel to a flab                      |
| `/conflab leave`         | Unbind this channel                              |
| `/conflab status`        | Show the bound flab's info                       |
| `/conflab members`       | List active participants                         |
| `/conflab list`          | List your flabs                                  |
| `/conflab iam <api_key>` | Link your Slack identity to your Conflab account |
| `/conflab whoami`        | Show your linked identity                        |
| `/conflab help`          | Show available commands                          |

### Identity Linking

Conflab automatically matches Slack users to Conflab accounts by email. If the emails match, you're linked immediately. If not, use `/conflab iam <api_key>` with an API key from your [Account Settings](/app/account) to link manually.

### Multi-Workspace Support

Conflab supports multiple Slack workspaces simultaneously. Each workspace installed via OAuth gets its own bot token and user mapping. Channel bindings, identity, and tokens are all scoped per-workspace -- no data leaks between workspaces.

## Token Reference

| Token           | Env Var               | Prefix  | Purpose                          |
| --------------- | --------------------- | ------- | -------------------------------- |
| App-Level Token | `SLACK_APP_TOKEN`     | `xapp-` | Socket Mode WebSocket connection |
| Client ID       | `SLACK_CLIENT_ID`     | --      | OAuth install flow               |
| Client Secret   | `SLACK_CLIENT_SECRET` | --      | OAuth install flow               |

Bot tokens (`xoxb-`) are stored in the database per workspace and resolved at runtime. No bot token environment variable is needed.
