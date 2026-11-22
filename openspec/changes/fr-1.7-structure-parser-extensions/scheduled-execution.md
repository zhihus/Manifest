# Scheduled Structure Parser Runs

The parser is a one-shot command. Configure the operating-system
scheduler to invoke it; do not keep a shell process running.

## Command

Run from the Manifest repository root:

```bash
bash scripts/structure-parser.sh --dir workflow
```

The process returns:
- `0` — every discovered Markdown file passed;
- `1` — at least one file has a structure violation;
- `2` — invalid arguments, inaccessible/missing directory, or no
  Markdown files found.

## Linux / cron

Create a crontab entry, replacing the repository path and schedule:

```cron
*/30 * * * * cd /path/to/Manifest && mkdir -p logs && bash scripts/structure-parser.sh --dir workflow >> logs/structure-parser.log 2>&1; status=$?; printf 'exit=%s\\n' "$status" >> /path/to/Manifest/logs/structure-parser.log; exit "$status"
```

Cron records command output in the configured log. A non-zero process
exit status indicates a failed run; use the host's cron logging or
monitoring to alert on it.

## Windows / Task Scheduler

Create a Basic Task and configure its trigger as required.

**Program/script:**

```text
C:\Program Files\Git\bin\bash.exe
```

**Add arguments:**

```text
-lc "mkdir -p logs; bash scripts/structure-parser.sh --dir workflow >> logs/structure-parser.log 2>&1; status=$?; echo exit=$status >> logs/structure-parser.log; exit $status"
```

**Start in:**

```text
C:\WorkProjects\Manifest
```

Replace the example paths with the actual Git installation and
repository paths. In Task Scheduler, enable the task history and
inspect **Last Run Result**; exit code `0` is success, non-zero is
failure. The log contains parser diagnostics.

## Operational notes

- Choose a directory whose Markdown files are governed by the
  Manifest structure rules. The parser validates every `.md` file
  below the selected directory.
- The parser does not create a schedule, install a service, or change
  Git configuration.
- Avoid overlapping scheduled runs; each invocation is independent.
