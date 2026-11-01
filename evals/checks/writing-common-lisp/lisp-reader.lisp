;;;; Reader and functional checks run only in a disposable child Lisp process.
(uiop:define-package #:40ants-ai-evals-common-lisp-checks/lisp-reader
  (:use #:cl)
  (:import-from #:serapeum #:-> #:dict)
  (:export #:inspect-source))
(in-package #:40ants-ai-evals-common-lisp-checks/lisp-reader)

(serapeum:-> next-form-start (string integer)
    (or null integer))
(defun next-form-start (source start)
  ;; Let the Lisp reader skip real comments, including nested #| ... |#.
  (with-input-from-string (stream source)
    (file-position stream start)
    (loop for char = (peek-char t stream nil nil) do
      (cond
        ((null char) (return nil))
        ((char= char #\;)
         (read-char stream)
         (funcall (get-macro-character #\;) stream #\;))
        ((char= char #\#)
         (read-char stream)
         (if (eql (peek-char nil stream nil nil) #\|)
             (progn
               (read-char stream)
               (funcall (get-dispatch-macro-character #\# #\|) stream #\| nil))
             (return (1- (file-position stream)))))
        (t (return (file-position stream)))))))

(serapeum:-> signature-layout-valid-p (list integer string)
    boolean)
(defun signature-layout-valid-p (form start source)
  (let ((*readtable* (copy-readtable nil)))
    (with-input-from-string (stream source)
      (file-position stream (1+ start))
      ;; Read the operator, function name and complete argument-type list.
      ;; Nested argument types cannot confuse the return-type boundary.
      (dotimes (index 3) (read-preserving-whitespace stream))
      (let* ((return-start (next-form-start source (file-position stream)))
             (line-start (and return-start
                              (1+ (or (position #\Newline source
                                                :end return-start :from-end t)
                                      -1)))))
        (and (= (length form) 4) return-start
             (string= (subseq source line-start return-start) "    "))))))

(serapeum:-> read-source (string)
    (values list list &optional))
(defun read-source (filename)
  (let* ((*read-eval* nil) (*package* (find-package :cl-user))
         (*readtable* (copy-readtable nil))
         (source (uiop:read-file-string filename))
         (forms nil) (list-starts nil) (signature-layouts nil)
         (list-reader (get-macro-character #\()))
    ;; Capture actual list locations, not signature-looking text in comments or
    ;; strings. String streams keep offsets correct for non-ASCII source too.
    (set-macro-character #\(
      (lambda (stream char)
        (let* ((start (1- (file-position stream)))
               (form (funcall list-reader stream char)))
          (push (cons form start) list-starts)
          form)))
    (with-input-from-string (stream source)
      (loop for form = (read stream nil :end) until (eq form :end) do
        (push form forms)
        (when (and (consp form) (eq (car form) 'serapeum:->))
          (push (if (signature-layout-valid-p
                     form (cdr (assoc form list-starts :test #'eq)) source)
                    1 0)
                signature-layouts))
        (when (consp form)
          (cond
            ((member (car form) '(uiop:define-package cl:defpackage))
             ;; Apply only package declarations so local nicknames resolve for
             ;; subsequent READs. Arbitrary forms are not evaluated here.
             (eval form))
            ((eq (car form) 'cl:in-package)
             (setf *package* (find-package (second form))))))))
    (values (nreverse forms) (nreverse signature-layouts))))

(serapeum:-> functional-check (string string string)
    t)
(defun functional-check (package-name test-name filename)
  (let ((*standard-output* (make-broadcast-stream)))
    (load filename :verbose nil :print nil))
  (let ((package (find-package (string-upcase package-name))))
    (flet ((fn (name) (symbol-function (find-symbol name package))))
      (cond
        ((string= test-name "add-score")
         (assert (= 12 (funcall (fn "ADD-SCORE") 5 7)))
         (assert (= -2 (funcall (fn "ADD-SCORE") -4 2))))
        ((string= test-name "sum-even")
         (assert (= 0 (funcall (fn "SUM-EVEN") nil)))
         (assert (= 8 (funcall (fn "SUM-EVEN") '(1 2 3 4 -2 4 -1)))))
        ((string= test-name "status-code")
         (assert (= 201 (funcall (fn "STATUS-CODE") :new)))
         (assert (= 200 (funcall (fn "STATUS-CODE") :ok)))
         (assert (= 404 (funcall (fn "STATUS-CODE") :missing)))
         (assert (handler-case (progn (funcall (fn "STATUS-CODE") :other) nil)
                   (error () t))))
        ((string= test-name "ensure-positive")
         (assert (= 4 (funcall (fn "ENSURE-POSITIVE") 4)))
         (assert (handler-case (progn (funcall (fn "ENSURE-POSITIVE") -7) nil)
                   (error (condition) (search "-7" (princ-to-string condition))))))
        ((string= test-name "first-value")
         (assert (equal '(1 2) (funcall (fn "FIRST-VALUE") '(1 2) :ignored))))
        ((string= test-name "ready-p")
         (assert (funcall (fn "READY-P") :ready))
         (assert (not (funcall (fn "READY-P") :other)))
         (assert (not (funcall (fn "READY-P") nil))))
        ((string= test-name "hooks")
         (let ((seen nil)
               (hook-symbol (find-symbol "*AFTER-SAVE-HOOKS*" package)))
           (setf (symbol-value hook-symbol)
                 (list (lambda (object) (push (list :first object) seen))
                       42
                       (lambda (object) (push (list :second object) seen))))
           (funcall (fn "RUN-AFTER-SAVE-HOOKS") :object)
           (assert (equal (reverse seen) '((:first :object) (:second :object))))))
        (t (error "Unknown functional check: ~A" test-name))))))

(serapeum:-> form-json (t)
    t)
(defun form-json (object)
  (cond
    ((null object) :null)
    ((stringp object) object)
    ((symbolp object)
     (dict "s" (string-downcase (symbol-name object))
           "p" (if (symbol-package object) (package-name (symbol-package object)) :null)))
    ((or (listp object) (vectorp object)) (map 'vector #'form-json object))
    ((numberp object) object)
    ((characterp object) (string object))
    (t (princ-to-string object))))

(serapeum:-> inspect-source (string string string)
    hash-table)
(defun inspect-source (filename package-name test-name)
  "Read actual forms and run the named functional check in this child image."
  (let ((forms nil) (layouts nil) (read-error :null) (runtime-error :null))
    (handler-case (multiple-value-setq (forms layouts) (read-source filename))
      (error (condition) (setf read-error (princ-to-string condition))))
    (when (eq read-error :null)
      (handler-case (functional-check package-name test-name filename)
        (error (condition) (setf runtime-error (princ-to-string condition)))))
    (dict "forms" (map 'vector #'form-json forms)
          "signatureLayouts" (coerce layouts 'vector)
          "readError" read-error "runtimeError" runtime-error)))
