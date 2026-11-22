# Tasks: add-commit-msg-hook

## 1. Hook and regression tests

- [x] FR 1.1 commit-msg-validator

Implement scripts/hooks/commit-msg according to design D1-D4. Add
scripts/test-commit-msg.sh with cases for valid ordinary messages,
unknown type, malformed format, uppercase/non-English/empty subject,
trailing period, valid breaking change, missing footer, and footer
without !. Assert rejected message files remain byte-identical.
Stop criterion: the regression script passes every case; the hook
returns 0/1/2 for valid/invalid invocation/invalid message as
specified; bash -n passes for the hook and test script.
Maps to scenarios: Valid ordinary commit; Invalid message format;
Invalid subject; Breaking marker without footer; Footer without
breaking marker; Valid breaking change; Rejected message remains unchanged.
