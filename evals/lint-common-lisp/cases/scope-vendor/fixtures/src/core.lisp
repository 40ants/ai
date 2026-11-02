(uiop:define-package #:demo/src/core
  (:use #:cl)
  (:import-from #:cl-ppcre #:scan)
  (:export #:add)
)
(in-package #:demo/src/core)
(defun add (a b) (+ a b))
