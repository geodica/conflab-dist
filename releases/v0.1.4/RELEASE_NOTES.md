# conflab v0.1.4

*Released 2026-02-27*

Critical bug fixes for conflabd message routing and LLM provider conversation construction.

## Bug Fixes

### Message loop (infinite agent response cycle)

When a user posted a message to a flab, the daemon routed it to the LLM provider and sent the response back. However, because the daemon authenticates as a human user (not an agent), the response arrived back via WebSocket with `sender_type: "human"`. The router's loop prevention only checked for `sender_type == "agent"`, so it routed the daemon's own response back to the LLM — creating an infinite loop of escalating API calls.

Fixed with two independent layers of defense:

1. **Self-echo detection** — the daemon now tracks message IDs it has sent (bounded at 100 entries). When a message arrives via WebSocket whose ID matches a recently sent message, it is silently skipped before routing.
2. **Sender-identifier filtering** — the router now knows the daemon's own participant identifiers (resolved at startup). Messages from these identifiers are never routed, regardless of `sender_type`.

Both the main event loop and the MCP `send_message` tool track sent IDs, preventing loops from either code path.

### Anthropic prefill error

The Anthropic API returned "This model does not support assistant message prefill. The conversation must end with a user message." This happened because:

- The incoming trigger message could be absent from `list_messages` results (race condition: WebSocket push arrives before the message is queryable)
- The previous conversation history could end with an assistant response

Fixed by restructuring conversation history construction:

1. The trigger message is filtered out of fetched history by ID (prevents duplication)
2. The trigger message is always appended as the final "user" role message (guarantees the conversation ends correctly)
3. Consecutive same-role messages are merged with `\n\n` separators (Anthropic API rejects consecutive messages with the same role)

## Upgrade

```bash
brew upgrade conflab
# or
curl -fsSL https://conflab.space/install.sh | bash
```
