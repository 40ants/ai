(uiop:define-package #:demo/src/core
  (:use #:cl)
  (:export #:add)
)
(in-package #:demo/src/core)
(defun add (a b) "Add two numbers." (+ a b))
