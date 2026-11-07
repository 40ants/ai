(asdf:defsystem "demo" :class :package-inferred-system :depends-on ("demo/src/core") :in-order-to ((asdf:test-op (asdf:test-op "demo-tests"))))
