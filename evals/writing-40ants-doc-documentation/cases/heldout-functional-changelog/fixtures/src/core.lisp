(uiop:define-package #:demo/src/core
  (:use #:cl)
  (:export #:add)
)
(in-package #:demo/src/core)
(defun add (a b &optional (c 0)) "Add two or three numbers." (+ a b c))
