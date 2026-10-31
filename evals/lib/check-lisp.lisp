;;;; Read actual Lisp forms and execute functional checks with real Serapeum.
(require :asdf)
(let ((*standard-output* (make-broadcast-stream)))
  (asdf:load-system "serapeum"))

(defun json-string (text)
  (write-char #\")
  (loop for char across text do
    (case char
      (#\" (write-string "\\\""))
      (#\\ (write-string "\\\\"))
      (#\Newline (write-string "\\n"))
      (#\Return (write-string "\\r"))
      (#\Tab (write-string "\\t"))
      (otherwise
       (if (< (char-code char) 32)
           (format t "\\u~4,'0X" (char-code char))
           (write-char char)))))
  (write-char #\"))

(defun emit-json (object)
  (cond
    ((null object) (write-string "null"))
    ((stringp object) (json-string object))
    ((symbolp object)
     (write-string "{\"s\":")
     (json-string (string-downcase (symbol-name object)))
     (write-string ",\"p\":")
     (if (symbol-package object)
         (json-string (package-name (symbol-package object)))
         (write-string "null"))
     (write-char #\}))
    ((or (listp object) (vectorp object))
     (write-char #\[)
     (loop for value across (coerce object 'vector)
           for first = t then nil do
       (unless first (write-char #\,))
       (emit-json value))
     (write-char #\]))
    ((numberp object) (princ object))
    ((characterp object) (json-string (string object)))
    (t (json-string (princ-to-string object)))))

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

(let* ((args (cdr sb-ext:*posix-argv*))
       (filename (first args))
       (package-name (second args))
       (test-name (third args))
       (forms nil) (signature-layouts nil) (read-error nil) (runtime-error nil))
  (handler-case (multiple-value-setq (forms signature-layouts) (read-source filename))
    (error (condition) (setf read-error (princ-to-string condition))))
  (unless read-error
    (handler-case (functional-check package-name test-name filename)
      (error (condition) (setf runtime-error (princ-to-string condition)))))
  (write-string "EVAL_JSON:")
  (write-string "{\"forms\":")
  (emit-json (coerce forms 'vector))
  (write-string ",\"signatureLayouts\":")
  (emit-json (coerce signature-layouts 'vector))
  (write-string ",\"readError\":") (emit-json read-error)
  (write-string ",\"runtimeError\":") (emit-json runtime-error)
  (write-string "}")
  (terpri))
