# Project Boundaries and Publication Rules

## 1. Project independence

This repository is a standalone project with its own purpose, architecture,
roadmap, source code, documentation, and quality criteria.

Other projects may use its functionality when it fits their needs. Reuse is
optional and is not, by itself, a reason to change this project's architecture
or requirements.

Do not modify one project to satisfy another project's internal needs.
Cross-project integration is allowed only through explicitly defined and
approved contracts. Each consumer independently decides whether to adopt it.

## 2. Local development

A local working copy may contain multiple branches, temporary files,
experiments, reports, helper scripts, local configuration, test data, and
other materials needed by the developer.

A file being present locally does not make it part of the product or mean it
belongs on GitHub. Local-only material may remain exclusively on the
developer's computer.

Do not create private GitHub repositories or private mirrors to hold local
development. Working variants and supporting materials stay local.

## 3. The single public branch

The public branch for this project is `develop`.

Development may take place in multiple local branches. Before publication,
selected changes are integrated into the public branch. Only this branch is
pushed to GitHub; local working branches are not published.

Do not change the public branch, push, or publish additional branches without
the user's explicit authorization. Do not create parallel public development
lines.

## 4. Distilled GitHub contents

The public repository contains only the distilled project: files required to
use, build, test, maintain, and understand this product itself.

Exclude before publication:

- personal data, identifiers, and contact details;
- customer information, processes, documents, and identifying examples;
- local paths, usernames, and developer-environment details;
- secrets, tokens, passwords, private keys, and local configuration;
- temporary files, scratch directories, intermediate outputs, and personal
  reports;
- backups, local databases, and exports that are not product artifacts;
- materials from other projects unless explicitly part of this project's
  public contract.

Anonymization must be genuine: replacing a name with a placeholder is not
enough if the context still identifies a customer or person. Use synthetic
examples. Do not weaken checks or remove protective tests to pass publication
review.

## 5. Publication gate

Before every push to `develop`:

1. Review the diff against the previous public-branch state.
2. Review all added, changed, and deleted files, including new and untracked
   files.
3. Confirm that every published file belongs to this project's purpose and is
   needed for its public use or maintenance.
4. Check for personal data, customer material, local paths, secrets, and
   unrelated files.
5. Run the applicable project tests and checks.
6. Publish only the verified result to `develop`.

Never synchronize the entire local working directory to GitHub. Publication
is a deliberate selection of reviewed changes, not a mirror of local files.

## 6. Enforcement

These rules are mandatory for all agents and contributors. If it is unclear
whether a file belongs to the public product, do not publish it. Record the
question and ask the user.
