# Падения полного прогона OpenCode 3 ноября 2026

Проверены все **77 кейсов из 12 suites** на OpenCode `2.2.1` с моделью `zai-coding-plan/glm-5.3` (GLM-5.3 Z.AI Coding Plan), включая holdout. Вариант — `with-skill`, без ablation. Исходники всех suites зафиксированы в manifest как commit `c19f611c7d425f7d11e048102363798ced0321d1`.

Начало: **02.11.2026 23:23:55 МСК**. Завершение: **03.11.2026 07:24:56 МСК**. Запланировано **231** обращение (77 × 3); фактически записано **234** результата из-за ошибки разворачивания одного кейса в дополнительные варианты.

**Итог: 144 успешные попытки и 90 неуспешных.** Большинство неуспехов — таймауты. Их нельзя считать подтверждёнными дефектами навыков. В семи результатах подтверждена замена обязательного `serapeum:->` на `declaim`; ещё два результата указывают на возможный дефект REPL-проверки.

## Сводка по типам проблем

| Тип | Попытки | Интерпретация |
| --- | --- | --- |
| Таймаут OpenCode 210 секунд | 80 | Инфраструктурная ошибка; качество результата не установлено |
| Разрыв соединения `ECONNRESET` | 1 | Транспортная ошибка провайдера |
| Нет обязательной сигнатуры `serapeum:->` | 7 | Нарушение инструкции навыка; два связанных assertion на одну попытку |
| REPL: `persistent-repl-state` | 2 | Возможное ложное падение: дедлайн обработан, но служебный флаг остался false |
| **Всего неуспешных** | **90** | Каждая попытка включена ровно в одну группу |

Три лишние попытки входят в 80 таймаутов и уже учтены в этих 90 результатах. Ошибка матрицы не прибавляется к сумме ещё раз. Номера попыток ниже — порядок результатов одного кейса по `test_idx`; у ошибочно размноженного кейса их шесть, у остальных — три. Один кейс может встречаться в нескольких разделах, если разные попытки закончились разными проблемами.

## Результаты по suites

| Suite | Фактически / запланировано | PASS | Assertion FAIL | Таймаут | Прочая ошибка |
| --- | --- | --- | --- | --- | --- |
| [writing-common-lisp][eval-writing-common-lisp] | 33/33 | 16 | 7 | 9 | 1 |
| [avoiding-common-lisp-pitfalls][eval-avoiding-common-lisp-pitfalls] | 18/18 | 17 | 0 | 1 | 0 |
| [clearing-asdf-fasl-cache][eval-clearing-asdf-fasl-cache] | 18/18 | 6 | 0 | 12 | 0 |
| [defining-clos-classes][eval-defining-clos-classes] | 18/18 | 18 | 0 | 0 | 0 |
| [handling-json-in-common-lisp][eval-handling-json-in-common-lisp] | 18/18 | 14 | 0 | 4 | 0 |
| [logging-with-log4cl][eval-logging-with-log4cl] | 18/18 | 8 | 0 | 10 | 0 |
| [testing-with-rove][eval-testing-with-rove] | 18/18 | 6 | 0 | 12 | 0 |
| [using-common-lisp-repl][eval-using-common-lisp-repl] | 18/18 | 16 | 2 | 0 | 0 |
| [lint-common-lisp][eval-lint-common-lisp] | 18/18 | 13 | 0 | 5 | 0 |
| [writing-40ants-doc-documentation][eval-writing-40ants-doc-documentation] | 21/18 | 4 | 0 | 17 | 0 |
| [deploy-40ants-project][eval-deploy-40ants-project] | 18/18 | 18 | 0 | 0 | 0 |
| [nix-shell-playwright][eval-nix-shell-playwright] | 18/18 | 8 | 0 | 10 | 0 |

## 1. Нет обязательного serapeum:-> — 7 попыток

Suite: `writing-common-lisp`. Во всех семи попытках одновременно упали `cl/type-signature` (`type-signature`) и `cl/return-type-layout` (`return-type-layout`). При этом `cl/reader` и `cl/functional` прошли. Это **7 неуспешных попыток, а не 14**.

Архивные исходники подтверждают: агент использовал `(declaim (ftype ...))`, а обязательной формы `serapeum:->` не добавил. Поэтому падение `return-type-layout` здесь производно от отсутствия сигнатуры; оно само по себе не доказывает ошибку отступа в существующей форме `->`.

| Suite | Кейс | Падения этого типа / все попытки кейса | Номера неуспешных попыток |
| --- | --- | --- | --- |
| [writing-common-lisp][eval-writing-common-lisp] | `loop-style` | 1/3 | 1 |
| [writing-common-lisp][eval-writing-common-lisp] | `hook-contract` | 1/3 | 2 |
| [writing-common-lisp][eval-writing-common-lisp] | `heldout-path` | 3/3 | 1, 2, 3 |
| [writing-common-lisp][eval-writing-common-lisp] | `heldout-format` | 2/3 | 1, 2 |

Пример из `loop-style`, попытка 1:

```lisp
(declaim (ftype (function (list) (values integer &optional)) sum-even))
(defun sum-even (integers)
  ...)
```

В `hook-contract`, третьей попытке `heldout-path` и первой попытке `heldout-format` агент в комментариях объясняет замену предполагаемой недоступностью Serapeum. Это объяснение агента, а не подтверждённый факт об окружении. В инструкции навыка явно указано, что уже установленную Serapeum использовать можно.

### Исходники и результаты каждой из семи попыток

| Кейс | Попытка | Архивный код | Все assertions |
| --- | --- | --- | --- |
| `loop-style` | 1 | [src/numbers.lisp](</Users/art/projects/lisp/ai/.evals/runs/2026-11-02T20-24-00-924556Z-94237c/samples/loop-style-with-skill-opencode-6353eddc/files/src/numbers.lisp>) | [grading.json](</Users/art/projects/lisp/ai/.evals/runs/2026-11-02T20-24-00-924556Z-94237c/samples/loop-style-with-skill-opencode-6353eddc/grading.json>) |
| `hook-contract` | 2 | [src/hooks.lisp](</Users/art/projects/lisp/ai/.evals/runs/2026-11-02T20-24-00-924556Z-94237c/samples/hook-contract-with-skill-opencode-e6e89dd2/files/src/hooks.lisp>) | [grading.json](</Users/art/projects/lisp/ai/.evals/runs/2026-11-02T20-24-00-924556Z-94237c/samples/hook-contract-with-skill-opencode-e6e89dd2/grading.json>) |
| `heldout-path` | 1 | [src/domain/account/balance.lisp](</Users/art/projects/lisp/ai/.evals/runs/2026-11-02T20-24-00-924556Z-94237c/samples/heldout-path-with-skill-opencode-ba236058/files/src/domain/account/balance.lisp>) | [grading.json](</Users/art/projects/lisp/ai/.evals/runs/2026-11-02T20-24-00-924556Z-94237c/samples/heldout-path-with-skill-opencode-ba236058/grading.json>) |
| `heldout-path` | 2 | [src/domain/account/balance.lisp](</Users/art/projects/lisp/ai/.evals/runs/2026-11-02T20-24-00-924556Z-94237c/samples/heldout-path-with-skill-opencode-269b95cf/files/src/domain/account/balance.lisp>) | [grading.json](</Users/art/projects/lisp/ai/.evals/runs/2026-11-02T20-24-00-924556Z-94237c/samples/heldout-path-with-skill-opencode-269b95cf/grading.json>) |
| `heldout-path` | 3 | [src/domain/account/balance.lisp](</Users/art/projects/lisp/ai/.evals/runs/2026-11-02T20-24-00-924556Z-94237c/samples/heldout-path-with-skill-opencode-3dff112a/files/src/domain/account/balance.lisp>) | [grading.json](</Users/art/projects/lisp/ai/.evals/runs/2026-11-02T20-24-00-924556Z-94237c/samples/heldout-path-with-skill-opencode-3dff112a/grading.json>) |
| `heldout-format` | 1 | [src/predicates.lisp](</Users/art/projects/lisp/ai/.evals/runs/2026-11-02T20-24-00-924556Z-94237c/samples/heldout-format-with-skill-opencode-3787f7bb/files/src/predicates.lisp>) | [grading.json](</Users/art/projects/lisp/ai/.evals/runs/2026-11-02T20-24-00-924556Z-94237c/samples/heldout-format-with-skill-opencode-3787f7bb/grading.json>) |
| `heldout-format` | 2 | [src/predicates.lisp](</Users/art/projects/lisp/ai/.evals/runs/2026-11-02T20-24-00-924556Z-94237c/samples/heldout-format-with-skill-opencode-6a73bcde/files/src/predicates.lisp>) | [grading.json](</Users/art/projects/lisp/ai/.evals/runs/2026-11-02T20-24-00-924556Z-94237c/samples/heldout-format-with-skill-opencode-6a73bcde/grading.json>) |

## 2. REPL deadline — 2 возможных ложных падения

Suite: `using-common-lisp-repl`, кейс `deadline`, попытки **1 и 2 из 3**. Третья попытка прошла. Упал только `skill/repl-state`, имя результата — `persistent-repl-state`.

Ожидание кейса — `counter=41` и `deadlineExpired=true`. По результатам реальных MCP-вызовов в обеих неуспешных попытках:

- Агент запустил бесконечный цикл под `sb-sys:with-deadline` с лимитом 1 секунда.
- Внутренний `handler-case` поймал `SB-SYS:DEADLINE-TIMEOUT`; инструмент вернул тип условия и сообщение о достижении дедлайна.
- Следующий вызов успешно прочитал `DEMO/STATE:READ-COUNTER`, получив `41`; живой образ сохранился.
- Служебный `state.deadlineExpired` в ответах инструмента остался `false`.

Проверка сравнивает именно служебный флаг последнего вызова с `true`. По наблюдаемому поведению задача выполнена, но этот флаг не подтверждает дедлайн, обработанный внутри пользовательской формы. **Вероятная проблема — контракт assertion/сбор свидетельств, а не доказанный дефект навыка.** Оригинальные оценки оставлены без изменений.

| Попытка | Sample | Native tool evidence | Assertions |
| --- | --- | --- | --- |
| 1 | `deadline-with-skill-opencode-6f2ab18e` | [sample.json](</Users/art/projects/lisp/ai/.evals/runs/2026-11-03T01-12-09-910309Z-571822/samples/deadline-with-skill-opencode-6f2ab18e/sample.json>) | [grading.json](</Users/art/projects/lisp/ai/.evals/runs/2026-11-03T01-12-09-910309Z-571822/samples/deadline-with-skill-opencode-6f2ab18e/grading.json>) |
| 2 | `deadline-with-skill-opencode-19915a25` | [sample.json](</Users/art/projects/lisp/ai/.evals/runs/2026-11-03T01-12-09-910309Z-571822/samples/deadline-with-skill-opencode-19915a25/sample.json>) | [grading.json](</Users/art/projects/lisp/ai/.evals/runs/2026-11-03T01-12-09-910309Z-571822/samples/deadline-with-skill-opencode-19915a25/grading.json>) |

Контракт кейса: [cases.json](</Users/art/projects/lisp/ai/evals/using-common-lisp-repl/cases.json:97>). Реализация проверки: [repl-check](</Users/art/projects/lisp/ai/evals/checks/skill-behavior/checks.lisp:185>).

## 3. Таймаут OpenCode — 80 попыток

Точный текст ошибки для всех 80 записей: `OpenCode sample timed out after 210.0s`. Лимит работы агента — 210 секунд, общий лимит sample — 240 секунд. Эти результаты не были оценены как обычные assertion failures. По одному таймауту нельзя определить, была ли причина в модели, выполнении команды, загрузке зависимостей или подготовленном окружении.

| Suite | Кейс | Падения этого типа / все попытки кейса | Номера неуспешных попыток |
| --- | --- | --- | --- |
| [writing-common-lisp][eval-writing-common-lisp] | `loop-style` | 2/3 | 2, 3 |
| [writing-common-lisp][eval-writing-common-lisp] | `exhaustive-dispatch` | 1/3 | 3 |
| [writing-common-lisp][eval-writing-common-lisp] | `formatted-error` | 3/3 | 1, 2, 3 |
| [writing-common-lisp][eval-writing-common-lisp] | `hook-contract` | 1/3 | 3 |
| [writing-common-lisp][eval-writing-common-lisp] | `project-override` | 2/3 | 1, 2 |
| [avoiding-common-lisp-pitfalls][eval-avoiding-common-lisp-pitfalls] | `stripped-output` | 1/3 | 3 |
| [clearing-asdf-fasl-cache][eval-clearing-asdf-fasl-cache] | `smoke` | 3/3 | 1, 2, 3 |
| [clearing-asdf-fasl-cache][eval-clearing-asdf-fasl-cache] | `multi-version` | 3/3 | 1, 2, 3 |
| [clearing-asdf-fasl-cache][eval-clearing-asdf-fasl-cache] | `path-spaces` | 3/3 | 1, 2, 3 |
| [clearing-asdf-fasl-cache][eval-clearing-asdf-fasl-cache] | `automatic` | 3/3 | 1, 2, 3 |
| [handling-json-in-common-lisp][eval-handling-json-in-common-lisp] | `smoke` | 2/3 | 1, 2 |
| [handling-json-in-common-lisp][eval-handling-json-in-common-lisp] | `heldout-nested-roundtrip` | 1/3 | 1 |
| [handling-json-in-common-lisp][eval-handling-json-in-common-lisp] | `automatic` | 1/3 | 3 |
| [logging-with-log4cl][eval-logging-with-log4cl] | `smoke` | 2/3 | 1, 3 |
| [logging-with-log4cl][eval-logging-with-log4cl] | `formatted-count` | 1/3 | 3 |
| [logging-with-log4cl][eval-logging-with-log4cl] | `package-inference` | 3/3 | 1, 2, 3 |
| [logging-with-log4cl][eval-logging-with-log4cl] | `heldout-error-value` | 1/3 | 3 |
| [logging-with-log4cl][eval-logging-with-log4cl] | `automatic` | 3/3 | 1, 2, 3 |
| [testing-with-rove][eval-testing-with-rove] | `smoke` | 1/3 | 2 |
| [testing-with-rove][eval-testing-with-rove] | `test-op` | 3/3 | 1, 2, 3 |
| [testing-with-rove][eval-testing-with-rove] | `global-restoration` | 3/3 | 1, 2, 3 |
| [testing-with-rove][eval-testing-with-rove] | `heldout-specific-condition` | 2/3 | 1, 2 |
| [testing-with-rove][eval-testing-with-rove] | `automatic` | 3/3 | 1, 2, 3 |
| [lint-common-lisp][eval-lint-common-lisp] | `scope-vendor` | 1/3 | 2 |
| [lint-common-lisp][eval-lint-common-lisp] | `heldout-runtime-import` | 2/3 | 1, 3 |
| [lint-common-lisp][eval-lint-common-lisp] | `automatic` | 2/3 | 2, 3 |
| [writing-40ants-doc-documentation][eval-writing-40ants-doc-documentation] | `smoke` | 3/3 | 1, 2, 3 |
| [writing-40ants-doc-documentation][eval-writing-40ants-doc-documentation] | `autodoc` | 3/3 | 1, 2, 3 |
| [writing-40ants-doc-documentation][eval-writing-40ants-doc-documentation] | `xref-warning` | 2/3 | 1, 3 |
| [writing-40ants-doc-documentation][eval-writing-40ants-doc-documentation] | `heldout-functional-changelog` | 6/6 | 1, 2, 3, 4, 5, 6 |
| [writing-40ants-doc-documentation][eval-writing-40ants-doc-documentation] | `automatic` | 3/3 | 1, 2, 3 |
| [nix-shell-playwright][eval-nix-shell-playwright] | `smoke` | 3/3 | 1, 2, 3 |
| [nix-shell-playwright][eval-nix-shell-playwright] | `server-required` | 2/3 | 1, 3 |
| [nix-shell-playwright][eval-nix-shell-playwright] | `missing-browser` | 2/3 | 1, 2 |
| [nix-shell-playwright][eval-nix-shell-playwright] | `heldout-existing-shell` | 3/3 | 1, 2, 3 |

Всего затронуто **35 различных кейсов**. В документационном `heldout-functional-changelog` все 6 фактически выполненных попыток завершились таймаутом; лишние 3 описаны отдельно ниже. Полный реестр всех 80 записей находится в приложении.

## 4. Разрыв соединения провайдера — 1 попытка

Suite: `writing-common-lisp`, кейс `exhaustive-dispatch`, попытка **2 из 3**. Первая попытка прошла, третья завершилась таймаутом.

Promptfoo показывает `OpenCode assistant reported a model or execution error`. В архивном экспорте OpenCode, `export.data.messages[5].error`, причина уточнена:

```text
type: provider.transport
Connection lost while reading the response: ECONNRESET:
The socket connection was closed unexpectedly.
```

Это транспортная ошибка при чтении ответа, а не падение Lisp-проверки. HTTP status `200` в записи не означает, что поток ответа успешно дочитан.

[Архивный trace.json](</Users/art/projects/lisp/ai/.evals/runs/2026-11-02T20-24-00-924556Z-94237c/opencode/dfcc2363-92ee-4608-be40-d35bd8c4f7bc/trace.json>) · [writing-common-lisp][eval-writing-common-lisp].

## 5. Ошибка обвязки: 3 лишние попытки

В `writing-40ants-doc-documentation / heldout-functional-changelog` зарегистрированы два файла assertions. Обвязка положила служебный список строк `fileResources` в `vars`. Promptfoo развернул этот список в два варианта теста и затем повторил каждый по три раза.

Ожидалось **3** попытки этого кейса; выполнено **6**. Для документационного suite получилось **21 вместо 18**, для всей матрицы — **234 вместо 231**. Статус задания `incomplete` означает расхождение с ожидаемым числом результатов; все 12 suites были обработаны.

Исходное значение в архивном `selected-cases.json`:

```json
"fileResources": [
  "cases/heldout-functional-changelog/assertions-2.lisp",
  "cases/heldout-functional-changelog/assertions-1.lisp"
]
```

В результатах отдельных попыток это поле уже является одной строкой. Каждая из двух строк встречается в трёх результатах. Все шесть попыток закончились таймаутом. Данные сохранены как есть; три лишние записи не удалялись и не маскировались.

[Архивная конфигурация кейсов](</Users/art/projects/lisp/ai/.evals/runs/2026-11-03T02-05-36-691606Z-363a43/harness/evals/writing-40ants-doc-documentation/selected-cases.json>) · [Статус задания](</Users/art/projects/lisp/ai/.evals/jobs/all-opencode-3x-2026-11-02T20-20-30Z/status.json>).

## Дополнительное наблюдение по изоляции ASDF

В `loop-style`, попытка 1, агент вызвал `(asdf:load-system :demo)` из собственного workspace. В выводе этой команды присутствует компиляция `evals/clearing-asdf-fasl-cache/cases/automatic/fixtures/src/counter.lisp` из основного проекта. Это посторонняя fixture-система, а не только что созданный агентом `demo/src/numbers`.

Наблюдение указывает на риск конфликта одноимённых ASDF-систем между fixtures. Оно не посчитано отдельным падением и не доказывает причину всех таймаутов. Перед массовым повтором стоит проверить source registry и однозначность загрузки систем в изолированном workspace.

[Trace с выводом команды](</Users/art/projects/lisp/ai/.evals/runs/2026-11-02T20-24-00-924556Z-94237c/opencode/b005489c-6bb0-4e7c-ae72-5efdf4198f38/trace.json>).

## Что проверять дальше

1. Устранить разворачивание служебного `fileResources` в варианты теста; проверять число реально запланированных попыток до обращения к модели.
2. Проверить изоляцию ASDF-систем и корректность разрешения `demo` в workspace.
3. Пересмотреть контракт REPL deadline: обработанный внутри формы дедлайн не должен автоматически считаться провалом из-за одного служебного флага.
4. Для таймаутов разобрать последние завершённые tool calls и длительности по отдельным кейсам; увеличение лимита без диагностики не подтверждает исправление.
5. Для `writing-common-lisp` разбирать семь подтверждённых замен `serapeum:->` на `declaim`; пока не смешивать их с инфраструктурными ошибками.

При подготовке этого отчёта модели не запускались, assertions и навыки не менялись, архивные оценки не переписывались.

## Приложение: полный реестр 90 неуспешных попыток

Каждая запись ниже соответствует одному уникальному `eval_results.id` в базе Promptfoo. `test_idx` — исходный индекс результата с нуля. Он указан явно, поскольку порядок строк интерфейса может меняться при фильтрации. UUID позволяет однозначно найти результат независимо от наличия `sample.json`.

### Нет serapeum:-> — 7

| Suite / UI | Кейс | Попытка | test_idx | Latency, с | Result ID |
| --- | --- | --- | --- | --- | --- |
| [writing-common-lisp][eval-writing-common-lisp] | `loop-style` | 1 | 3 | 144.4 | `f3961119-6a25-4156-8469-b6c97a94a3d6` |
| [writing-common-lisp][eval-writing-common-lisp] | `hook-contract` | 2 | 16 | 131.8 | `e8bd3164-f903-4d72-ad37-f7fbb825e3c0` |
| [writing-common-lisp][eval-writing-common-lisp] | `heldout-path` | 1 | 27 | 59.9 | `52ca05aa-74b1-4e41-ae8f-16d3a67776f3` |
| [writing-common-lisp][eval-writing-common-lisp] | `heldout-path` | 2 | 28 | 90.8 | `98c127e4-ab9e-4c65-b7c6-c13a60d6e251` |
| [writing-common-lisp][eval-writing-common-lisp] | `heldout-path` | 3 | 29 | 68.1 | `463b0846-3fb5-4a5e-b448-21a117b4459a` |
| [writing-common-lisp][eval-writing-common-lisp] | `heldout-format` | 1 | 30 | 90.1 | `6f4cf7d4-b5f8-4a62-a8bb-2eb4d87d3e63` |
| [writing-common-lisp][eval-writing-common-lisp] | `heldout-format` | 2 | 31 | 79.6 | `d652b65a-191a-4bdf-8cc2-4969a294f9d5` |

### REPL deadline — 2

| Suite / UI | Кейс | Попытка | test_idx | Latency, с | Result ID |
| --- | --- | --- | --- | --- | --- |
| [using-common-lisp-repl][eval-using-common-lisp-repl] | `deadline` | 1 | 6 | 72.3 | `80df43ce-aafa-4e3e-99ae-a49500b97425` |
| [using-common-lisp-repl][eval-using-common-lisp-repl] | `deadline` | 2 | 7 | 39.9 | `dc8fd333-ea28-4208-a268-3a89aa6e24fb` |

### Таймаут 210 секунд — 80

| Suite / UI | Кейс | Попытка | test_idx | Latency, с | Result ID |
| --- | --- | --- | --- | --- | --- |
| [writing-common-lisp][eval-writing-common-lisp] | `loop-style` | 2 | 4 | 211.8 | `d6317192-1869-4fef-85ad-854264cc893f` |
| [writing-common-lisp][eval-writing-common-lisp] | `loop-style` | 3 | 5 | 211.8 | `e40ffbaf-2311-460f-b813-3d90df34a92b` |
| [writing-common-lisp][eval-writing-common-lisp] | `exhaustive-dispatch` | 3 | 8 | 212.0 | `744d653e-fb28-473b-ab3e-76fbefdd3ded` |
| [writing-common-lisp][eval-writing-common-lisp] | `formatted-error` | 1 | 9 | 211.8 | `17ddde76-1151-4f93-a9c0-3e163d5b1b0f` |
| [writing-common-lisp][eval-writing-common-lisp] | `formatted-error` | 2 | 10 | 211.9 | `964c03e8-2551-409a-8c8a-d558062fc6e8` |
| [writing-common-lisp][eval-writing-common-lisp] | `formatted-error` | 3 | 11 | 211.9 | `f2c035e6-739c-43e4-a590-cf32c68f9d6c` |
| [writing-common-lisp][eval-writing-common-lisp] | `hook-contract` | 3 | 17 | 211.9 | `24527173-7d46-4193-8fcd-da9e33074fc9` |
| [writing-common-lisp][eval-writing-common-lisp] | `project-override` | 1 | 18 | 211.8 | `6f086e09-887f-4e26-8457-7b131f773f04` |
| [writing-common-lisp][eval-writing-common-lisp] | `project-override` | 2 | 19 | 211.8 | `c3b39666-bb96-4c25-9c97-3c2c8ec7d29c` |
| [avoiding-common-lisp-pitfalls][eval-avoiding-common-lisp-pitfalls] | `stripped-output` | 3 | 5 | 211.6 | `f7d898e9-806b-40df-a96e-174a0e46dd85` |
| [clearing-asdf-fasl-cache][eval-clearing-asdf-fasl-cache] | `smoke` | 1 | 0 | 211.9 | `c244d565-5bf2-455d-a17a-a484259c0e69` |
| [clearing-asdf-fasl-cache][eval-clearing-asdf-fasl-cache] | `smoke` | 2 | 1 | 211.7 | `fdc6ed03-5c06-4e8b-aa08-d05d7816c7ce` |
| [clearing-asdf-fasl-cache][eval-clearing-asdf-fasl-cache] | `smoke` | 3 | 2 | 211.7 | `4e85413c-9879-447c-b3f6-6bdb08346bcd` |
| [clearing-asdf-fasl-cache][eval-clearing-asdf-fasl-cache] | `multi-version` | 1 | 3 | 211.7 | `e4a36cf3-9a0f-4c45-ac27-921c57bbe04e` |
| [clearing-asdf-fasl-cache][eval-clearing-asdf-fasl-cache] | `multi-version` | 2 | 4 | 211.6 | `a237b86d-5916-40b1-8575-5f5675e227cf` |
| [clearing-asdf-fasl-cache][eval-clearing-asdf-fasl-cache] | `multi-version` | 3 | 5 | 211.6 | `15b40208-b2ae-4606-a075-9faeaa36037d` |
| [clearing-asdf-fasl-cache][eval-clearing-asdf-fasl-cache] | `path-spaces` | 1 | 6 | 211.6 | `17e36e8a-0e2c-4c10-bd10-681f717c9870` |
| [clearing-asdf-fasl-cache][eval-clearing-asdf-fasl-cache] | `path-spaces` | 2 | 7 | 211.6 | `195f1638-97db-4e67-87e0-1c9ee74d9a19` |
| [clearing-asdf-fasl-cache][eval-clearing-asdf-fasl-cache] | `path-spaces` | 3 | 8 | 211.6 | `c69c349a-5b7e-4d25-951f-6586e0ed1f04` |
| [clearing-asdf-fasl-cache][eval-clearing-asdf-fasl-cache] | `automatic` | 1 | 12 | 211.6 | `1764600d-3f8c-4878-a8f9-c24c1036f244` |
| [clearing-asdf-fasl-cache][eval-clearing-asdf-fasl-cache] | `automatic` | 2 | 13 | 211.6 | `a5a7c5c9-0666-4ad2-88dd-3235051bbfde` |
| [clearing-asdf-fasl-cache][eval-clearing-asdf-fasl-cache] | `automatic` | 3 | 14 | 211.6 | `370ef13d-814e-41c7-9e78-330ff0fea2a0` |
| [handling-json-in-common-lisp][eval-handling-json-in-common-lisp] | `smoke` | 1 | 0 | 211.9 | `4a6f46a8-ad12-4b9c-a77b-71f44159a61b` |
| [handling-json-in-common-lisp][eval-handling-json-in-common-lisp] | `smoke` | 2 | 1 | 211.6 | `e20a144b-b67b-4efa-8bf7-f1ad027e23da` |
| [handling-json-in-common-lisp][eval-handling-json-in-common-lisp] | `heldout-nested-roundtrip` | 1 | 9 | 211.6 | `1e7f7d61-b7de-47e6-bf60-6815d5569be6` |
| [handling-json-in-common-lisp][eval-handling-json-in-common-lisp] | `automatic` | 3 | 14 | 211.7 | `79caa744-277a-4a66-a5e8-e185cb9fb990` |
| [logging-with-log4cl][eval-logging-with-log4cl] | `smoke` | 1 | 0 | 211.9 | `41e773b2-b795-46e4-b573-8deab5ec74ba` |
| [logging-with-log4cl][eval-logging-with-log4cl] | `smoke` | 3 | 2 | 211.6 | `2acedc2b-f3a1-47ba-9d66-a6e1bdf77cf4` |
| [logging-with-log4cl][eval-logging-with-log4cl] | `formatted-count` | 3 | 5 | 211.6 | `e696d689-740b-4e6d-af75-b493d4db9691` |
| [logging-with-log4cl][eval-logging-with-log4cl] | `package-inference` | 1 | 6 | 211.6 | `3e6bdab6-5ae2-4f83-b78e-d5a84548188f` |
| [logging-with-log4cl][eval-logging-with-log4cl] | `package-inference` | 2 | 7 | 211.6 | `2ed4e264-47b7-4396-94df-cad6ace57b52` |
| [logging-with-log4cl][eval-logging-with-log4cl] | `package-inference` | 3 | 8 | 211.6 | `f3297190-31d2-4294-be9d-421fa3883de6` |
| [logging-with-log4cl][eval-logging-with-log4cl] | `heldout-error-value` | 3 | 11 | 211.6 | `a35e339e-6499-48a3-b049-fac48eec6beb` |
| [logging-with-log4cl][eval-logging-with-log4cl] | `automatic` | 1 | 12 | 211.6 | `bd4ca5ec-194e-4cef-a06b-66a24d2265b0` |
| [logging-with-log4cl][eval-logging-with-log4cl] | `automatic` | 2 | 13 | 211.6 | `456a0691-183f-4553-8cc0-50bcfe50c052` |
| [logging-with-log4cl][eval-logging-with-log4cl] | `automatic` | 3 | 14 | 211.6 | `dfdfe3b4-a517-4bd8-ad40-bceb7afa5547` |
| [testing-with-rove][eval-testing-with-rove] | `smoke` | 2 | 1 | 211.6 | `b81c7674-b490-4c97-a1c5-64899d18eeda` |
| [testing-with-rove][eval-testing-with-rove] | `test-op` | 1 | 3 | 211.7 | `cc5fc051-f744-4d2d-9953-d6aad5474c95` |
| [testing-with-rove][eval-testing-with-rove] | `test-op` | 2 | 4 | 211.6 | `b821c149-d21b-4c79-86e0-c8208fb9f48c` |
| [testing-with-rove][eval-testing-with-rove] | `test-op` | 3 | 5 | 211.6 | `6ef36fec-d5b8-4dcd-bcc8-81b35161a4b0` |
| [testing-with-rove][eval-testing-with-rove] | `global-restoration` | 1 | 6 | 211.6 | `c77ecd4a-7ab5-4be4-a969-d276a6db4181` |
| [testing-with-rove][eval-testing-with-rove] | `global-restoration` | 2 | 7 | 211.6 | `963cda56-dcf0-4d3f-bd20-7b00feabd3e1` |
| [testing-with-rove][eval-testing-with-rove] | `global-restoration` | 3 | 8 | 211.6 | `76c2ff55-62d2-48bf-bf23-045a551bc8d4` |
| [testing-with-rove][eval-testing-with-rove] | `heldout-specific-condition` | 1 | 9 | 211.6 | `9536d47e-23b8-4c9c-9802-baf1cd72dd6d` |
| [testing-with-rove][eval-testing-with-rove] | `heldout-specific-condition` | 2 | 10 | 211.6 | `a4393584-4a1b-4e78-88ab-70fb2d02fa7b` |
| [testing-with-rove][eval-testing-with-rove] | `automatic` | 1 | 12 | 211.6 | `94636214-ccb2-4c35-864d-6b4e772d16df` |
| [testing-with-rove][eval-testing-with-rove] | `automatic` | 2 | 13 | 211.7 | `fc00d237-1e1b-4532-b13b-ec1151e27d95` |
| [testing-with-rove][eval-testing-with-rove] | `automatic` | 3 | 14 | 211.6 | `8c5fb5fb-6599-4977-bea2-6a18b1754d6f` |
| [lint-common-lisp][eval-lint-common-lisp] | `scope-vendor` | 2 | 4 | 211.6 | `665a7e30-3dbc-490b-8940-17a7b440808a` |
| [lint-common-lisp][eval-lint-common-lisp] | `heldout-runtime-import` | 1 | 9 | 211.6 | `d697f786-bdad-44dd-a9b4-3475e5f64da4` |
| [lint-common-lisp][eval-lint-common-lisp] | `heldout-runtime-import` | 3 | 11 | 211.6 | `bd6be0b5-f501-47d6-b460-c104e6312183` |
| [lint-common-lisp][eval-lint-common-lisp] | `automatic` | 2 | 13 | 211.6 | `882c5109-41c7-4c7e-86c5-f15c03a5ec89` |
| [lint-common-lisp][eval-lint-common-lisp] | `automatic` | 3 | 14 | 211.7 | `1fdd854b-7bae-4691-afdb-7e52da443c5b` |
| [writing-40ants-doc-documentation][eval-writing-40ants-doc-documentation] | `smoke` | 1 | 0 | 211.9 | `5f191894-57b7-4867-bc6a-3e7055f238ad` |
| [writing-40ants-doc-documentation][eval-writing-40ants-doc-documentation] | `smoke` | 2 | 1 | 211.6 | `3eee5866-3c83-4167-928e-dc73b34d3391` |
| [writing-40ants-doc-documentation][eval-writing-40ants-doc-documentation] | `smoke` | 3 | 2 | 211.6 | `7ffaca1b-75c9-4edd-aa91-bb8019d8ca48` |
| [writing-40ants-doc-documentation][eval-writing-40ants-doc-documentation] | `autodoc` | 1 | 3 | 211.7 | `527a2e17-04cc-4dbc-bc12-81156b93e01b` |
| [writing-40ants-doc-documentation][eval-writing-40ants-doc-documentation] | `autodoc` | 2 | 4 | 211.7 | `a8136456-d8cd-43ee-b58c-b2c39a68fa44` |
| [writing-40ants-doc-documentation][eval-writing-40ants-doc-documentation] | `autodoc` | 3 | 5 | 211.6 | `19e69af3-7ba2-4b0a-b5d1-7b40b2bccb1c` |
| [writing-40ants-doc-documentation][eval-writing-40ants-doc-documentation] | `xref-warning` | 1 | 6 | 211.6 | `28ff2ee5-99d0-41f7-ab27-0a1ac01ebc44` |
| [writing-40ants-doc-documentation][eval-writing-40ants-doc-documentation] | `xref-warning` | 3 | 8 | 211.6 | `701ccd2c-dd4c-4520-8cf9-b5a0115f8fc6` |
| [writing-40ants-doc-documentation][eval-writing-40ants-doc-documentation] | `heldout-functional-changelog` | 1 | 9 | 211.7 | `3928d00d-6391-4789-a4c0-1ac158d705b9` |
| [writing-40ants-doc-documentation][eval-writing-40ants-doc-documentation] | `heldout-functional-changelog` | 2 | 10 | 211.6 | `96e22512-dc39-43fd-94be-27b74fb1a649` |
| [writing-40ants-doc-documentation][eval-writing-40ants-doc-documentation] | `heldout-functional-changelog` | 3 | 11 | 211.6 | `48f78db6-0cf8-44ff-9709-653ca4698ff7` |
| [writing-40ants-doc-documentation][eval-writing-40ants-doc-documentation] | `heldout-functional-changelog` | 4 | 12 | 211.6 | `d0509ac1-cbc2-4d85-a6ba-2960f56c4332` |
| [writing-40ants-doc-documentation][eval-writing-40ants-doc-documentation] | `heldout-functional-changelog` | 5 | 13 | 211.6 | `a19ca3df-fb64-48dd-adbc-0b243bd3aec1` |
| [writing-40ants-doc-documentation][eval-writing-40ants-doc-documentation] | `heldout-functional-changelog` | 6 | 14 | 211.6 | `313ca820-a496-4f2f-a5a4-1397f949930d` |
| [writing-40ants-doc-documentation][eval-writing-40ants-doc-documentation] | `automatic` | 1 | 15 | 211.6 | `0597edef-3c10-4acb-9e3c-17a20b9f8d88` |
| [writing-40ants-doc-documentation][eval-writing-40ants-doc-documentation] | `automatic` | 2 | 16 | 211.6 | `6c5bf3a2-5057-47e3-a60a-a59e93a67232` |
| [writing-40ants-doc-documentation][eval-writing-40ants-doc-documentation] | `automatic` | 3 | 17 | 211.6 | `caf18752-f560-48d9-bc98-282329a310ad` |
| [nix-shell-playwright][eval-nix-shell-playwright] | `smoke` | 1 | 0 | 211.9 | `b32a9d63-82d9-49f5-87e5-451457724ede` |
| [nix-shell-playwright][eval-nix-shell-playwright] | `smoke` | 2 | 1 | 211.6 | `94f376a9-3f62-452b-aadb-2800372ae5e0` |
| [nix-shell-playwright][eval-nix-shell-playwright] | `smoke` | 3 | 2 | 211.6 | `50fec42c-b50f-44cd-88e8-e667a60c7500` |
| [nix-shell-playwright][eval-nix-shell-playwright] | `server-required` | 1 | 3 | 211.7 | `d83f4f68-6bbc-487f-a178-955fc7d4ff1a` |
| [nix-shell-playwright][eval-nix-shell-playwright] | `server-required` | 3 | 5 | 211.7 | `34f0d223-f156-4e94-96ee-63c8d5fb1892` |
| [nix-shell-playwright][eval-nix-shell-playwright] | `missing-browser` | 1 | 6 | 211.6 | `03f3e1b6-76e8-4c56-8495-0ca019f3d747` |
| [nix-shell-playwright][eval-nix-shell-playwright] | `missing-browser` | 2 | 7 | 211.7 | `c8130d93-fe81-45b2-a3cf-5ed654403960` |
| [nix-shell-playwright][eval-nix-shell-playwright] | `heldout-existing-shell` | 1 | 9 | 211.6 | `01f1a172-c5db-4bb4-9939-fe305ba8f7be` |
| [nix-shell-playwright][eval-nix-shell-playwright] | `heldout-existing-shell` | 2 | 10 | 211.6 | `5ce796c9-68aa-4f94-9f24-2db2032afddb` |
| [nix-shell-playwright][eval-nix-shell-playwright] | `heldout-existing-shell` | 3 | 11 | 211.6 | `f58a3c97-0b99-4c1c-b565-e6903670e563` |

### ECONNRESET — 1

| Suite / UI | Кейс | Попытка | test_idx | Latency, с | Result ID |
| --- | --- | --- | --- | --- | --- |
| [writing-common-lisp][eval-writing-common-lisp] | `exhaustive-dispatch` | 2 | 7 | 187.7 | `0e437c45-db05-4545-92f1-6acfbf548f94` |

## Источники и навигация

Полнота реестра сверена с базой Promptfoo, а не только с каталогами `samples/`: неуспешные обращения провайдера могут не иметь стандартного sample-архива. Ссылки на архивы ниже локальные и предполагают доступ к этому checkout.

- [Promptfoo database](</Users/art/projects/lisp/ai/.evals/promptfoo/promptfoo.db>)
- [Batch index](</Users/art/projects/lisp/ai/.evals/batches/ad9827e9-726a-45b6-bc86-13a190fde95e.json>)
- [Job status](</Users/art/projects/lisp/ai/.evals/jobs/all-opencode-3x-2026-11-02T20-20-30Z/status.json>)
- [Общий журнал](</Users/art/projects/lisp/ai/.evals/jobs/all-opencode-3x-2026-11-02T20-20-30Z/run.log>)

В Promptfoo откройте suite, найдите кейс и неуспешную попытку, затем **View output and test details → Evaluation** для причины или **Prompt & Output** для ответа. Индивидуальные проверки также находятся в архивном `grading.json`.

[eval-writing-common-lisp]: http://127.0.0.1:15500/eval/eval-5DI-2026-11-02T20%3A24%3A03
[eval-avoiding-common-lisp-pitfalls]: http://127.0.0.1:15500/eval/eval-kFs-2026-11-02T21%3A30%3A15
[eval-clearing-asdf-fasl-cache]: http://127.0.0.1:15500/eval/eval-3Hb-2026-11-02T21%3A54%3A55
[eval-defining-clos-classes]: http://127.0.0.1:15500/eval/eval-Stw-2026-11-02T22%3A42%3A42
[eval-handling-json-in-common-lisp]: http://127.0.0.1:15500/eval/eval-cHc-2026-11-02T22%3A56%3A46
[eval-logging-with-log4cl]: http://127.0.0.1:15500/eval/eval-8O3-2026-11-02T23%3A34%3A07
[eval-testing-with-rove]: http://127.0.0.1:15500/eval/eval-43y-2026-11-03T00%3A20%3A19
[eval-using-common-lisp-repl]: http://127.0.0.1:15500/eval/eval-cLh-2026-11-03T01%3A12%3A11
[eval-lint-common-lisp]: http://127.0.0.1:15500/eval/eval-mpY-2026-11-03T01%3A27%3A19
[eval-writing-40ants-doc-documentation]: http://127.0.0.1:15500/eval/eval-jPi-2026-11-03T02%3A05%3A38
[eval-deploy-40ants-project]: http://127.0.0.1:15500/eval/eval-dBm-2026-11-03T03%3A12%3A37
[eval-nix-shell-playwright]: http://127.0.0.1:15500/eval/eval-fGo-2026-11-03T03%3A36%3A04
