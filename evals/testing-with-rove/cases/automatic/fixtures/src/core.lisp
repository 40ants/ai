(uiop:define-package #:demo/src/core
  (:use #:cl)
  (:export #:invalid-count #:positive-count)
)
(in-package #:demo/src/core)
(define-condition invalid-count (error) ())
(defun positive-count (n) (if (plusp n) n (error 'invalid-count)))
