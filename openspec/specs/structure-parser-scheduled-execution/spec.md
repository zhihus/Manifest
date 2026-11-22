# Structure Parser Scheduled Execution

## Purpose

Define scheduled invocation without coupling the parser to a specific
operating-system scheduler.

## Requirements

### Requirement: One-shot scheduled invocation

The parser MUST remain a one-shot command that can be invoked by an
external scheduler. It MUST NOT install or configure scheduler
services, daemonize, or wait between runs.

#### Scenario: External scheduler

- **WHEN** cron or Windows Task Scheduler invokes the documented
  directory command
- **THEN** the parser performs one validation run and exits with the
  documented aggregate status.

### Requirement: Scheduler documentation

The project MUST document the command, working-directory requirement,
and a way to retain output and observe the exit status for supported
scheduler examples.

#### Scenario: Scheduled validation failure

- **WHEN** a scheduled run finds a structure violation
- **THEN** the process exits 1 so the scheduler or wrapper can record
  the failed run.
