;;;; Extension API: named checks, profiles, typed parameters and shared evidence.
(uiop:define-package #:40ants-ai-evals/src/checks
  (:use #:cl)
  (:import-from #:serapeum #:-> #:dict)
  (:import-from #:40ants-ai-evals/src/util
                #:field #:true-p #:bool #:root #:at #:safe-relative-p #:sequence-list
                #:json-equal-p)
  (:export #:register-check #:register-profile #:load-check-systems #:validate-plan
           #:execute-plan #:make-context #:context-sample #:context-vars #:cached
           #:outcome #:merge-vars #:describe-checks))
(in-package #:40ants-ai-evals/src/checks)

(defvar *checks* (dict))
(defvar *profiles* (dict))
(defvar *loaded-systems* (dict))

(-> merge-vars (t t)
    hash-table)
(defun merge-vars (defaults overrides)
  "Copy defaults then apply explicit object fields without mutating inputs."
  (let ((result (dict)))
    (dolist (object (list defaults overrides))
      (when (hash-table-p object)
        (maphash (lambda (key value) (setf (gethash key result) value)) object)))
    result))

(-> register-check (string symbol &key (:parameters hash-table) (:defaults hash-table)
                                    (:validate (or null symbol)))
    string)
(defun register-check (id handler &key (parameters (dict)) (defaults (dict)) validate)
  "Register HANDLER(context, parameters), with required typed parameters and defaults."
  (unless (and (plusp (length id)) (fboundp handler) (not (macro-function handler)))
    (error "Check ~A requires a defined function handler: ~A" id handler))
  (when (and validate (not (fboundp validate)))
    (error "Check ~A has an undefined parameter validator: ~A" id validate))
  (let ((old (gethash id *checks*)))
    (when (and old (not (eq handler (field old "handler"))))
      (error "Check ID collision ~A: ~A versus ~A" id (field old "handler") handler))
    (setf (gethash id *checks*)
          (dict "handler" handler "parameters" parameters "defaults" defaults
                "validate" validate))
    id))

(-> register-profile (string vector)
    string)
(defun register-profile (id specifications)
  "Register a reusable ordered plan, owned by the registering package."
  (let* ((owner (package-name *package*)) (old (gethash id *profiles*)))
    (when (and old (not (equal owner (field old "owner"))))
      (error "Profile ID collision ~A: ~A versus ~A" id (field old "owner") owner))
    (setf (gethash id *profiles*) (dict "owner" owner "checks" specifications))
    id))

(-> load-check-systems (t)
    t)
(defun load-check-systems (systems)
  "Load trusted ASDF extensions from explicit project paths or Qlot dependencies."
  (dolist (spec (sequence-list systems))
    (let ((name (field spec "system")) (asd (field spec "asd")))
      (unless (and (stringp name) (or (not asd) (stringp asd)))
        (error "Invalid check system declaration: ~S" spec))
      (let ((key (format nil "~A/~A/~A" (root) name asd)))
        (unless (gethash key *loaded-systems*)
          (let ((*standard-output* *error-output*) (*trace-output* *error-output*))
            (when asd
              (unless (safe-relative-p asd) (error "Invalid extension ASDF path: ~A" asd))
              (asdf:load-asd (at (root) asd)))
            (asdf:load-system name)
            (setf (gethash key *loaded-systems*) t)))))))

(-> truthy-p (t)
    boolean)
(defun truthy-p (value)
  (and value (not (member value '(:null yason:false)))
       (not (and (stringp value) (zerop (length value))))
       (not (and (numberp value) (zerop value)))))

(-> active-p (hash-table hash-table)
    boolean)
(defun active-p (spec vars)
  (let ((when (field spec "when")) (unless (field spec "unless")))
    (dolist (condition (list when unless))
      (unless (or (not condition) (stringp condition))
        (error "Check conditions must name case variables: ~S" condition)))
    (and (or (not when) (truthy-p (field vars when)))
         (or (not unless) (not (truthy-p (field vars unless)))))))

(-> resolve-value (t hash-table)
    t)
(defun resolve-value (value vars)
  (cond
    ((hash-table-p value)
     (multiple-value-bind (reference reference-p) (gethash "$var" value)
       (if reference-p
           (progn
             (unless (stringp reference) (error "Invalid variable reference: ~S" reference))
             (multiple-value-bind (found present-p) (gethash reference vars)
               (if present-p found
                   (multiple-value-bind (default default-p) (gethash "default" value)
                     (if default-p default (error "Missing case variable: ~A" reference))))))
           (let ((result (dict)))
             (maphash (lambda (key child)
                        (setf (gethash key result) (resolve-value child vars))) value)
             result))))
    ((and (vectorp value) (not (stringp value)))
     (map 'vector (lambda (child) (resolve-value child vars)) value))
    (t value)))

(-> parameter-valid-p (t string)
    boolean)
(defun parameter-valid-p (value type)
  (not (null
        (cond ((equal type "string") (stringp value))
              ((equal type "integer") (integerp value))
              ((equal type "number") (numberp value))
              ((equal type "boolean") (member value '(yason:true yason:false)))
              ((equal type "object") (hash-table-p value))
              ((equal type "array") (and (vectorp value) (not (stringp value))))
              ((equal type "nullable-string") (or (eq value :null) (stringp value)))
              ((equal type "any") t)
              (t (error "Unknown parameter type: ~A" type))))))

(-> checked-parameters (string hash-table hash-table hash-table)
    hash-table)
(defun checked-parameters (id definition spec vars)
  (let* ((raw (or (field spec "params") (dict)))
         (schema (field definition "parameters")))
    (unless (hash-table-p raw) (error "Parameters of ~A must be an object" id))
    (let ((params (merge-vars (field definition "defaults") (resolve-value raw vars))))
      (maphash (lambda (key value)
                 (let ((type (gethash key schema)))
                   (unless type (error "Unknown parameter ~A for ~A" key id))
                   (unless (parameter-valid-p value type)
                     (error "Parameter ~A of ~A must be ~A; got ~S" key id type value)))) params)
      (maphash (lambda (key type)
                 (declare (ignore type))
                 (unless (nth-value 1 (gethash key params))
                   (error "Missing parameter ~A for ~A" key id))) schema)
      (let ((validator (field definition "validate")))
        (when (and validator (not (funcall validator params)))
          (error "Invalid parameter values for check ~A: ~S" id params)))
      params)))

(-> expand-plan (t hash-table list)
    list)
(defun expand-plan (specifications vars stack)
  (loop for raw in (sequence-list specifications)
        for spec = (if (stringp raw) (dict "check" raw) raw) append
    (progn
      (unless (hash-table-p spec) (error "Invalid check descriptor: ~S" spec))
      (maphash (lambda (key value)
                 (declare (ignore value))
                 (unless (member key '("check" "profile" "params" "when" "unless")
                                  :test #'equal)
                   (error "Unknown check descriptor field: ~A" key))) spec)
      (let ((id (field spec "check")) (profile (field spec "profile")))
        (unless (and (or (stringp id) (stringp profile)) (not (and id profile)))
          (error "A descriptor needs exactly one check or profile: ~S" spec))
        (cond
          (profile
           (unless (gethash profile *profiles*) (error "Unknown check profile: ~A" profile))
           (when (member profile stack :test #'equal)
             (error "Recursive check profile: ~{~A~^ -> ~}" (reverse (cons profile stack))))
           (when (field spec "params")
             (error "Profile parameters are not supported: ~A" profile))
           (when (active-p spec vars)
             (expand-plan (field (gethash profile *profiles*) "checks") vars (cons profile stack))))
          (t
           (let ((definition (gethash id *checks*)))
             (unless definition (error "Unknown check: ~A" id))
             (when (active-p spec vars)
               (list (dict "check" id "params"
                           (checked-parameters id definition spec vars)))))))))))

(-> validate-plan (hash-table)
    list)
(defun validate-plan (vars)
  "Load extensions and resolve a typed plan before spending model calls."
  (load-check-systems (field vars "checkSystems"))
  (let ((checks (field vars "checks")))
    (unless (and (vectorp checks) (not (stringp checks)))
      (error "Test vars.checks must be an array: ~S" checks))
    (let ((plan (expand-plan checks vars nil)))
      (unless plan (error "Refusing an empty check plan: ~A" (field vars "id")))
      plan)))

(-> make-context (hash-table hash-table)
    hash-table)
(defun make-context (sample vars)
  "Create a per-sample extension context with an isolated evidence cache."
  (dict "sample" sample "vars" vars "cache" (make-hash-table :test 'equal)))

(-> context-sample (hash-table)
    hash-table)
(defun context-sample (context)
  "Return immutable-by-convention sample evidence for a check."
  (field context "sample"))

(-> context-vars (hash-table)
    hash-table)
(defun context-vars (context)
  "Return the test variables for a check."
  (field context "vars"))

(-> cached (hash-table t function)
    t)
(defun cached (context key compute)
  "Compute shared evidence once per sample, including a cached NIL result."
  (let ((cache (field context "cache")))
    (multiple-value-bind (value present-p) (gethash key cache)
      (if present-p value (setf (gethash key cache) (funcall compute))))))

(-> outcome (string t &key (:reason (or null string)))
    hash-table)
(defun outcome (name pass &key reason)
  "Return one boolean check result with an optional failure explanation."
  (let ((result (dict "name" name "pass" (bool pass))))
    (when (and reason (not pass)) (setf (gethash "reason" result) reason))
    result))

(-> execute-plan (hash-table list)
    list)
(defun execute-plan (context plan)
  "Execute independent handlers; NIL skips a check, a vector emits several results."
  (loop for spec in plan for id = (field spec "check") append
    (let* ((definition (gethash id *checks*))
           (value (funcall (field definition "handler") context (field spec "params")))
           (results (if (hash-table-p value) (list value) (sequence-list value))))
      (when (and value (not (hash-table-p value))
                 (not (and (vectorp value) (not (stringp value)))))
        (error "Check ~A returned an invalid result: ~S" id value))
      (dolist (result results)
        (unless (and (stringp (field result "name"))
                     (member (field result "pass") '(yason:true yason:false)))
          (error "Check ~A returned an invalid outcome: ~S" id result))
        (setf (gethash "checkId" result) id))
      results)))

(-> describe-checks ()
    hash-table)
(defun describe-checks ()
  "Return JSON-compatible schemas for the checks currently registered."
  (let ((result (dict)))
    (maphash (lambda (id definition)
               (setf (gethash id result)
                     (dict "parameters" (field definition "parameters")
                           "defaults" (field definition "defaults")))) *checks*)
    result))
