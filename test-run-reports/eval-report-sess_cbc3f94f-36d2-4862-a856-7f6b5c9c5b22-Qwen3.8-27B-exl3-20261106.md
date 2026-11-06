# Eval-report — sess_cbc3f94f-36d2-4862-a856-7f6b5c9c5b22

## 1. Шапка

- **Дата:** 2026-11-06
- **sessionId:** `sess_cbc3f94f-36d2-4862-a856-7f6b5c9c5b22`
- **Title:** `/coder` (вторая `/coder`-сессия за день по времени начала)
- **Модель/провайдер:** `new-provider-65k/Qwen3.8-27B-exl3`
- **Файл задачи:** `unavailable` (в проекте нет `docs/eval/task-NNN.md`; сессия запущена slash-командой `/coder`)
- **Версия харнеса/сервера:** `unavailable` (версионные метки ZCode/TabbyAPI в телеметрии не фиксируются; модель — exl3-квант Qwen3.8-27B)
- **Окно прогона (UTC):** модельная активность 05:45:38 → 06:54:39 (~69 мин); сессия создана 05:45:29, последний апдейт 08:14:39
- **Скрипт:** `extract_metrics.py` v1.2.0
- **mtime скрипта:** 2026-11-05 16:14 UTC
- **Ревизия:** v1 (первый разбор сессии)

## 2. Сводка per-agent

| Агент | profileId | статус | wall-clock | input | output | reasoning | cache | total (in+out) | tool-вызовов | итерации |
|---|---|---|---|---|---|---|---|---|---|---|
| **main** | — | — | 05:45:38→06:54:39 (69 мин) | 508 885 | 21 799 | 0 | 224 768 | 530 684 | 10 (rollout) | 12 |
| coder | `agent_9e9e5381` | completed | 2 298 044 ms (38,3 мин) | 2 347 571 | 77 416 | 0 | 2 170 112 | 2 424 987 | 93 | 78 |
| code-reviewer | `agent_8b192d23` | completed | 1 084 226 ms (18,1 мин) | 775 577 | 26 371 | 0 | 678 144 | 801 948 | 39 | 31 |
| **ИТОГ** | — | — | ~69 мин | 3 632 033 | 125 586 | 0 | 2 873 024 | 3 757 619 | 142 | 121 |

**Иерархия (parent→child), последовательно (не параллельно):**
- main → **coder** `agent_9e9e5381` (`parentToolUseId` `call_0a8e9b5c…`), 05:47:38 → 06:25:56
- main → **code-reviewer** `agent_8b192d23` (`parentToolUseId` `call_1e8b2969…`), 06:29:42 → 06:47:46

*Источники: main — rollout `response.usage`/`response.toolCalls`; субагенты — агрегаты `metadata.json` (`totalDurationMs`, `usage`, `totalToolUseCount`); итерации = число per-request записей (main) / `subagent_rollout_records` (субагенты). Иерархия восстановлена по `parentSessionId`+`parentToolUseId`+`childSessionId`.*

## 3. Per-request таблица

12 запросов main-сессии (9 `main_turn` + 3 `compact`), все `attempt=1`:

| # | время (UTC) | dur (с) | source | attempt | input | output | total | cache | finish | toolCalls |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 05:45:38.760 | 47,3 | main_turn | 1 | 37 057 | 271 | 37 328 | 0 | tool-calls | 1 |
| 2 | 05:46:27.334 | 4,1 | main_turn | 1 | 37 363 | 164 | 37 527 | 36 864 | tool-calls | 1 |
| 3 | 05:46:31.933 | 5,3 | main_turn | 1 | 37 561 | 234 | 37 795 | 37 120 | tool-calls | 2 |
| 4 | 05:46:37.316 | 27,5 | main_turn | 1 | 39 517 | 1 237 | 40 754 | 37 376 | tool-calls | 2 |
| 5 | 05:47:05.185 | 14,8 | main_turn | 1 | 41 450 | 561 | 42 011 | 39 424 | tool-calls | 1 |
| 6 | 05:47:20.229 | 17,9 | main_turn | 1 | 42 047 | 811 | 42 858 | 41 216 | tool-calls | 1 |
| 7 | 06:25:56.280 | 147,0 | compact | 1 | 41 440 | 5 313 | 46 753 | 0 | stop | 0 |
| 8 | 06:28:23.553 | 78,9 | main_turn | 1 | 45 621 | 1 265 | 46 886 | 0 | tool-calls | 1 |
| 9 | 06:47:46.784 | 164,6 | compact | 1 | 46 883 | 5 745 | 52 628 | 0 | stop | 0 |
| 10 | 06:50:31.639 | 59,9 | main_turn | 1 | 46 897 | 165 | 47 062 | 0 | tool-calls | 1 |
| 11 | 06:51:31.852 | 119,1 | compact | 1 | 47 934 | 5 325 | 53 259 | 32 768 | stop | 0 |
| 12 | 06:53:31.177 | 68,0 | main_turn | 1 | 45 115 | 708 | 45 823 | 0 | stop | 0 |

*Кросс-проверка: число tool-вызовов main = 10 (rollout `response.toolCalls`, канонический источник). Событий `tool.call.*` в `cli\log` за окно — 139 (лог-счёт, включает субагентные вызовы и пересобранные при рестартах — НЕ канонический источник, приведён только как кросс-проверка).*

## 4. Серверные метрики (TabbyAPI)

Все 12 запросов main-сессии сматчились с сервером, **confidence: high × 12, medium 0, low 0, unmatched 0** (из `tabby_matches` канонического `extract_metrics.py`). Матчинг по (время +04:00, точное число prompt/gen токенов). `#N` — канонические из скрипта.

| #N | req | source | prompt | %cached | new T/s | gen T/s | TTFT (с) | conf |
|---|---|---|---|---|---|---|---|---|
| #11 | 1 | main_turn | 37 057 | 0% | 884 | 62,4 | 41,9 | high |
| #12 | 2 | main_turn | 37 363 | 99% | 393 | 66,5 | 1,29 | high |
| #13 | 3 | main_turn | 37 561 | 99% | 380 | 64,9 | 1,18 | high |
| #14 | 4 | main_turn | 39 517 | 95% | 702 | 49,5 | 3,08 | high |
| #15 | 5 | main_turn | 41 450 | 95% | 660 | 42,3 | 3,09 | high |
| #16 | 6 | main_turn | 42 047 | 98% | 589 | 54,4 | 1,43 | high |
| #95 | 7 | compact | 41 440 | 0% | 782 | 55,2 | 53,0 | high |
| #96 | 8 | main_turn | 45 621 | 0% | 861 | 50,5 | 53,0 | high |
| #128 | 9 | compact | 46 883 | 0% | 769 | 55,2 | 61,0 | high |
| #129 | 10 | main_turn | 46 897 | 0% | 859 | 27,2 | 54,6 | high |
| #130 | 11 | compact | 47 934 | 68% | 603 | 57,6 | 25,2 | high |
| #131 | 12 | main_turn | 45 115 | 0% | 866 | 44,1 | 52,1 | high |

**Доля low-confidence: 0%** (12/12 high). Пропуски в `#N` (#17–#94, #97–#127) — это запросы субагентов (coder/reviewer) и другие сессии в том же окне лога; они не входят в main-таблицу. Рестартов сервера внутри окна не было (сегмент 1).

## 5. GPU/CPU

**`unavailable`** — внешний read-only поллер (фаза B, `nvidia-smi`/CIM, ~5 с) до прогона не запускался, исторический ряд GPU/CPU не существует. По протоколу блок помечается `unavailable`, значения не выдумываются и не оцениваются.

## 6. Параметры модели

**Статус подтверждения: подтверждено per-request** — в окне прогона в каждой metric-строке сервера записаны фактические sampler-значения с аннотацией `(preset)`; `server_sampler.confirmed_per_request=true`.

**Слой 1 — запрос (клиент, rollout `request.body`):**
- `model`: Qwen3.8-27B-exl3
- `max_tokens`: 8192 (все 12 запросов)
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
- **Окно прогона** определено по модельной активности (05:45:38→06:54:39 UTC); `updated_at` сессии (08:14:39) позже — это последний апдейт индекса, не модельная активность.
- Прочего не было: retention включён (полные per-request записи), рестартов сервера в окне нет, ретраев/ошибок нет.

## 8. Ретраи/ошибки

**Чистый прогон: ретраев и ошибок нет.**
- `retried_requests`: пусто (все 12 запросов `attempt=1`)
- `error_events`: пусто (нет `model.request.failed`, нет `model.retry.delay.resolved`)
- `finishReason`: 8 × `tool-calls`, 4 × `stop` — все штатные, подозрительных значений нет
- Оба субагента завершились со статусом `completed` (`agents_failed=0`)