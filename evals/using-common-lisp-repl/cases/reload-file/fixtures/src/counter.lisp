(uiop:define-package #:demo/src/counter
  (:use #:cl)
  (:export #:value)
)
(in-package #:demo/src/counter)
(defun value () 1)
