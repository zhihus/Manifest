# Eval-report: sess_eb6697c6 (Qwen3.8-27B-exl3, 2026-11-06)

## 1. Шапка

- **Дата:** 2026-11-06
- **sessionId:** `sess_eb6697c6-acd8-4a7d-9920-66852a6dc1a4`
- **title:** `/coder`
- **Модель/провайдер:** `new-provider-65k/Qwen3.8-27B-exl3`
- **Файл задачи:** не применимо — сессия `/coder`, задача не из `docs/eval/task-NNN.md` (замерный прогон не по фиксированному промпт-файлу)
- **Версия харнеса/сервера:** `unavailable` — не зафиксирована в источниках (rollout/лог не несут версий)
- **Окно прогона:** 2026-11-06 05:42:18.161 → 05:45:04.397 UTC (wall-clock **166.2 s**, status `interrupted`)
- **Скрипт-извлекатель:** `extract_metrics.py` **v1.2.0**, mtime **2026-11-05 16:14 UTC**
- **Источники:** rollout `model-io-sess_eb6697c6-….jsonl`; лог `zcode-2026-11-06.jsonl`; TabbyAPI `2026-11-06_09-36-48_383164.log`; `tasks-index.sqlite` (read-only). Архив: `Temp/eval-archive-20261106/`.

## 2. Сводка per-agent

Субагентов **не было**: каталог `cli/agents/sess_eb6697c6-…/` отсутствует → per-agent агрегаты **`unavailable`** (нет `metadata.json`). Вся работа выполнена в main-сессии, субагентных rollouts нет.

**Итог по прогону (main-сессия):**

| Метрика | Значение |
|---|---|
| Запросов (main) | 6 (5 завершённых + 1 cancelled) |
| input tokens | 187 985 |
| output tokens | 810 |
| cacheRead tokens | 148 992 |
| reasoning tokens | 0 |
| total (input+output) | 188 795 |
| tool-вызовы (rollout `response.toolCalls`) | 5 |
| tool-вызовы (кросс-проверка, log `tool.call.completed`) | 4 |
| wall-clock | 166.2 s |
| Субагентов | 0 |

**Иерархия:** только main-сессия, parent→child отсутствуют.

## 3. Per-request таблица

Источник: rollout `model-io-sess_eb6697c6-….jsonl` (per-request). Время UTC.

| # | startedAt | dur (ms) | querySource | attempt | input | output | cache | finishReason | toolCalls |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 05:42:18.636 | 44 761 | main_turn | 1 | 37 052 | 124 | 0 | tool-calls | 1 |
| 2 | 05:43:04.445 | 4 078 | main_turn | 1 | 37 204 | 173 | 36 864 | tool-calls | 1 |
| 3 | 05:43:09.092 | 4 168 | main_turn | 1 | 37 446 | 164 | 37 120 | tool-calls | 1 |
| 4 | 05:43:13.548 | 3 269 | main_turn | 1 | 37 761 | 113 | 37 376 | tool-calls | 1 |
| 5 | 05:43:17.104 | 6 264 | main_turn | 1 | 38 522 | 236 | 37 632 | tool-calls | 1 |
| 6 | 05:45:02.861 | 1 506 | main_turn | 1 | — | — | — | cancelled | 0 |

**Кросс-проверка с `cli\log`** (подписанный источник): `tool.call.completed` = **4** события, все `Bash`, `durationMs` в событиях не заполнены. Rollout `response.toolCalls` = **5** (сумма по запросам 1–5). Расхождение на 1: tool-call из ответа запроса 5 не имеет события `tool.call.completed` в логе (сессия прервана до его выполнения). Канонический счёт tool-вызовов — по rollout = **5**.

## 4. Серверные метрики (TabbyAPI)

`#N` — канонические из `tabby_matches` скрипта (совпадают в прозе и таблице). Матчинг по (время +04:00, точные prompt/gen токены), сегмент 1 (без рестарта в окне).

| #N | conf | prompt | gen | %cached | new T/s | gen T/s | TTFT | draft accepted | Δ (с) |
|---|---|---|---|---|---|---|---|---|---|
| #5 | high | 37 052 | 124 | 0 % (none) | 910 | 60.5 | 40.7 s | 91/122 (75 %) | 46.75 |
| #6 | high | 37 204 | 173 | 99 % | 351 | 65.3 | 0.99 s | 131/163 (80 %) | 5.64 |
| #7 | high | 37 446 | 164 | 99 % | 336 | 59.3 | 0.99 s | 120/170 (71 %) | 5.34 |
| #8 | high | 37 761 | 113 | 99 % | 389 | 58.6 | 1.01 s | 82/116 (71 %) | 4.14 |
| #9 | high | 38 522 | 236 | 98 % | 578 | 57.2 | 1.56 s | 170/242 (70 %) | 6.59 |
| #10 | low | 38 865 | — | — | — | — | — | — | 3.45 |

- **Доля low-confidence:** 1/6 = **16.7 %** — это cancelled-запрос **#10** (без usage в rollout): матчен по start-строке в окне [−5; +60] с, prompt-токены (38 865) взяты из start-строки, gen недоступен.
- **unmatched:** 0.
- TTFT #5 аномально высок (40.7 s) — первый запрос после простоя сервера (cold start, none cached); остальные 0.99–1.56 s при 98–99 % cached.

## 5. GPU/CPU

**`unavailable`** — внешний poller (фаза B) перед прогоном не запускался, исторического ряда GPU/CPU нет. По инварианту «не выдумывать»: блок помечен `unavailable` с причиной, ноль и оценка не подставляются.

## 6. Параметры модели

**Слой (а) — `request.body` из rollout** (клиент не шлёт sampling-параметры):
- model: `Qwen3.8-27B-exl3`
- max_tokens: `8192`
- tool_choice: `auto`
- template_vars.reasoning_effort: `low`

**Слой (б) — серверные фолбэки `config.yml`:**
- `override_preset: safe_defaults` → temperature 0.8, top_k 40, top_p 0.95, min_p 0.05
- инлайн: temperature 0.7, max_tokens 8192 (force: false)

**Слой (в) — инференс-конфиг:**
- max_seq_len 130 000, cache 130 048, cache_mode 5,4
- max_batch_size 1, MTP draft, exl3-квант

**Статус подтверждения:** подтверждено per-request из логов сервера — в окне прогона каждая metric-строка содержит аннотацию `(preset)` с фактическими sampler-значениями (temperature 0.7, min_p 0.05, top_k 40, top_p 0.95), совпадающими со слоем (б).

## 7. Ограничения прогона

- **Субагентов не было** — каталог `cli/agents/<sessId>/` отсутствует → per-agent агрегаты `unavailable` (нет `metadata.json`). Вся работа — в main-сессии.
- **GPU/CPU** — `unavailable`: poller (фаза B) не запускался, исторического ряда нет.
- **Версия харнеса/сервера** — `unavailable`: не зафиксирована в rollout/логах.
- **Сессия прервана** (`interrupted`): запрос #6 (32f45bfb) отменён — client disconnected на сервере, generation cancelled.
- **Restarts сервера в окне:** отсутствуют (сегмент 1, счётчик `#N` непрерывен).

## 8. Ретраи/ошибки

**Ретраи:** отсутствуют — `retried_requests` пуст, ни один запрос не имеет `attempt>1`.

**Ошибки** (2 события, оба по отменённому запросу #6 / `32f45bfb`):

| Время (UTC) | Событие | status | retryable/canRetry | reason |
|---|---|---|---|---|
| 05:45:04.372 | `model.request.failed` | cancelled | retryable: false | cancelled |
| 05:45:04.374 | `model.retry.delay.resolved` | failed | canRetry: false | cancelled |

Оба события — следствие отмены запроса клиентом (client disconnected на сервере), а не сетевой/модельной ошибки: `retryable=false`, `canRetry=false`, повторных попыток не было. `maxAttempts=11` / `maxRetries=10` — конфигурация харнеса, фактически не задействована.