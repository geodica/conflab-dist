# conflab v0.1.8

*Released 2026-03-23*

Workflow output, interactive prompts, pagination, and macOS UX overhaul.

## Added

- **Workflow step output** -- `bridge.output(table)` Lua function captures structured JSON output per step. Logs captured via `bridge.log()`. Both persisted in SQLite and exposed via GraphQL. Web UI renders per-step output with structured and JSON view modes.
- **Interactive workflow prompts** -- steps declare prompt schemas via `step.prompt` in Lua registration. Five field types: string, choice, boolean, number, text. Engine pauses at prompt steps (extending existing approval gate). Web UI renders auto-generated forms. `approveWorkflow` mutation accepts optional variables JSON.
- **Workflow pagination** -- `offset` parameter on `workflows` GraphQL query. 5 per page with Newer/Older controls in the web UI.
- **Workflow deletion** -- `deleteWorkflow` GraphQL mutation removes from in-memory manager and SQLite. Rejects deletion of active (running/paused) workflows. Web UI provides inline two-step confirmation.
- **Workflow UI (Model 3)** -- browser-bridged workflow management page at `/app/workflows`. Approve, abort, monitor progress, view structured output, copy variables.
- **Simplified macOS menu** -- menubar reduced from 15+ items to 8. Persistent Status Window with 5 tabs: Flabs, Workflows, Plugins, Logs, Settings.
- **Workflow-aware Prompts menu** -- macOS app detects `conflab-workflow` marker in templates. Workflow templates route to `runWorkflow` mutation instead of interpolate-and-clipboard. Variable form support for workflow templates with "Run Workflow" button.
- **Execution-level variables** -- final workflow variables exposed in GraphQL and rendered in the web UI with click-to-copy.

## Changed

- Workflow progress display fixed: 0-indexed `currentStep` now displayed as 1-indexed in both web and macOS app.
- Completed workflows section uses expand/collapse toggle (chevron icon) instead of DaisyUI checkbox collapse.
- Structured/JSON view toggle for workflow output rendering.
- Code quality improvements:
  - Deduplicated approve/abort event handlers into `push_workflow_mutation/3` (Highlander Rule).
  - Deduplicated StepResult construction in engine error paths (Highlander Rule).
  - Deduplicated onclick clipboard handler into `copy_js` lambda (Highlander Rule).
  - Deduplicated `current_step_prompt/1` call (Highlander Rule).
  - Flattened nested if-else in Swift `templateSelected` (PFIC).
  - Replaced if-let cascade with switch in Swift `extractValue` (PFIC).

## Upgrade

```bash
brew upgrade conflab
# or
curl -fsSL https://conflab.space/install.sh | bash
```
