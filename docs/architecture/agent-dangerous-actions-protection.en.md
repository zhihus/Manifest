# Protection from Dangerous Agent Actions

# Metadata
> **Status: draft**  
> **Type: document**  
> **Version: 1.0.0**  
> **Updated: 2026-11-27**  

# Description
A prospective architectural plan for protecting Manifest projects from
dangerous actions that an AI agent may perform through its tools. The
document describes the goal and boundaries of protection, a
preliminary set of dangerous-action categories, the interception
mechanism and the full lifecycle of the `allow` / `ask` / `deny`
decisions, interaction with agents and tools, limitations, failure
scenarios, and security requirements. Protection is treated as a
standalone Manifest capability: the concrete enforcement approach
(universal Git mechanisms, mechanisms of a specific AI-harness) is
the subject of separate design and is not tied to a specific harness
in this document.

## 1. Goal and Boundaries

### 1.1. Goal

Protect the project from dangerous actions that an AI agent performs
through its tools. The mechanism makes a decision for each call:
allow it automatically by approved policy (`allow`), request user
confirmation (`ask`), or reject it (`deny`).

The mechanism does not perform a dangerous action itself and does not
decide on behalf of the user where confirmation is required: it
interrupts the call, passes the request for confirmation, and
delivers the user's response to the agent. Automatic decisions
(`allow` and `deny`) are made by a pre-approved policy, not by the
user at the moment of the call.

### 1.2. Boundaries

- Protection acts at the level of tool calls (before their execution),
  not only at the commit stage.
- The main scope of the function is protection of tool calls.
  Interception of user prompts and agent messages is separate future
  directions (see §7).
- The mechanism does not replace task approval, roles, and workflow
  gates: it complements them at the level of tool execution.
- The mechanism does not change the architecture of other Manifest
  components.

### 1.3. Place in the Manifest Architecture

Protection from dangerous actions is a standalone prospective
Manifest capability, not a function of a single component.

`context-files-guard` is a related existing mechanism and a special
case of this protection: it protects a specific class of objects —
context files (see `architecture-brief.ru.md`, section «Защита
контекстных файлов»). The dangerous-action protection capability
covers a broader class of actions; `context-files-guard` is one of
its special cases, not the component that automatically handles all
dangerous actions.

The principle "a technical prohibition takes priority over agent
instructions" applies to dangerous actions as well: the prohibition
is configured by the user and is not overridden by a prompt.

## 2. Categories of Dangerous Actions

Categories are defined by the `tool_input` of a call, not by the
semantics of intent. Below is a preliminary set of categories: it is
a starting point for design, not approved default settings.

- destructive file operations (`rm -rf` and analogues);
- writing to system and protected paths;
- executing external code (`curl … | sh`, download and run);
- sending data outward (network, API);
- rewriting Git history (`reset --hard`, `rebase`, force-push);
- modifying protected context files.

The exact set of categories, their thresholds, and the decision for
each are a design topic (see §9).

## 3. Interception Mechanism

### 3.1. Interception Point

Interception happens before a tool call is executed. The mechanism
receives the full input of the call (tool name and its arguments) and
makes a decision: allow (`allow`), request confirmation (`ask`), or
reject (`deny`).

### 3.2. Determining "Danger"

"Danger" is determined by a set of rules over `tool_input` (patterns),
not by semantic analysis of intent. For typical cases this is enough;
extending to semantics is a possible development (see §9).

### 3.3. Policy and Enforcement Mechanisms

The universal security policy (what is considered dangerous, which
decision for each category) is separated from the concrete
mechanisms that enforce it. The policy is harness-independent; the
enforcement mechanisms are harness-dependent.

The priority of enforcement mechanisms is aligned with the Manifest
decision (see `architecture-brief.ru.md`, section «Автоматизированный
контроль»):

- first level — universal Git mechanisms (Git Hooks and control
  scripts, installed by `manifest-init`);
- second level — mechanisms of a specific AI-harness (for example,
  ZCode); for the other harnesses the principles and an example
  implementation are fixed.

Manifest does not develop its own hooks manager and does not manage
the settings of a specific AI-harness. The protection behavior is not
guaranteed identical on all harnesses: it is identical where the
universal level (Git) acts, and depends on the capabilities of the
specific harness at the second level.

### 3.4. Lifecycle of the `allow` / `ask` / `deny` Decisions

For each call the mechanism returns one of three decisions.

`allow`:

- the call is allowed automatically by approved policy;
- the call returns to the executor and is performed without user
  involvement;
- user confirmation is not required.

`ask`:

- the mechanism interrupts execution and passes the user a request
  for confirmation with a description of the action (tool and
  arguments);
- the user confirms or rejects;
- on confirmation the call returns to the executor and is performed;
- on rejection the call is not performed and the agent is passed the
  reason;
- the confirmation is bound to the specific call: re-execution of the
  same call and applying the confirmation to another call are
  excluded. The concrete binding method (call identifier, one-time
  token, re-trigger control) is an open architectural decision (see
  §9).

`deny`:

- the call is rejected by approved policy;
- the agent is passed the rejection reason;
- the call is not performed and is not passed to the user.

## 4. Passing the Request to the User

On an `ask` decision the mechanism interrupts execution and passes the
user a request for confirmation.

The delivery channel (interface, input field, notification) is a
design topic. Requirement: the user receives a description of the
action (tool and arguments) and can set a response — confirm or
reject.

## 5. Handling the User's Response

The user's response to an `ask` decision reaches the agent through two
paths:

- as the rejection reason (the agent sees why the action was not
  performed);
- as additional context (the agent sees the user-set response).

For an empty response, the behavior is defined by policy (see §9):
the default is to reject with a system message.

## 6. Interaction with Agents and Tools

- The mechanism works at the "agent → tool" boundary: it sees the
  input of a call and returns a decision to the executor.
- The agent does not receive direct permission for an action that
  requires confirmation: the user makes the decision.
- Automatic decisions (`allow` and `deny`) are made by approved
  policy, without user involvement at the moment of the call.
- The mechanism does not rewrite the agent's intent: it can only
  reject, request confirmation, or let the call pass. Rewriting the
  call input (for example, replacing a dangerous path) is a possible
  development (see §9).

## 7. Limitations and Failure Scenarios

1. "Danger" is determined by patterns, not by semantics: false
   positives and misses are possible.
2. Interception is synchronous: the mechanism must be fast so it does
   not block the agent's work.
3. The protection behavior is not identical on all harnesses: the
   universal level (Git) acts identically, the second level depends
   on the capabilities of the specific harness.
4. If the confirmation channel is unavailable (the user did not
   respond), the action is not performed: the safe default behavior
   is to reject.

Interception of user prompts and the agent's own messages is outside
the boundaries of the current function (protection of tool calls) and
is considered as separate future directions: for a prompt the
interception point is different (before prompt processing), for the
agent's output there is no direct interception of the text.

## 8. Security Requirements

The requirements are separated by data class:

- Secrets and sensitive data: not written to Git, logs, or
  command-line arguments.
- Contents of intercepted calls: writing to Git, logs, and
  command-line arguments is prohibited by default; the question of
  logging is an open decision (see §9).
- Safe audit metadata: may be written for audit; the audit
  composition is not adopted and is determined by the user's decision
  (see §9).

Additionally:

- The prohibition is configured by the user and is not overridden by
  agent instructions or a prompt.
- The mechanism stores no secrets: it passes only the action
  description and the user's response.
- The default failure is safe: on an error or timeout the action is
  rejected, not performed.

## 9. Open Questions (Require Design)

1. The exact set of "dangerous" action categories, their thresholds,
   and the decision for each category.
2. The channel for passing the request to the user (interface, field,
   notification).
3. Behavior on an empty response: reject or let it pass.
4. The audit composition: whether interception events are logged,
   which metadata, and where they are stored.
5. Extending to semantic analysis of intent (beyond patterns).
6. Rewriting the call input (replacing a dangerous path with a safe
   one).
7. Interface localization (en/ru).
8. The method of binding a confirmation to a specific call: excluding
   re-execution and applying the confirmation to another call.

## 10. Possible Implementation Stages

1. Fixing the categories and the policy (this document → decision).
2. A prototype of interception on a specific harness (see Appendix A).
3. The channel for passing the request and handling the response.
4. Integration with `context-files-guard` and Git Hooks.
5. Audit log (by decision).

## Appendix A. Prototype on ZCode (Reference)

ZCode supports hook events that can be used as a prototype of the
interception mechanism. This is one of the possible implementation
approaches, not an architectural dependency of Manifest.

### A.1. Events and Interception Point

ZCode supports hook events, among which `PreToolUse` is the
interception point before a tool is executed. The matcher is a
case-sensitive regex over the tool name, for example
`Bash|Write|Edit`; without a matcher it fires on all tools.

### A.2. Hook Input and Output

The hook receives on stdin a JSON with the full input of the call
(`tool_name`, `tool_input`, etc.) and returns a JSON decision. For
`PreToolUse` the following fields are supported:

| Field | Meaning |
|---|---|
| `permissionDecision` | `deny` — reject; `ask` — request confirmation; `allow` — let it pass. |
| `permissionDecisionReason` | The reason text; reaches the agent as the rejection reason. |
| `additionalContext` | Additional context; injected into the conversation. |
| `updatedInput` | Rewritten input (an additional capability). |

Exit codes: `0` — let it pass, `2` — block (deny), another non-zero —
error. The output schema is strict: an extra key drops the hook
effect.

### A.3. Response Delivery Channel

In the prototype the user's response is stored in a plugin data file:
the interface (panel) writes the file, and the hook reads it on
interception. An alternative channel is the manifest `userConfig`, but
`${user_config.<key>}` substitution works only in MCP-server
configuration, not in hook commands, so the panel is chosen as the
primary channel.

### A.4. ZCode Primitives

| Primitive | Purpose |
|---|---|
| Hook events (`PreToolUse` and others) | Interception points before a tool is executed. |
| `createCompatibleHookStdin` | Passing the call input to the hook script via stdin (JSON). |
| `processHookOutput` | Parsing the hook output (decision, reason, context, `updatedInput`). |
| Context injection | Hook response reaches the agent as additional context and rejection reason. |
| `ui.surfaces` in the manifest | A persistent interface panel with an HTML page. |
| `ZCODE_PLUGIN_DATA` | A shared data directory for the hook and the MCP server. |

### A.5. Prototype Size Estimate

| File | Estimate |
|---|---|
| `plugin.json` (manifest) | ~20 lines |
| `hooks.json` (hook registration) | ~10 lines |
| `check.mjs` (interception script) | 60–100 lines |
| `server.mjs` (MCP server) | 100–150 lines |
| `panel.html` (panel page) | 50–80 lines |

The skeleton is generated by the `plugin-creator` skill; the panel
page follows the `zcode-mcp-app-dev` sample. Installation is through
the local marketplace and Settings → Plugin Management.