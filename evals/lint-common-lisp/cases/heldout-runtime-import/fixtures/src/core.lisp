(uiop:define-package #:demo/src/core
  (:use #:cl)
  (:import-from #:serapeum #:dict)
  (:import-from #:cl-ppcre #:scan)
  (:export #:add)
)
(in-package #:demo/src/core)
(defun add (a b) (serapeum:dict "total" (+ a b)))
