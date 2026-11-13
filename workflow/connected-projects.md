# Connected Projects Registry

# Metadata
> **Status: draft**  
> **Type: document**  
> **Version: 1.0.0**  
> **Updated: 2026-11-12**  

# Description
Registry of projects connected to the Manifest framework. The
manifest-init skill appends one entry per project on successful
connection (the agent running the skill writes the entry, not the
script). Entries are never deleted.

## 1. Entry format

Each entry contains:

* `name` — project name, kebab-case (as validated at init).
* `path` — path to the project folder.
* `connected` — connection date, ISO (`YYYY-MM-DD`).
* `version` — Manifest framework version at connection time.
* `status` — `active` or `archived`.

A removed or retired project is marked `status: archived`; a moved
project gets its `path` updated.

## 2. Entries

*(none yet)*

- name: vstrecha-raytec
  path: C:/WorkProjects/vstrecha-raytec
  connected: 2026-11-12
  version: 1.0.0
  status: active

- name: test-unica-project
  path: C:/WorkProjects/test-unica-project
  connected: 2026-11-13
  version: 1.0.0
  status: active
