(uiop:define-package #:demo/base
  (:use #:cl)
  (:export #:item #:label)
)
(in-package #:demo/base)
(defclass item () ())
(defgeneric label (item))
(defmethod label ((item item)) 42)
