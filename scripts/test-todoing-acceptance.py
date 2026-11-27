#!/usr/bin/env python3
"""Real Todoing API + OpenSpec acceptance test in an isolated temporary project."""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TODOING = Path(os.environ["TODOING_BIN"]).resolve()
PROJECT_ID = str(uuid.uuid4())
ACTOR = "manifest-acceptance"


def run(command: list[str], cwd: Path, *, input_text: str | None = None) -> str:
    result = subprocess.run(
        command,
        cwd=cwd,
        input=input_text,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode:
        raise AssertionError(
            f"Command failed ({result.returncode}): {' '.join(command)}\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )
    return result.stdout.strip()


def api(root: Path, operation: str, args: dict, *, token: str | None = None,
        actor: str = ACTOR, expect_ok: bool = True) -> dict:
    request = {
        "api_version": 1,
        "project_id": PROJECT_ID,
        "actor_id": actor,
        "operation": operation,
        "args": args,
    }
    if token is not None:
        request["lock_token"] = token
    result = subprocess.run(
        [str(TODOING), "--json", "api"],
        cwd=root,
        input=json.dumps(request),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    try:
        response = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise AssertionError(
            f"{operation}: invalid JSON response; exit={result.returncode}; "
            f"stdout={result.stdout!r}; stderr={result.stderr!r}"
        ) from error
    if expect_ok and (result.returncode != 0 or response.get("ok") is not True):
        raise AssertionError(f"{operation} failed: {response}; stderr={result.stderr}")
    if not expect_ok and response.get("ok") is not False:
        raise AssertionError(f"{operation} unexpectedly succeeded: {response}")
    return response.get("data", response)


def write_change(root: Path, change_id: str, title: str) -> None:
    change = root / "openspec" / "changes" / change_id
    (change / "specs" / "acceptance-fixture").mkdir(parents=True)
    (change / "proposal.md").write_text(
        f"# {title}\n\n## Why\nAcceptance fixture.\n\n"
        "## What Changes\nExercise the documented archive path.\n",
        encoding="utf-8",
    )
    (change / "tasks.md").write_text(
        "# Tasks\n\n- [x] Verify the isolated acceptance scenario.\n",
        encoding="utf-8",
    )
    (change / "specs" / "acceptance-fixture" / "spec.md").write_text(
        "# Acceptance Fixture\n\n## ADDED Requirements\n\n"
        "### Requirement: Acceptance fixture\n"
        "The temporary project can archive an isolated change.\n\n"
        "#### Scenario: Archive fixture\n"
        "- WHEN the acceptance test archives the change\n"
        "- THEN the change is moved into the archive\n",
        encoding="utf-8",
    )


def acquire(root: Path, task_id: int) -> dict:
    return api(root, "task.lock.acquire", {"task_id": task_id})


def owner_call(root: Path, operation: str, args: dict, grant: dict,
               *, actor: str = ACTOR) -> dict:
    return api(root, operation, args, token=grant["lock_token"], actor=actor)


def release(root: Path, task_id: int, grant: dict) -> None:
    owner_call(
        root,
        "task.lock.release",
        {
            "task_id": task_id,
            "owner_id": grant["owner_id"],
            "fencing_generation": grant["fencing_generation"],
        },
        grant,
    )


def run_todoing_only_acceptance(parent: Path, config: str) -> None:
    """Exercise the full task lifecycle without creating or invoking OpenSpec."""
    root = parent / "todoing-only"
    (root / ".manifest").mkdir(parents=True)
    (root / ".manifest" / "project-id").write_text(PROJECT_ID, encoding="utf-8")
    (root / ".todoing").mkdir()
    (root / ".todoing" / "config.toml").write_text(config, encoding="utf-8")

    run(["git", "init", "-b", "main"], root)
    run(["git", "config", "user.name", "Manifest Todoing-only Acceptance"], root)
    run(["git", "config", "user.email", "todoing-only@example.invalid"], root)
    (root / "tracked.txt").write_text("todoing-only fixture\n", encoding="utf-8")
    run(["git", "add", "tracked.txt"], root)
    run(["git", "commit", "-m", "test: initialize Todoing-only fixture"], root)

    assert not (root / "openspec").exists()
    api(root, "store.init", {})
    api(root, "store.info", {})
    api(root, "store.verify", {"deep": True})

    created = api(root, "task.create", {
        "title": "Standalone Todoing task",
        "status_id": "backlog",
        "body": "Goal: verify the task lifecycle without an OpenSpec dependency.",
    })["task"]
    task_id = created["id"]
    initial = api(root, "task.get", {"task_id": task_id})["task"]
    assert initial.get("external_references", []) == []
    listed = api(root, "task.list", {"status_id": "backlog"})["tasks"]
    assert any(item["id"] == task_id for item in listed)

    prerequisite = api(root, "task.create", {
        "title": "Standalone prerequisite",
        "status_id": "backlog",
    })["task"]
    api(root, "task.dependency.add", {
        "task_id": task_id,
        "depends_on_task_id": prerequisite["id"],
    })
    dependencies = api(root, "task.dependency.list", {"task_id": task_id})
    assert prerequisite["id"] in dependencies["dependencies"]
    api(root, "task.dependency.remove", {
        "task_id": task_id,
        "depends_on_task_id": prerequisite["id"],
    })
    assert not api(root, "task.dependency.list", {"task_id": task_id})["dependencies"]

    # This API sequence represents an explicit user approval of the task.
    api(root, "task.status.set", {"task_id": task_id, "status_id": "ready"})
    ready = api(root, "task.get", {"task_id": task_id})
    api(root, "task.version.approve", {
        "task_id": task_id,
        "version_no": ready["version_no"],
    })

    grant = acquire(root, task_id)
    owner_call(root, "task.status.set", {
        "task_id": task_id,
        "status_id": "in_progress",
    }, grant)
    owner_call(root, "task.update", {
        "task_id": task_id,
        "patch": {"body": "Implementation completed without OpenSpec."},
    }, grant)
    owner_call(root, "task.status.set", {
        "task_id": task_id,
        "status_id": "review",
    }, grant)

    reviewed_version = api(
        root, "task.get", {"task_id": task_id}, token=grant["lock_token"]
    )["version_no"]
    owner_call(root, "task.review.add", {
        "task_id": task_id,
        "review_id": "todoing-only-approved-review",
        "version_no": reviewed_version,
        "reviewer": "todoing-only-reviewer",
        "outcome": "approved",
        "comments": [],
    }, grant, actor="todoing-only-reviewer")
    owner_call(root, "task.status.set", {
        "task_id": task_id,
        "status_id": "verified",
    }, grant)

    final_sha = run(["git", "rev-parse", "HEAD"], root)
    owner_call(root, "task.commit.finalize", {
        "task_id": task_id,
        "revision": final_sha,
    }, grant)
    owner_call(root, "task.status.set", {
        "task_id": task_id,
        "status_id": "completed",
    }, grant)
    release(root, task_id, grant)

    completed = api(root, "task.get", {"task_id": task_id})["task"]
    assert completed["outcome"] == "completed"
    assert completed["final_commit_sha"] == final_sha
    assert completed.get("external_references", []) == []
    assert len(api(root, "task.review.list", {"task_id": task_id})["reviews"]) == 1
    assert not (root / "openspec").exists()
    api(root, "store.verify", {"deep": True})


def main() -> None:
    if not TODOING.is_file():
        raise SystemExit(f"TODOING_BIN is not a file: {TODOING}")

    with tempfile.TemporaryDirectory(prefix="manifest-todoing-acceptance-") as raw:
        root = Path(raw)
        (root / ".manifest").mkdir()
        (root / ".manifest" / "project-id").write_text(PROJECT_ID, encoding="utf-8")
        (root / "openspec").mkdir(exist_ok=True)
        shutil.copy2(ROOT / "openspec" / "config.yaml", root / "openspec" / "config.yaml")

        config = """format_version = 1

[locking]
lease_seconds = 720
heartbeat_seconds = 60
recovery_grace_seconds = 60

[[statuses]]
id = "backlog"
label = "Backlog"
enabled = true

[[statuses]]
id = "ready"
label = "Ready"
enabled = true

[[statuses]]
id = "in_progress"
label = "In Progress"
enabled = true

[[statuses]]
id = "review"
label = "Review"
enabled = true

[[statuses]]
id = "verified"
label = "Verified"
enabled = true

[[statuses]]
id = "completed"
label = "Completed"
enabled = true
outcome = "completed"

[[transitions]]
from = "backlog"
to = "ready"

[[transitions]]
from = "ready"
to = "in_progress"

[[transitions]]
from = "in_progress"
to = "review"

[[transitions]]
from = "review"
to = "in_progress"

[[transitions]]
from = "review"
to = "verified"

[[transitions]]
from = "verified"
to = "completed"
"""
        (root / ".todoing").mkdir()
        (root / ".todoing" / "config.toml").write_text(config, encoding="utf-8")

        run(["git", "init", "-b", "main"], root)
        run(["git", "config", "user.name", "Manifest Acceptance"], root)
        run(["git", "config", "user.email", "acceptance@example.invalid"], root)
        (root / "tracked.txt").write_text("acceptance fixture\n", encoding="utf-8")
        run(["git", "add", "tracked.txt"], root)
        run(["git", "commit", "-m", "test: initialize acceptance fixture"], root)

        write_change(root, "acceptance-main", "Acceptance main lifecycle")
        write_change(root, "acceptance-cancel", "Acceptance cancellation")

        api(root, "store.init", {})
        api(root, "store.info", {})
        api(root, "store.verify", {"deep": True})

        created = api(root, "task.create", {
            "title": "Main lifecycle acceptance",
            "status_id": "backlog",
            "body": "Exercise Todoing and Manifest contract.",
        })
        task_id = created["task"]["id"]
        api(root, "task.external-ref.add", {
            "task_id": task_id,
            "namespace": "openspec.change",
            "value": "acceptance-main",
            "relation": "implements",
            "scope": "project",
        })
        api(root, "task.status.set", {"task_id": task_id, "status_id": "ready"})
        ready_version = api(root, "task.get", {"task_id": task_id})["version_no"]
        api(root, "task.version.approve", {
            "task_id": task_id,
            "version_no": ready_version,
        })

        grant = acquire(root, task_id)
        owner_call(root, "task.status.set", {
            "task_id": task_id,
            "status_id": "in_progress",
        }, grant)
        owner_call(root, "task.update", {
            "task_id": task_id,
            "patch": {"body": "first implementation"},
        }, grant)
        owner_call(root, "task.status.set", {
            "task_id": task_id,
            "status_id": "review",
        }, grant)

        before_review = api(root, "task.get", {"task_id": task_id},
                            token=grant["lock_token"])["version_no"]
        review_args = {
            "task_id": task_id,
            "review_id": "acceptance-review-changes-1",
            "version_no": before_review,
            "reviewer": "acceptance-reviewer",
            "outcome": "changes_requested",
            "comments": [{"path": "tracked.txt", "comment": "Revise the fixture."}],
        }
        owner_call(root, "task.review.add", review_args, grant,
                   actor="acceptance-reviewer")
        after_first_review = api(root, "task.get", {"task_id": task_id},
                                 token=grant["lock_token"])["task"]
        assert after_first_review["revision_count"] == 1
        owner_call(root, "task.review.add", review_args, grant,
                   actor="acceptance-reviewer")
        after_retry = api(root, "task.get", {"task_id": task_id},
                          token=grant["lock_token"])["task"]
        assert after_retry["revision_count"] == 1

        owner_call(root, "task.status.set", {
            "task_id": task_id,
            "status_id": "in_progress",
        }, grant)
        owner_call(root, "task.update", {
            "task_id": task_id,
            "patch": {"body": "revised implementation"},
        }, grant)
        owner_call(root, "task.status.set", {
            "task_id": task_id,
            "status_id": "review",
        }, grant)
        final_version = api(root, "task.get", {"task_id": task_id},
                            token=grant["lock_token"])["version_no"]
        owner_call(root, "task.review.add", {
            "task_id": task_id,
            "review_id": "acceptance-review-approved-2",
            "version_no": final_version,
            "reviewer": "acceptance-reviewer",
            "outcome": "approved",
            "comments": [],
        }, grant, actor="acceptance-reviewer")
        owner_call(root, "task.status.set", {
            "task_id": task_id,
            "status_id": "verified",
        }, grant)

        run(["openspec", "archive", "acceptance-main", "--yes"], root)
        (root / "tracked.txt").write_text("final accepted fixture\n", encoding="utf-8")
        run(["git", "add", "-A"], root)
        run(["git", "commit", "-m", "test: finalize accepted change"], root)
        final_sha = run(["git", "rev-parse", "HEAD"], root)
        owner_call(root, "task.commit.finalize", {
            "task_id": task_id,
            "revision": final_sha,
        }, grant)
        owner_call(root, "task.status.set", {
            "task_id": task_id,
            "status_id": "completed",
        }, grant)
        release(root, task_id, grant)

        completed = api(root, "task.get", {"task_id": task_id})["task"]
        assert completed["outcome"] == "completed"
        assert completed["final_commit_sha"] == final_sha
        assert completed["revision_count"] == 1
        assert completed["external_references"][0]["value"] == "acceptance-main"
        assert len(api(root, "task.review.list", {"task_id": task_id})["reviews"]) == 2
        assert api(root, "task.version.list", {"task_id": task_id})["versions"]
        assert api(root, "task.history.list", {"task_id": task_id})["events"]

        cancel_task = api(root, "task.create", {
            "title": "Cancellation acceptance",
            "status_id": "backlog",
        })["task"]
        cancel_id = cancel_task["id"]
        api(root, "task.external-ref.add", {
            "task_id": cancel_id,
            "namespace": "openspec.change",
            "value": "acceptance-cancel",
            "relation": "implements",
            "scope": "project",
        })
        cancel_grant = acquire(root, cancel_id)
        owner_call(root, "task.cancel", {
            "task_id": cancel_id,
            "reason": "User-approved acceptance cancellation",
        }, cancel_grant)
        run(["openspec", "archive", "acceptance-cancel", "--yes", "--skip-specs"], root)
        release(root, cancel_id, cancel_grant)
        cancelled = api(root, "task.get", {"task_id": cancel_id})["task"]
        assert cancelled["outcome"] == "cancelled"
        assert cancelled["external_references"][0]["value"] == "acceptance-cancel"

        snapshot = api(root, "store.snapshot", {"output_path": "acceptance.db"})
        snapshot_path = snapshot["snapshot_path"]
        snapshot_sha = snapshot["sha256"]
        verified = api(root, "store.snapshot.verify", {
            "snapshot_path": snapshot_path,
            "expected_sha256": snapshot_sha,
        })
        assert verified["integrity"]["integrity_check"] == "ok"

        extra = api(root, "task.create", {
            "title": "Must disappear after restore",
            "status_id": "backlog",
        })["task"]
        restored = api(root, "store.snapshot.restore", {
            "snapshot_path": snapshot_path,
            "expected_sha256": snapshot_sha,
        })
        assert restored["restored"]["integrity_check"] == "ok"
        missing = api(root, "task.get", {"task_id": extra["id"]}, expect_ok=False)
        assert missing["error"]["code"] == "task_not_found"
        restored_main = api(root, "task.get", {"task_id": task_id})["task"]
        restored_cancel = api(root, "task.get", {"task_id": cancel_id})["task"]
        assert restored_main["final_commit_sha"] == final_sha
        assert restored_main["revision_count"] == 1
        assert restored_main["external_references"][0]["value"] == "acceptance-main"
        assert len(api(root, "task.review.list", {"task_id": task_id})["reviews"]) == 2
        assert restored_cancel["outcome"] == "cancelled"
        assert restored_cancel["external_references"][0]["value"] == "acceptance-cancel"
        api(root, "store.verify", {"deep": True})
        run_todoing_only_acceptance(root, config)

    print("PASS real Todoing API ↔ Manifest/OpenSpec acceptance lifecycle")
    print("PASS standalone Todoing task lifecycle without OpenSpec")
    print("PASS review idempotency, final SHA, cancellation archive, snapshot verify/restore")


if __name__ == "__main__":
    main()
