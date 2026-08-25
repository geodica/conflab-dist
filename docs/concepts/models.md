---
title: Models
---

# Models

**MODELS are foundation LLMs** such as Claude Opus, Claude Haiku, Claude Sonnet, and others. They are LLM provider configurations with no identity of their own. A model generates tokens; an [Agent](/app/help/concepts/agents) provides the identity those tokens belong to.

Models are not agents. Models have no personality, no memory between runs, and no standing presence in a flab. They are called into service by agents and by direct Lens execution.

## What a Model Is

A model configuration captures:

- **Provider** (`anthropic`, `openai`, `google`, and others as they are added).
- **Model identifier** -- the provider's own name for a model, such as `claude-opus-5`. You rarely write one down; see [Model Symbols](#model-symbols) below.
- **API key**, stored once per provider and shared by every model naming that provider.
- **Status flags** such as whether the key verifies and whether the model is the default.

Configuration lives in `models.toml` under your Conflab config directory. `conflab daemon init` generates it, and what it writes is the part that is genuinely yours -- your key and your chosen default:

```toml
[providers.anthropic]
api_key = "sk-ant-..."

[routing]
default_model = "ANTHROPIC_OPUS_LATEST"
```

**Your provider API keys are stored in this file, in plaintext.** The file is written with your system's default permissions, so treat it as you would any credential file. The plaintext key never leaves the daemon -- no surface, including the macOS app and the MCP tools, ever reads it back out.

## Model Symbols

A **symbol** names the role a model plays rather than a particular generation of it. `ANTHROPIC_OPUS_LATEST` means "Anthropic's most capable line"; a shipped seed binds that role to today's identifier, and you name only the role.

This matters because providers retire identifiers. A configuration that pinned `gemini-1.5-flash` kept working right up until it did not, and the failure arrived as an HTTP error that reads like a rejected API key. Naming the role instead means a retirement is something Conflab absorbs rather than something you debug.

Conflab ships eight symbols:

| Symbol                       | Provider    | Role                                                     |
| ---------------------------- | ----------- | -------------------------------------------------------- |
| `ANTHROPIC_OPUS_LATEST`      | `anthropic` | Most capable line. The shipped default.                  |
| `ANTHROPIC_SONNET_LATEST`    | `anthropic` | Balanced line -- capability against cost and latency.    |
| `ANTHROPIC_HAIKU_LATEST`     | `anthropic` | Fastest and cheapest line. Bulk and classification work. |
| `ANTHROPIC_FABLE_LATEST`     | `anthropic` | Long-form narrative line.                                |
| `OPENAI_GPT_LATEST`          | `openai`    | Flagship line.                                           |
| `OPENAI_GPT_MINI_LATEST`     | `openai`    | Small line. Bulk and classification work.                |
| `GOOGLE_GEMINI_PRO_LATEST`   | `google`    | Most capable line.                                       |
| `GOOGLE_GEMINI_FLASH_LATEST` | `google`    | Fast line.                                               |

`conflab model list` shows the effective table -- every shipped symbol, plus anything you pinned -- and says which of the two answered for each entry.

### Pinning a model

You win. Adding a `[models.<name>]` entry pins that name to an identifier you chose, and a pin always beats the seed:

```toml
[models.claude-opus]
provider = "anthropic"
model = "claude-opus-5"
```

The trade is that a pin stops tracking updates. The seed will move to the next generation and your pinned entry will not, which is the correct behaviour for a machine that pinned something deliberately and the wrong one for a machine that just wanted a sensible default.

A provider's live catalogue is a third thing, and Conflab compares against it rather than adopting from it. An upstream change is reported to you; it never rewrites your configuration behind your back.

## Managing Models

From the CLI:

| Command                               | What it does                                                                                                                                                                                                         |
| ------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `conflab model list`                  | List the effective models and their status, and where each binding came from.                                                                                                                                        |
| `conflab model update <name>`         | Update a model's configuration.                                                                                                                                                                                      |
| `conflab model default <name>`        | Set the default model for Lens execution.                                                                                                                                                                            |
| `conflab model route <flab> <name>`   | Route a flab to a specific model.                                                                                                                                                                                    |
| `conflab model unroute <flab>`        | Remove a flab's model override (fall back to default).                                                                                                                                                               |
| `conflab model verify-key <provider>` | Ask the provider whether the stored key is accepted. Add `--api-key <key>` to verify a candidate and store it only if the provider accepts it, or `--api-key <key> --no-save` to check one without writing anything. |

From the daemon dashboard at `/app/daemon`, the Models section lists the same information with inline editing.

From MCP tools:

| Tool                            | What it does                                               |
| ------------------------------- | ---------------------------------------------------------- |
| `list_models`                   | List configured models.                                    |
| `update_model_config`           | Update provider / model / keys.                            |
| `set_default_model`             | Set the default model for Lens execution.                  |
| `verify_provider_key`           | Check whether the stored key for a provider is accepted.   |
| `verify_candidate_provider_key` | Check a candidate key and write nothing, whatever it says. |
| `verify_and_save_provider_key`  | Check a candidate key and keep it only if it is accepted.  |

## Default Model and Routing

Conflab picks a model for each Lens execution using this precedence:

1. An explicit model passed to the execution (eg `conflab run <lens> --model <name>`).
2. The flab's routed model, if the Lens is running in a flab context with routing set.
3. The agent's configured model, if the invocation is attributed to an agent.
4. The system default model set via `conflab model default`.

Routing lets you keep a specific flab on a faster or cheaper model without changing the global default.

## Models and Agents (Distinct Concepts)

A common source of confusion: an agent is not a model. The difference matters.

| AGENT                                     | MODEL                                              |
| ----------------------------------------- | -------------------------------------------------- |
| Autonomous collaborator                   | Foundation LLM                                     |
| Autonomous, stateful                      | Stateless token generator                          |
| Addressed with `^HANDLE`                  | Referenced by name (`claude-opus`)                 |
| Stored in Conflab (Accounts domain)       | Stored in daemon (`~/.config/conflab/models.toml`) |
| One agent, many conversations, persistent | One model, many callers, no persistence            |
| `conflab auth`, `/app/account/agents`     | `conflab model`, `/app/daemon`                     |

These two concepts used to share the word "agent" and produced frequent confusion; the terminology is now normalised: AGENTS are collaborators, MODELS are LLMs. See [Agents](/app/help/concepts/agents) for the collaborator side.

## When You Care About Models

Most day-to-day Conflab usage does not require thinking about models. The system default handles typical Lens execution and agent responses. You care about models when:

- You are running an expensive Lens on lots of content and want a cheaper model.
- A specific flab benefits from a different model (eg a coding flab on Opus, a summarisation flab on Haiku).
- You are introducing a new provider.
- You are debugging why a Lens produced unexpected output and want to check which model ran it.
