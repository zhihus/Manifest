# Protection from Dangerous Agent Actions

# Metadata
> **Status: draft**  
> **Type: document**  
> **Version: 1.0.0**  
> **Updated: 2026-11-27**  

# Description
A prospective architectural plan for protecting Manifest projects from
dangerous actions that an AI agent may perform through its tools. The
document describes the goal and boundaries of protection, categories
of dangerous actions, the interception mechanism, passing the request
for confirmation to the user, handling the response, interaction with
agents and tools, limitations, failure scenarios, and security
requirements. The concrete implementation approach (including the hook
mechanism of a specific harness) is the subject of separate design: in
this document it is named as a possible prototype, not as an
architectural dependency.

## 1. Goal and Boundaries

### 1.1. Goal

Protect the project from dangerous actions that an AI agent performs
through its tools, and ensure agreed user intervention before such an
action is executed.

The mechanism does not execute a dangerous action automatically and
does not decide on behalf of the user: it interrupts the action,
passes the request for confirmation, and delivers the user's response
to the agent.

### 1.2. Boundaries

- Protection acts at the level of tool calls (before their execution),
  not only at the commit stage.
- The mechanism is not tied to a specific AI harness, provider, or
  version: Manifest defines the behavior, not a concrete
  implementation.
- The mechanism does not replace task approval, roles, and workflow
  gates: it complements them at the level of tool execution.
- The mechanism does not change the architecture of other Manifest
  components.

### 1.3. Place in the Manifest Architecture

Protection from dangerous actions is a prospective Manifest capability
that extends the `context-files-guard` component (see
`architecture-brief.ru.md`, section «Защита контекстных файлов»).
The principle "a technical prohibition takes priority over agent
instructions" applies to dangerous actions as well: the prohibition is
configured by the user and is not overridden by a prompt.

## 2. Categories of Dangerous Actions

Categories are defined by the `tool_input` of a call, not by the
semantics of intent. The basic set (by default):

- destructive file operations (`rm -rf` and analogues);
- writing to system and protected paths;
- executing external code (`curl … | sh`, download and run);
- sending data outward (network, API);
- rewriting Git history (`reset --hard`, `rebase`, force-push);
- modifying protected context files.

The exact set of categories and their thresholds is a design topic
(see §9).

## 3. Interception Mechanism

### 3.1. Interception Point

Interception happens before a tool call is executed. The mechanism
receives the full input of the call (tool name and its arguments) and
makes a decision: execute, request confirmation, or reject.

### 3.2. Determining "Danger"

"Danger" is determined by a set of rules over `tool_input` (patterns),
not by semantic analysis of intent. For typical cases this is enough;
extending to semantics is a possible development (see §9).

### 3.3. Check Result

For each call the mechanism returns one of the decisions:

- `allow` — execute without confirmation;
- `ask` — require user confirmation;
- `deny` — reject and pass the reason to the agent.

## 4. Passing the Request to the User

On an `ask` decision or on interception of a dangerous action, the
mechanism interrupts execution and passes a request for confirmation
to the user.

The delivery channel (interface, input field, notification) is a
design topic. Requirement: the user receives a description of the
action (tool and arguments) and can set a response.

## 5. Handling the User's Response

The user's response reaches the agent through two paths:

- as the rejection reason (the agent sees why the action was not
  performed);
- as additional context (the agent sees the user-set response).

For an empty response, the behavior is defined by policy (see §9):
the default is to reject with a system message.

## 6. Interaction with Agents and Tools

- The mechanism works at the "agent → tool" boundary: it sees the
  input of a call and returns a decision to the executor.
- The agent does not receive direct permission for a dangerous
  action: the user makes the decision.
- The mechanism does not rewrite the agent's intent: it can only
  reject, request confirmation, or let the call pass. Rewriting the
  call input (for example, replacing a dangerous path) is a possible
  development (see §9).

## 7. Limitations and Failure Scenarios

1. "Danger" is determined by patterns, not by semantics: false
   positives and misses are possible.
2. Interception is synchronous: the mechanism must be fast so it does
   not block the agent's work.
3. If the "dangerous" item is the user's prompt rather than a tool
   call, the interception point is different (before prompt
   processing); the same decision, a different point.
4. If the "dangerous" item is the agent's own output, there is no
   direct interception of the text: the mechanism can require
   continuation but cannot rewrite the message.
5. If the confirmation channel is unavailable (the user did not
   respond), the action is not performed: the safe default behavior
   is to reject.

## 8. Security Requirements

- The prohibition is configured by the user and is not overridden by
  agent instructions or a prompt.
- The user's response and interception data are not written to Git,
  logs, or command-line arguments.
- The mechanism stores no secrets: it passes only the action
  description and the user's response.
- The default failure is safe: on an error or timeout the action is
  rejected, not performed.

## 9. Open Questions (Require Design)

1. The exact set of "dangerous" action categories and their default
   thresholds.
2. The channel for passing the request to the user (interface, field,
   notification).
3. Behavior on an empty response: reject or let it pass.
4. Whether interception events should be logged for audit.
5. Extending to semantic analysis of intent (beyond patterns).
6. Rewriting the call input (replacing a dangerous path with a safe
   one).
7. Interface localization (en/ru).

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