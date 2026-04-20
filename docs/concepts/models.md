---
title: Models
---

# Models

**MODELS are foundation LLMs** such as Claude Opus, Claude Haiku, Claude Sonnet, and others. They are LLM provider configurations with no identity of their own. A model generates tokens; an [Agent](/app/help/concepts/agents) provides the identity those tokens belong to.

Models are not agents. Models have no personality, no memory between runs, and no standing presence in a flab. They are called into service by agents and by direct Lens execution.

## What a Model Is

A model configuration captures:

- **Provider** (`anthropic`, and others as they are added).
- **Model name** (`claude-opus-4-7`, `claude-haiku-4-5-20251001`, etc).
- **API key** stored in the daemon's secrets store.
- **Status flags** such as whether the key is valid and whether the model is the default.

Configuration lives in `~/.conflab/models.toml`. Sections are keyed by model name:

```toml
[models.claude-opus]
provider = "anthropic"
model = "claude-opus-4-7"

[models.claude-haiku]
provider = "anthropic"
model = "claude-haiku-4-5-20251001"
```

The daemon keeps the API keys separately in its secrets store, not in `models.toml`.

## Managing Models

From the CLI:

| Command                             | What it does                                           |
| ----------------------------------- | ------------------------------------------------------ |
| `conflab model list`                | List configured models and their status.               |
| `conflab model update <name>`       | Update a model's configuration.                        |
| `conflab model default <name>`      | Set the default model for Lens execution.              |
| `conflab model route <flab> <name>` | Route a flab to a specific model.                      |
| `conflab model unroute <flab>`      | Remove a flab's model override (fall back to default). |

From the daemon dashboard at `/app/daemon`, the Models section lists the same information with inline editing.

From MCP tools:

| Tool                  | What it does                              |
| --------------------- | ----------------------------------------- |
| `list_models`         | List configured models.                   |
| `update_model_config` | Update provider / model / keys.           |
| `set_default_model`   | Set the default model for Lens execution. |

## Default Model and Routing

Conflab picks a model for each Lens execution using this precedence:

1. An explicit model passed to the execution (e.g. `conflab run <lens> --model <name>`).
2. The flab's routed model, if the Lens is running in a flab context with routing set.
3. The agent's configured model, if the invocation is attributed to an agent.
4. The system default model set via `conflab model default`.

Routing lets you keep a specific flab on a faster or cheaper model without changing the global default.

## Models and Agents (Distinct Concepts)

A common source of confusion: an agent is not a model. The difference matters.

| AGENT                                     | MODEL                                       |
| ----------------------------------------- | ------------------------------------------- |
| Autonomous collaborator                   | Foundation LLM                              |
| Autonomous, stateful                      | Stateless token generator                   |
| Addressed with `^HANDLE`                  | Referenced by name (`claude-opus`)          |
| Stored in Conflab (Accounts domain)       | Stored in daemon (`~/.conflab/models.toml`) |
| One agent, many conversations, persistent | One model, many callers, no persistence     |
| `conflab auth`, `/app/account/agents`     | `conflab model`, `/app/daemon`              |

Before ST0077 these two concepts shared the word "agent" and produced frequent confusion. The rename normalises usage: AGENTS are collaborators, MODELS are LLMs. See [Agents](/app/help/concepts/agents) for the collaborator side.

## When You Care About Models

Most day-to-day Conflab usage does not require thinking about models. The system default handles typical Lens execution and agent responses. You care about models when:

- You are running an expensive Lens on lots of content and want a cheaper model.
- A specific flab benefits from a different model (e.g. a coding flab on Opus, a summarisation flab on Haiku).
- You are introducing a new provider.
- You are debugging why a Lens produced unexpected output and want to check which model ran it.
