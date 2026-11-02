# Adding checks without changing the core

The core `40ants-ai-evals` runs declared check plans. File rules live in
`40ants-ai-evals-common-checks`; Lisp rules live in
`40ants-ai-evals-common-lisp-checks`. Each rule has a stable ID and typed
parameters. Existing human-readable failure names, such as `type-signature`,
remain unchanged; `grading.json` also records the originating `checkId`.

## Declare a case's checks

`evals/writing-common-lisp/cases.json` now contains a `vars.checks` array:

```json
{
  "vars": {
    "file": "src/models/score.lisp",
    "checks": [
      {"profile": "common/contract"},
      {"profile": "common-lisp/source"},
      {
        "check": "source/max-line-length",
        "params": {"file": {"$var": "file"}, "limit": 80}
      }
    ]
  }
}
```

This example adds an 80-column check to the existing profiles. An explicit
`checks` array replaces the inherited array, so include the profiles you want
to keep. A string is shorthand for a check with no explicit parameters:
`"my/check"` means `{"check": "my/check"}`.

Parameters can be literal JSON values or references like `{"$var":"file"}`.
A missing variable is an error unless the reference includes a `default`:
`{"$var":"override","default":false}`. Each check's parameter schema is
strict: missing, unknown and incorrectly typed fields fail before model calls.
Supported types are `string`, `integer`, `number`, `boolean`, `object`, `array`,
`nullable-string`, `file` and `any`.

Use `when` or `unless` to name a case variable:

```json
{
  "check": "cl/return-type-layout",
  "unless": "override",
  "params": {
    "file": {"$var": "file"},
    "package": {"$var": "package"},
    "function": {"$var": "function"},
    "runtime": {"$var": "runtime"}
  }
}
```

Missing variables, null, false, zero and empty strings are false in conditions.
Parameter references for an inactive check are not resolved. Profiles are ordered
bundles of descriptors, registered by extensions. See `checks.lisp` in each
built-in check system for their definitions. Profile descriptors support
conditions but do not accept `params`; their checks bind case variables explicitly.

Inspect the available check IDs, schemas and defaults:

```bash
qlot exec ros roswell/ai-evals.ros checks
```

The command prints JSON and makes no model calls. The current default suite
loads 28 independently selectable checks.

## Implement an independent extension

Create `evals/checks/project/my-eval-checks.asd`:

```lisp
(asdf:defsystem "my-eval-checks"
  :class :package-inferred-system
  :license "Unlicense"
  :depends-on ("my-eval-checks/checks"))
```

Create `evals/checks/project/checks.lisp`:

```lisp
(uiop:define-package #:my-eval-checks/checks
  (:use #:cl)
  (:import-from #:serapeum #:-> #:dict)
  (:import-from #:40ants-ai-evals/util #:field)
  (:import-from #:40ants-ai-evals/checks
                #:register-check #:context-sample #:outcome))
(in-package #:my-eval-checks/checks)

(-> no-fixme (hash-table hash-table)
    hash-table)
(defun no-fixme (context params)
  (let ((text (field (context-sample context) "files" (field params "file"))))
    (outcome "no-fixme" (and (stringp text) (not (search "FIXME" text))))))

(register-check "project/no-fixme" 'no-fixme
                :parameters (dict "file" "string"))
```

Add this entry to `defaultTest.vars.checkSystems` in the suite's Promptfoo config,
alongside existing entries:

```json
{
  "system": "my-eval-checks",
  "asd": "evals/checks/project/my-eval-checks.asd"
}
```

Then add the rule to the appropriate case's `vars.checks`:

```json
{"check":"project/no-fixme","params":{"file":{"$var":"file"}}}
```

No core or built-in check module changes are needed. Keep production extensions
under `evals/checks/`: the runner snapshots this tree, and replay fingerprints
include its code. A third-party system installed by Qlot can omit `asd`; its
version must be fixed in `qlfile.lock`. Run `qlot install` after adding library
dependencies. ASDF extensions are trusted project code.

`t/fixtures/example-check/` is a runnable version of this example. Integration
tests invoke it in a separate Roswell process with both clean text and FIXME text.

## Handler and result contract

`register-check` takes a globally unique ID and a handler symbol. Its
`:parameters` object maps names to types; every declared parameter is required
unless `:defaults` supplies a value. Defaults can be overridden in a descriptor.
Re-registering the same handler supports reloads; a different handler using the
same ID is rejected. Namespace IDs to avoid collisions.

The `file` parameter type accepts a suite-relative path to an existing regular
file. Validation rejects missing files, absolute paths, parent traversal,
symlinks in any component and special files before any model call. Use
`40ants-ai-evals/case-resources:resolve-resource` with `context-vars` in your
handler to read the same snapshotted file. File parameters are included in the
case input fingerprint automatically.

Use `:optional-parameters '("inline" "file")` when parameters are alternatives.
Undeclared optional fields remain errors; absent optional fields are not added
to the parameter object. A validator can require exactly one alternative.
The runtime check uses `assertions` for legacy inline code and `assertionsFile`
for ordinary Lisp files; authored cases use the latter.

Fixture paths in `vars.fixtures` name directories relative to the suite. Store
inputs under `cases/CASE_ID/fixtures/`, alongside `assertions.lisp`; omit the
field for cases without starting files. Fixture directories support binary
files and preserve executable bits. `baseline-manifest` and `sample-manifest`
provide byte-oriented evidence to custom checks, and `restore-sample` restores
archived text and binary candidate files into a checking workspace. None of
these helpers follows symbolic links.

For domain constraints, supply `:validate 'validator-function`. The validator
receives the resolved parameter object and must return a true Lisp value or
signal an error. A false result rejects the plan before model execution. This
supports enums, ranges and other constraints without extending core type rules;
the built-in line-length check uses it to require a positive limit.

Handlers receive `(context parameters)`. `context-sample` provides files, final
answer, variant, usage and activation evidence; `context-vars` provides case
variables. Treat both objects as read-only. `cached` stores computed evidence
in the current sample only, including NIL values:

```lisp
(cached context (list :my-evidence filename)
        (lambda () (compute-evidence filename)))
```

Return `(outcome "failure-name" predicate)` or supply a string failure explanation
with `:reason`. The predicate uses Lisp truth values. A vector emits multiple
results; NIL emits none. A failed result contributes zero to the score; a passed
result contributes one. Skipped checks do not enter the denominator. The overall
score is the fraction of passed results, and overall pass requires every result
to pass. Empty output from all handlers is an error. Handler exceptions are
infrastructure errors, distinct from ordinary failed checks.

Named profiles use `(register-profile "project/profile" descriptors-vector)`.
They can include other profiles; cycles are rejected. Checks run in declaration
order and may share expensive evidence through `cached`. The Lisp rule pack
uses this to run the real reader and functional tests once per source/scenario,
while keeping each assertion independently selectable.

Source-inspection rules skip absent or empty source files. Keep the
`source/target-file` check (included in `common/contract`) so missing output is
reported as an ordinary failed assertion.

## Verify an addition

1. Add a passing and failing fixture for the new rule using Rove.
2. Run `qlot exec ros roswell/ai-evals.ros test`.
3. Regrade old outputs with `qlot exec ros roswell/ai-evals.ros replay RUN_ID`.
4. Run one matching model case, then the full suite when changing behavior.

Changing a check plan or implementation changes the suite hash. Establish a
matched baseline, or replay old and new skill outputs under the same current
rules before comparing. Replay writes `replay-lisp.json` and does not replace
original scores or modify Promptfoo's database.

Promptfoo still receives one `Contract` assertion. Individual check results and
their IDs are available in each sample's archived `grading.json`.
