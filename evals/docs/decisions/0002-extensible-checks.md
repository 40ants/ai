# ADR 0002: Declarative check plans and independent ASDF extensions

Date: 2026-11-01

Status: Accepted.

## Context

A monolithic grader couples every new assertion to the core harness. Test cases
should declare the checks they need, and projects should implement new checks
without changing `40ants-ai-evals`.

## Decision

The core provides a registry, typed parameter validation, profile expansion,
per-sample evidence caching and result aggregation. Checks are ordinary Common
Lisp functions registered by independent ASDF systems. Suite configuration names
the systems to load; case variables contain an ordered JSON `checks` array.

Descriptors select a `check` with `params`, or a reusable `profile`. `$var`
references bind parameters to case variables, with explicit optional defaults.
`when` and `unless` select checks using case variables. Profiles cannot recurse.
Unknown names, missing parameters and type errors fail preflight before model
execution. Handlers return one outcome, a vector of outcomes, or NIL to skip.
A plan that produces no outcomes fails as an infrastructure/configuration error.

`40ants-ai-evals-common-checks` supplies file and skill-activation checks;
`40ants-ai-evals-common-lisp-checks` supplies reader, runtime and Lisp convention
checks. The core contains no Common Lisp source convention rules. A shared
context cache lets independent Lisp checks reuse one isolated reader/runtime
process for the same source, package and runtime scenario.

Production extension source lives under `evals/checks/`, so run snapshots and
grader fingerprints include it. Alternatively, a named ASDF extension can be
installed as a Qlot-pinned dependency. Historical runs retain their original
results; replay applies the current declared defaults to archived variables and
writes a separate report identifying the current grader and extensions.

## Verification

The test fixture `tests/fixtures/example-check/` defines a separate ASDF system
and registers `example/no-fixme`. Integration tests load it through a case's
`checkSystems`, execute it through the Roswell CLI and verify passing and failing
outputs. Adding it requires no changes to the core or built-in check systems.

Calibration and archived-output replays check that the registered built-in rules
retain the previous grader's scores and failure reasons.

See [Extending checks](../extending-checks.md) for the JSON format and extension API.
