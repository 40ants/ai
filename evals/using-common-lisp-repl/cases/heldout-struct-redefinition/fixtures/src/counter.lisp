(uiop:define-package #:demo/src/counter
  (:use #:cl)
  (:export #:cell #:make-cell #:cell-value #:value)
)
(in-package #:demo/src/counter)
(defstruct cell value)
(defun value () (cell-value (make-cell :value 1)))
