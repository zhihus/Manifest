# Spec Delta

## Purpose

The architecture-docs capability keeps the Manifest architecture document
set (Brief, decisions register, audits, Todoing decisions, workflow READMEs)
mutually consistent and truthful about decision status.

## ADDED Requirements

### Requirement: Status separation

Architecture documents MUST separate: accepted decisions, preliminary
positions, deferred items, open questions, completed analytical work, and
not-implemented functionality. Accepting a decision MUST NOT be recorded
as implementing it.

#### Scenario: decision accepted but not implemented

- **WHEN** an accepted decision describes functionality absent from the
  implementation (e.g. Todoing history/versions/locks)
- **THEN** the documents mark the functionality as not implemented.

### Requirement: No unresolved contradictions

The document set MUST NOT contain contradicting normative statements.

#### Scenario: role model

- **WHEN** the role list is compared across Brief §9, the decisions
  register, role-model decisions, and workflow READMEs
- **THEN** all four name the same 7 mandatory roles including Tester
  and Analyst.

### Requirement: Sequential execution recorded

The document set MUST record sequential agent execution as a mandatory
Manifest rule, with parallel dispatch prohibited and one global task per
project at a time.

#### Scenario: parallelism prohibition

- **WHEN** any architecture document describes agent dispatch
- **THEN** it does not allow parallel agent execution.
