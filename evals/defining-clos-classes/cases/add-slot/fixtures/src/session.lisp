(uiop:define-package #:demo/src/session
  (:use #:cl)
  (:export #:session #:make-session #:session-state #:session-timeout)
)
(in-package #:demo/src/session)
(defclass session () ((project-dir :initarg :project-dir :reader session-project-dir)
(state :initarg :state :initform :idle :accessor session-state)))
(defun make-session (project-dir &rest restargs &key state)
(declare (ignore state)) (apply #'make-instance 'session :project-dir project-dir restargs))
