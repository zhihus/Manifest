# Eval-report — sess_3d91ceae-7374-44d7-b875-cd278f6f5b22

## 1. Шапка

- **Дата:** 2026-11-06
- **sessionId:** `sess_3d91ceae-7374-44d7-b875-cd278f6f5b22`
- **Title:** `/coder` (третья `/coder`-сессия за день по времени начала)
- **Модель/провайдер:** `new-provider-65k/Qwen3.8-27B-exl3`
- **Файл задачи:** `unavailable` (в проекте нет `docs/eval/task-NNN.md`; сессия запущена slash-командой `/coder`)
- **Версия харнеса/сервера:** `unavailable` (версионные метки ZCode/TabbyAPI в телеметрии не фиксируются; модель — exl3-квант Qwen3.8-27B)
- **Окно прогона (UTC):** модельная активность 07:00:15 → 07:46:29 (~46 мин); сессия создана 07:00:12, последний апдейт 07:46:29
- **Скрипт:** `extract_metrics.py` v1.2.0
- **mtime скрипта:** 2026-11-05 16:14 UTC
- **Ревизия:** v1 (первый разбор сессии)

## 2. Сводка per-agent

| Агент | profileId | статус | wall-clock | input | output | reasoning | cache | total (in+out) | tool-вызовов | итерации |
|---|---|---|---|---|---|---|---|---|---|---|
| **main** | — | — | 07:00:15→07:46:29 (46 мин) | 318 814 | 7 890 | 0 | 151 808 | 326 704 | 6 (rollout) | 8 |
| coder | `agent_4023b015` | completed | 1 413 693 ms (23,6 мин) | 2 123 234 | 60 693 | 0 | 1 945 344 | 2 183 927 | 82 | 73 |
| code-reviewer | `agent_9352db06` | completed | 1 003 414 ms (16,7 мин) | 759 305 | 23 449 | 0 | 665 600 | 782 754 | 42 | 29 |
| **ИТОГ** | — | — | ~46 мин | 3 201 353 | 92 032 | 0 | 2 762 752 | 3 293 385 | 130 | 110 |

**Иерархия (parent→child), последовательно (не параллельно):**
- main → **coder** `agent_4023b015` (`parentToolUseId` `call_68bf8eb3…`), 07:01:45 → 07:25:19
- main → **code-reviewer** `agent_9352db06` (`parentToolUseId` `call_9f0122ce…`), 07:26:23 → 07:43:06

*Источники: main — rollout `response.usage`/`response.toolCalls`; субагенты — агрегаты `metadata.json` (`totalDurationMs`, `usage`, `totalToolUseCount`); итерации = число per-request записей (main) / `subagent_rollout_records` (субагенты). Иерархия восстановлена по `parentSessionId`+`parentToolUseId`+`childSessionId`.*

## 3. Per-request таблица

8 запросов main-сессии (7 `main_turn` + 1 `compact`), все `attempt=1`:

| # | время (UTC) | dur (с) | source | attempt | input | output | total | cache | finish | toolCalls |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 07:00:15.893 | 48,6 | main_turn | 1 | 37 170 | 292 | 37 462 | 0 | tool-calls | 1 |
| 2 | 07:01:05.778 | 3,7 | main_turn | 1 | 37 509 | 133 | 37 642 | 37 120 | tool-calls | 1 |
| 3 | 07:01:09.762 | 4,9 | main_turn | 1 | 38 546 | 141 | 38 687 | 37 376 | tool-calls | 1 |
| 4 | 07:01:14.935 | 10,3 | main_turn | 1 | 38 973 | 446 | 39 419 | 38 400 | tool-calls | 1 |
| 5 | 07:01:25.480 | 20,0 | main_turn | 1 | 40 093 | 830 | 40 923 | 38 912 | tool-calls | 1 |
| 6 | 07:25:19.273 | 63,7 | main_turn | 1 | 42 294 | 677 | 42 971 | 0 | tool-calls | 1 |
| 7 | 07:43:06.486 | 141,0 | compact | 1 | 42 738 | 4 728 | 47 466 | 0 | stop | 0 |
| 8 | 07:45:27.771 | 61,8 | main_turn | 1 | 41 491 | 643 | 42 134 | 0 | stop | 0 |

*Кросс-проверка: число tool-вызовов main = 6 (rollout `response.toolCalls`, канонический источник). Событий `tool.call.*` в `cli\log` за окно — 129 (лог-счёт, включает субагентные вызовы и пересобранные при рестартах — НЕ канонический источник, приведён только как кросс-проверка).*

## 4. Серверные метрики (TabbyAPI)

Все 8 запросов main-сессии сматчились с сервером, **confidence: high × 8, medium 0, low 0, unmatched 0** (из `tabby_matches` канонического `extract_metrics.py`). Матчинг по (время +04:00, точное число prompt/gen токенов). `#N` — канонические из скрипта.

| #N | req | source | prompt | %cached | new T/s | gen T/s | TTFT (с) | conf |
|---|---|---|---|---|---|---|---|---|
| #132 | 1 | main_turn | 37 170 | 0% | 826 | 55,5 | 45,0 | high |
| #133 | 2 | main_turn | 37 509 | 99% | 344 | 62,2 | 1,15 | high |
| #134 | 3 | main_turn | 38 546 | 97% | 594 | 59,8 | 1,99 | high |
| #135 | 4 | main_turn | 38 973 | 99% | 531 | 54,1 | 1,10 | high |
| #136 | 5 | main_turn | 40 093 | 97% | 239 | 51,1 | 4,97 | high |
| #210 | 6 | main_turn | 42 294 | 0% | 826 | 52,7 | 51,2 | high |
| #240 | 7 | compact | 42 738 | 0% | 766 | 55,8 | 55,8 | high |
| #241 | 8 | main_turn | 41 491 | 0% | 824 | 53,4 | 50,3 | high |

**Доля low-confidence: 0%** (8/8 high). Пропуски в `#N` (#137–#209, #211–#239) — это запросы субагентов (coder/reviewer) и другие сессии в том же окне лога; они не входят в main-таблицу. Рестартов сервера внутри окна не было (сегмент 1).

## 5. GPU/CPU

**`unavailable`** — внешний read-only поллер (фаза B, `nvidia-smi`/CIM, ~5 с) до прогона не запускался, исторический ряд GPU/CPU не существует. По протоколу блок помечается `unavailable`, значения не выдумываются и не оцениваются.

## 6. Параметры модели

**Статус подтверждения: подтверждено per-request** — в окне прогона в каждой metric-строке сервера записаны фактические sampler-значения с аннотацией `(preset)`; `server_sampler.confirmed_per_request=true`.

**Слой 1 — запрос (клиент, rollout `request.body`):**
- `model`: Qwen3.8-27B-exl3
- `max_tokens`: 8192 (все 8 запросов)
- `tool_choice`: auto
- `template_vars.reasoning_effort`: low
- sampling-параметры (temperature/top_p/top_k/min_p) клиент НЕ отправляет

**Слой 2 — серверные фолбэки (эффективные значения, `config.yml`):**
- `sampling.override_preset: safe_defaults` (llama.cpp-style): temperature 0.8, top_k 40, top_p 0.95, min_p 0.05
- инлайн-override'ы поверх пресета: **temperature 0.7** (фактически применяемый fallback), max_tokens 8192; все `force: false` (запрос мог бы перебить, но не перебивает)

**Слой 3 — инференс-конфиг (`config.yml`):**
- `max_seq_len` 130000, `cache_size` 130048, `cache_mode` 5,4 (квант KV), `max_batch_size` 1, `warmup`, `vision` true, `reasoning_budget_tokens` 2048
- `template_vars_default max_tool_response_chars` 4000, `template_vars_force preserve_reasoning` false
- `draft_model`: mtp, dynamic_draft; квант exl3 `/mnt/e/models/exl3/Qwen3.8-27B-exl3`
- `generation_config.json` модели (temp 1.0, top_k 20, top_p 0.95, do_sample) — перекрыт серверными override'ами

**Фактические sampler-значения (per-request из `(preset)`-строк):** temperature 0.7, min_p 0.05, top_k 40, top_p 0.95.

## 7. Ограничения прогона

- **GPU/CPU `unavailable`** — поллер (фаза B) не запускался до прогона; ряд не существует (блок 5).
- **Файл задачи `unavailable`** — в проекте нет `docs/eval/task-NNN.md`; сессия запущена slash-командой `/coder` (шапка).
- **Версия харнеса/сервера `unavailable`** — версионные метки ZCode/TabbyAPI в телеметрии не фиксируются (шапка).
- **Окно прогона** определено по модельной активности (07:00:15→07:46:29 UTC); `updated_at` сессии (07:46:29) совпадает с окончанием последней модельной записи — это последний апдейт индекса.
- Прочего не было: retention включён (полные per-request записи main + обоих субагентов), рестартов сервера в окне нет, ретраев/ошибок нет.

## 8. Ретраи/ошибки

**Чистый прогон: ретраев и ошибок нет.**
- `retried_requests`: пусто (все 8 запросов `attempt=1`)
- `error_events`: пусто (нет `model.request.failed`, нет `model.retry.delay.resolved`)
- `finishReason`: 6 × `tool-calls`, 2 × `stop` — все штатные, подозрительных значений нет
- Оба субагента завершились со статусом `completed` (`agents_failed=0`)