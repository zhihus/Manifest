# Spec Delta: preflight

## ADDED Requirements

### Requirement: Perl rendering capability is verified before installation
The preflight MUST verify that Perl is available and can execute a trivial program before the installer writes project files, because Perl is required by the template renderer.

#### Scenario: Perl is unavailable

- **WHEN** Perl is missing or cannot execute a trivial program
- **THEN** preflight fails with an actionable reason
- **AND** no project files are written

### Requirement: SHA-256 capability is verified portably
The preflight MUST verify that a working SHA-256 tool is available, without assuming a specific binary name: `sha256sum` or an equivalent such as `shasum -a 256` is accepted, and the detected tool is used consistently for the checksum guard.

The stored checksum records which tool produced it; re-verification
uses the same tool or an equivalent, byte-identical algorithm
(SHA-256).

#### Scenario: macOS without sha256sum

- **WHEN** the project runs on a platform where `sha256sum` is absent
  but `shasum -a 256` is available
- **THEN** preflight accepts the environment
- **AND** the checksum guard works with the detected tool

#### Scenario: No SHA-256 tool at all

- **WHEN** no working SHA-256 tool is found
- **THEN** preflight fails with the reason and required action
- **AND** nothing is written to the project
