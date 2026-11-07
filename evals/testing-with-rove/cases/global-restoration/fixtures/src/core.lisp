(uiop:define-package #:demo/src/core
  (:use #:cl)
  (:export #:*counter* #:with-temp-counter)
)
(in-package #:demo/src/core)
(global-vars:define-global-var *counter* 41)
