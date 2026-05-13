---
title: Output Protocol
---

# Output Protocol

An **enforceable Lens** is a Lens with a `shape:` reference. When you run one, the daemon synthesises a `produce_output` tool from your Shape, hands it to the model alongside any other tools the Lens has enlisted, and waits for the model to call it. The model's `produce_output` arguments are validated against the Shape's schema and rendered through the Shape's body to produce the run's final output.

This is mechanically reliable -- the API enforces the schema, not the model's good intentions -- but it requires one piece of cooperation from the Lens author: the system_prompt must tell the model to call `produce_output`. The model is never forced to use any specific tool; it has to opt in. If your Lens has a `shape:` and the system_prompt does not mention `produce_output`, the run will fail loudly with `EnforceableShapeNotProduced` on first execution.

## What makes a Lens enforceable

A Lens is enforceable when its frontmatter `shape:` field points at a Shape file (`.shape.json` or `.shapemd`). The daemon:

1. Resolves the Shape (loads the file, lifts a `.shapemd` Template into a JSON schema if needed).
2. Synthesises a `produce_output` tool whose `input_schema` is the Shape's schema.
3. Adds `produce_output` to the Lens's tool set for the run.
4. Calls the LLM provider with `tool_choice: auto` -- the model picks freely.
5. When the model emits a `produce_output` tool_use block, the daemon validates the arguments against the schema and renders the Shape body using the validated arguments as field values.

A Lens with no `shape:` field, or with a `shape:` pointing at a string of inline prose, is NOT enforceable. The daemon never registers `produce_output`; the model emits prose; the daemon stores it verbatim. The Output protocol stanza below does not apply to non-enforceable Lenses.

## The Output protocol stanza

Every enforceable Lens needs an `## Output protocol` H2 section in its `system_prompt`, immediately after the lead paragraph that sets the Lens's voice and purpose. The canonical template:

```markdown
## Output protocol

- Always emit your final result by calling the `produce_output` tool with every required field filled in. Do not respond with prose alone; the daemon only consumes the tool call.
- Do not ask clarifying questions about the inputs. If a value is ambiguous, malformed, or missing, fall back to <lens-specific fallback rule> so the rendered entry surfaces the gap for the user to correct.
- One `produce_output` call per run; do not call any other tool unless <lens-specific tool policy>.
```

Two placeholders are tailored per Lens:

- `<lens-specific fallback rule>` -- the per-field default the Lens uses when input is unusable. Convention is to set every Shape field to a single short literal string the user can spot at-a-glance. Examples: `(coaching notes required)`, `(profile text required)`, `(insufficient input)`, or named placeholders like `{TITLE}` / `{URL}` / `{DATE}` / `{WEEK}`. Pick one register for the whole Lens; do not mix.
- `<lens-specific tool policy>` -- typically one of: `explicitly required by the article content` (when the Lens enlists a tool like `web-fetch` and the model legitimately needs it), `the input requires it` (open-ended; for Lenses that may compose multiple tools), or just omit the bullet's tail entirely if the Lens enlists no other tools.

The stanza is intentionally short. It carries three rules and nothing else: emit via `produce_output`, never block on clarifying questions (fall back to a placeholder so the user can fix it), one terminal call.

## A worked example

`~/.conflab/db/lenses/matts/reading-list-entry.lensmd` is a reference implementation. Its frontmatter declares a Shape:

```yaml
---
title: Reading List Entry
shape: matts/reading-list-entry.shape.json
---
```

Its system_prompt opens with a paragraph setting voice and purpose, then the Output protocol stanza:

```markdown
## Output protocol

- Always emit your final result by calling the `produce_output` tool with every required field filled in. Do not respond with prose alone; the daemon only consumes the tool call.
- Do not ask clarifying questions about the inputs. If a value is ambiguous, malformed, or missing, fall back to the placeholder rules below (`{TITLE}`, `{URL}`, `{DATE}`, `{WEEK}`) so the rendered entry surfaces the gap for the user to correct.
- One `produce_output` call per run; do not call any other tool unless explicitly required by the article content.
```

Three other reference Lenses follow the same pattern with Lens-specific fallback strings: `coaching-notes-summary` (`(coaching notes required)`), `linkedin-profile-summary` (`(profile text required)`), `meeting-summary` (`(insufficient input)`).

## What `EnforceableShapeNotProduced` means

This is the loud error you'll see if your enforceable Lens does not include the Output protocol stanza, or if the model decides to ignore it.

What it means: the Lens declared a Shape, the daemon registered `produce_output` and ran the multi-turn agent loop, the loop terminated normally on `end_turn`, but the model never emitted a valid `produce_output` call across any of the loop's turns. The daemon refuses to silently fall back to free-text output -- you wrote a `shape:` field expecting structural enforcement, and silent fallback would break that expectation invisibly.

How to debug:

1. **Open the Run in conflabc.** The "Loop trace" tab shows every turn: what the model said, what tool calls it made, what tool_results came back. If `produce_output` was never called, you'll see prose-only assistant turns.
2. **Check the system_prompt.** Does it have an `## Output protocol` H2 section? Does the section explicitly name `produce_output`? Add the stanza per the canonical template above and re-run.
3. **Check the lead paragraph.** A common drift: the system_prompt opens with structural rules ("Output structure: `<one or two sentence summary> + #Hashtags`") and the model treats those as authoritative, ignoring the `produce_output` instruction. Strip structural rules from the system_prompt -- the Shape owns structure.
4. **Check the model.** Some models (especially smaller / older ones) are less reliable about following multi-tool instructions. If the Lens works on Sonnet but fails on Haiku, the Lens may need a stricter Output protocol stanza.

## Cap overrides via `agent_loop:`

The agent loop has two hard caps:

- `max_iterations` -- ceiling on provider round-trips per run. Default `10`.
- `max_input_tokens` -- ceiling on cumulative input tokens summed across all turns. Default `200_000`.

Most Lenses never hit either cap. If yours legitimately needs more (eg a Lens that fetches multiple URLs and synthesises across them), set `agent_loop:` in the Lens's frontmatter:

```yaml
---
title: Multi-Source Synthesis
shape: matts/synthesis.shape.json
tools:
  - web-fetch
agent_loop:
  max_iterations: 20
  max_input_tokens: 250000
---
```

Both fields are independently optional. A Lens can raise `max_iterations` without touching `max_input_tokens` and the unset cap falls through to the operator-wide or compiled default.

The resolution order, highest precedence first:

1. The Lens's frontmatter `agent_loop:` map.
2. The operator's `daemon.toml` `[agent_loop]` section (`max_iterations` and `max_input_tokens`, each independently optional).
3. The compiled defaults (`10` and `200_000`).

When a cap fires the run fails with a clear error message naming the cap, the actual usage, and the override paths.

## Authoring checklist

For a new enforceable Lens:

- [ ] Frontmatter has a `shape:` field pointing at a real Shape file.
- [ ] Lead paragraph in `system_prompt` sets voice and purpose.
- [ ] Immediately below the lead paragraph: an `## Output protocol` H2 section with the three canonical bullets.
- [ ] Fallback rule is filled in (placeholder strings or named markers, consistent register across the whole Lens).
- [ ] Tool policy bullet's tail is filled in if the Lens enlists tools, omitted if it enlists none.
- [ ] No structural rules in the system_prompt (sections, format strings, "Output structure: ..." blocks). The Shape owns structure.
- [ ] If the Lens legitimately needs more than 10 turns or 200,000 input tokens: `agent_loop:` cap overrides set.
- [ ] Test run produces structured output via `produce_output` (visible in the Loop trace tab).
- [ ] Negative test: pass empty / off-topic input. The Lens should emit the fallback placeholders rather than ask clarifying questions.

## See also

- [Lenses](/app/help/concepts/lenses) -- the concept behind `.lensmd` files.
- [Shapes](/app/help/concepts/shapes) -- the output-structure primitive that lifts to `produce_output`.
- [Named Tools](/app/help/daemon/named-tools) -- how to enlist server-side tools alongside an enforceable Shape.
- [Prompt Templates](/app/help/daemon/templates) -- the `.lensmd` format reference.
