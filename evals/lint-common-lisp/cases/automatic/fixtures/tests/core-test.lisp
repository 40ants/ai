(uiop:define-package #:demo-tests/core-test (:use #:cl) (:import-from #:rove #:deftest #:ok) (:import-from #:demo/src/core #:add))
(in-package #:demo-tests/core-test)
(deftest add (ok (= 12 (add 5 7))))
