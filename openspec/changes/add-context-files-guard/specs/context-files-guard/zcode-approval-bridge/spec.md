## Purpose

Connects the native ZCode permission UI to the Guard via an MCP approval broker and PreToolUse hooks, so that protected-file edits require a visible, independent user approval.

## ADDED Requirements

### Requirement: MCP approval tool
The ZCode plugin SHALL provide an MCP tool `request_change_approval` that the model calls with repository, branch, paths, the exact diff and a reason. The broker SHALL display the actual diff/summary to the user and SHALL return a receipt only after a confirmed one-time user decision (Allow or Reject).

#### Scenario: User approves exact diff
- **WHEN** the model submits an exact diff and the user selects one-time Allow in the native UI
- **THEN** the broker returns a receipt that the Guard can validate into an `AUTHORIZED` state

#### Scenario: User rejects
- **WHEN** the user selects Reject, or the request times out
- **THEN** no receipt is issued and the Guard records no authorization

### Requirement: PreToolUse enforcement
The ZCode plugin SHALL use PreToolUse hooks to force the approval tool to the `ask` permission level, and to permit protected-file operations only when they match an existing authorization. Unsupported or ambiguous writes to protected files SHALL be denied without consuming authorization.

#### Scenario: Protected file edit without authorization
- **WHEN** the model attempts an edit to a protected file with no matching authorization
- **THEN** the operation is denied and no authorization state is affected

#### Scenario: Authorized operation permitted
- **WHEN** the model attempts an edit that exactly matches an active authorization
- **THEN** the operation is permitted without consuming the authorization (consumption happens at commit)

### Requirement: Native UI is the only consent channel
The system MUST NOT accept ordinary chat questions, model-written approval text or "Always Allow" as consent for protected-file changes.

#### Scenario: Always Allow attempted
- **WHEN** a persistent "Always Allow" style permission is used instead of a one-time decision
- **THEN** the Guard does not treat it as a valid approval for a protected change

### Requirement: Proof-of-concept gate before relying on the bridge
Before relying on the bridge, the plugin MUST be verified end-to-end to confirm MCP argument visibility in the native UI and `ask` behavior across permission modes. If verification fails, the system SHALL use a dedicated approval UI instead; chat text is never consent.

#### Scenario: Verification failure
- **WHEN** end-to-end verification shows the exact change is not reliably displayed or `ask` is bypassed in some permission mode
- **THEN** the fallback dedicated approval UI is used and the native-UI path is not trusted
