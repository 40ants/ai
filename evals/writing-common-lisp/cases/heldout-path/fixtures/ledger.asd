;;;; Existing project scaffold supplied by the evaluation fixture.
(asdf:defsystem "ledger"
  :class :package-inferred-system
  :depends-on ("ledger/src/domain/account/balance"))
