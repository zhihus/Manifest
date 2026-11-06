# Eval-Report: /coder

**Версия протокола:** plan-telemetry-model-evaluation-1.1.0 · **Дата отчёта:** 2026-11-06 · **Аналитик:** skill eval-analyze (Phase C)

---

## 1. Шапка

| Поле | Значение |
|---|---|
| Session | `sess_eb6697c6-acd8-4a7d-9920-66852a6dc1a4` — «/coder» (первая по времени начала сессия 2026-11-06 с этим названием) |
| Модель / провайдер | `new-provider-65k/Qwen3.8-27B-exl3` (TabbyAPI-форк, WSL2, порт 127.0.0.1:42424, git `15484e2`) |
| Окно прогона (UTC) | 2026-11-06 05:42:18.636 → 05:45:04.367 (wall-clock 2 мин 46 с) |
| Модельные запросы (rollout) | первый 05:42:18.636, последний 05:45:02.861 |
| Харнес | ZCode desktop (версия не зафиксирована в телеметрии), workspace `C:\WorkProjects\context-files-guard` |
| Задача | без зафиксированного `docs/eval/task-NNN.md` (заголовок сессии `/coder`) |
| Скрипт | `extract_metrics.py` v1.2.0, mtime 2026-11-05 16:14 UTC |
| Архив | `Temp/eval-archive-20261106/` (rollout, log 2026-11-06, tabby-лог окна, tasks-index + wal/shm; сверен 1:1) |

## 2. Сводка per-agent

Субагентов не было: каталог `cli\agents\<sessId>\` отсутствует → per-agent агрегаты `unavailable` (не «0»).

| Профиль | Агентов | Статус | Input | Output | Cache read | Reasoning | Время суммарно | Tool-вызовы |
|---|---|---|---|---|---|---|---|---|
| **Main-сессия** | 1 | — | 187 985 | 810 | 148 992 | 0 | 64 046 мс (сумма 6 запросов) | 5 |
| **ВСЕГО прогон** | 1 | | **187 985** | **810** | **148 992** | 0 | | 5 |

Иерархия: один уровень (main-сессия), субагентов нет. Итерации: 6 запросов в одном turn (`turn_878e9826-01df-4b84-8692-973cc76fce63`), все `main_turn`, attempt=1. Tool-вызовы main-сессии = 5 (по `response.toolCalls` rollout; канонический источник).

## 3. Per-request (rollout, 6 записей)

6 `main_turn`-запросов, все attempt=1, один turn. Usage = input / output токены.

| # | start (UTC) | dur (мс) | querySource | attempt | usage (in/out) | cache read | finishReason | toolCalls |
|---|---|---|---|---|---|---|---|---|
| 0 | 05:42:18.636 | 44 761 | main_turn | 1 | 37 052 / 124 | 0 | tool-calls | 1 |
| 1 | 05:43:04.445 | 4 078 | main_turn | 1 | 37 204 / 173 | 36 864 | tool-calls | 1 |
| 2 | 05:43:09.092 | 4 168 | main_turn | 1 | 37 446 / 164 | 37 120 | tool-calls | 1 |
| 3 | 05:43:13.548 | 3 269 | main_turn | 1 | 37 761 / 113 | 37 376 | tool-calls | 1 |
| 4 | 05:43:17.104 | 6 264 | main_turn | 1 | 38 522 / 236 | 37 632 | tool-calls | 1 |
| 5 | 05:45:02.861 | 1 506 | main_turn | 1 | — (cancelled) | — | None | 0 |

Чек-проверка против `cli\log\zcode-2026-11-06.jsonl` (источник: события лога, кросс-проверка): 4 tool-вызова в логе (4 `tool.call.started` + 4 `tool.call.completed`) против 5 toolCalls в rollout — лог не полнее rollout для этого окна; канонический счёт — rollout (инвариант). Reasoning-токены: 0 во всех записях.

## 4. Серверные метрики (TabbyAPI)

Матчинг каноническим `extract_metrics.py` (критерии плана, шаг C.3). Лог сервера: `2026-11-06_09-36-48_383164.log` (окно прогона 09:42–09:45 локального времени +04:00). Рестартов сервера в окне не было.

| #N | prompt | cached | new T/s | gen T/s | TTFT | total | draft accepted | confidence |
|---|---|---|---|---|---|---|---|---|
| #5 | 37 052 | 0% | 910 | 60.5 | 40.7 с | 42.8 с | 91/122 (75%) | high |
| #6 | 37 204 | 99% | 351 | 65.3 | 0.99 с | 3.64 с | 131/163 (80%) | high |
| #7 | 37 446 | 99% | 336 | 59.3 | 0.99 с | 3.76 с | 120/170 (71%) | high |
| #8 | 37 761 | 99% | 389 | 58.6 | 1.01 с | 2.94 с | 82/116 (71%) | high |
| #9 | 38 522 | 98% | 578 | 57.2 | 1.56 с | 5.69 с | 170/242 (70%) | high |
| #10 | 38 865 | — | — | — (cancelled) | — | — | — | low |

Распределение confidence: **5 high / 0 medium / 1 low / 0 unmatched**. Доля low-confidence: 1 из 6 (17%) — cancelled-запрос #10, матчит по start-строке (prompt 38 865, gen неизвестен: `client disconnected, generation cancelled`).

Кросс-проверка draft: accepted-счета rollout `providerMetadata` (91, 131, 120, 82, 170) совпадают с accepted в строках сервера #5–#9 построчно.

## 5. GPU/CPU

`unavailable` — внешний GPU/CPU-поллер (фаза B) до прогона не запускался, исторического ряда нет. Данные не выдумываются.

## 6. Параметры модели

**Статус подтверждения: подтверждено per-request** — в окне прогона у всех 6 запросов есть `(preset)`-аннотации в start-строках лога сервера.

(a) `request.body` rollout (все 6 запросов идентичны): `model=Qwen3.8-27B-exl3`, `max_tokens=8192`, `tool_choice=auto`, `template_vars.reasoning_effort=low`. Sampling-параметров клиент не шлёт.

(b) Серверные фолбэки `config.yml`: `override_preset: safe_defaults` (temp 0.8, top_k 40, top_p 0.95, min_p 0.05) + инлайн temperature 0.7, max_tokens 8192 (force:false).

(c) Инференс-конфиг: max_seq_len 130000, cache 130048, cache_mode 5,4, max_batch_size 1, MTP draft, exl3-квант.

Фактические sampler-значения per-request (из `(preset)`-аннотаций, все 6 запросов): temperature 0.7, min_p 0.05, top_k 40, top_p 0.95; max_tokens 8192 (req).

## 7. Ограничения прогона

- Субагентов не было → per-agent агрегаты `unavailable` (каталог `cli\agents\<sessId>\` отсутствует).
- GPU/CPU-поллер не запускался → блок 5 `unavailable`.
- Последний запрос (#10, 05:45:02.861Z) отменён пользователем (`v4 session stopped`) — окно прогона завершено cancelled-запросом; его usage в rollout отсутствует, prompt-токены (38 865) взяты из start-строки сервера.
- Файл задачи `docs/eval/task-NNN.md` не зафиксирован.

## 8. Ретраи/ошибки

Ретраев не было: все 6 запросов attempt=1, `retried_requests` пуст.

Ошибки (2 события, оба по отменённому запросу #10, 05:45:04.37Z):
- `model.request.failed` (warn, status=cancelled, reason=cancelled, retryable=false, requestId `32f45bfb-cb0d-4a7b-ac35-f1cb6c6f13e0`) — пользователь остановил сессию, не модельная ошибка.
- `model.retry.delay.resolved` (warn, status=failed, canRetry=false, retryReason=network_error) — решение «не ретраить» по той же отмене.

finishReason: 5× `tool-calls`, 1× `None` (cancelled-запрос #10). Подозрительных finishReason нет.