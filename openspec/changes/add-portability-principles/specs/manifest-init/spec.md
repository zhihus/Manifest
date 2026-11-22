# Spec Delta: manifest-init

## ADDED Requirements

### Requirement: Install-time dependencies are declared
The install MUST use only external binaries declared in the external dependency register, and each such binary MUST have a register entry stating its purpose, scope, and detection method.

Perl used for template rendering stays declared and documented (its
replacement is out of scope unless a design shows a clear advantage);
every other tool invoked during install is registered the same way.

#### Scenario: Perl is unavailable

- **WHEN** Perl is missing or cannot execute a trivial program
- **THEN** preflight fails with an actionable installation message
- **AND** no project files are written

#### Scenario: Registered render dependency

- **WHEN** the install renders templates with Perl
- **THEN** the external dependency register documents Perl with
  purpose and scope
- **AND** the install runs without invoking any undeclared binary
