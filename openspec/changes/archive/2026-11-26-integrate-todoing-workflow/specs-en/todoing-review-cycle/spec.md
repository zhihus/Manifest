# Spec Delta

## Purpose

Defines the Review cycle: handing the task off for review, recording a Review
with an outcome, handling approval and remarks (revision_count), and the
idempotency of the Review record.

## ADDED Requirements

### Requirement: Handoff to review

Before handing off the result, the Orchestrator SHALL move the task to
`review` and pass the artifacts to the Reviewer through its own workflow.

#### Scenario: Handoff
- WHEN the Orchestrator is ready to hand off the result
- THEN it moves the task to `review` and passes the artifacts to the Reviewer

### Requirement: Review record

The system SHALL call `task.review.add` with `review_id`, `version_no` of the
reviewed version, `reviewer` label, `outcome` (`approved`/
`changes_requested`), and an ordered `comments` array. The `actor_id` envelope
records the Reviewer agent.

#### Scenario: Recording approval
- WHEN the Reviewer approves the version
- THEN the system calls `task.review.add` with outcome `approved` and an
  ordered `comments` array

#### Scenario: Recording remarks
- WHEN the Reviewer returns remarks
- THEN the system calls `task.review.add` with outcome `changes_requested`

### Requirement: Handling approval

On outcome `approved`, Todoing SHALL store the Review record, and Manifest
SHALL move the task to `verified`.

#### Scenario: Approval
- WHEN a Review record with outcome `approved` is stored
- THEN Manifest moves the task to `verified`

### Requirement: Handling remarks

On outcome `changes_requested`, Todoing SHALL atomically store the record and
increase `revision_count` by exactly one; Manifest SHALL return the task to
`in_progress`.

#### Scenario: Remarks
- WHEN a Review record with outcome `changes_requested` is stored
- THEN `revision_count` increases by exactly one and the task is returned to
  `in_progress`

### Requirement: Review record idempotency

A repeated `review_id` with an identical payload SHALL be a no-op; the same
ID with a different payload SHALL return `review_id_conflict`. A Review does
not change the workflow status.

#### Scenario: Repeated review_id
- WHEN `task.review.add` is called again with the same `review_id` and an
  identical payload
- THEN the operation is a no-op

#### Scenario: review_id conflict
- WHEN `task.review.add` is called with the same `review_id` but a different
  payload
- THEN `review_id_conflict` is returned