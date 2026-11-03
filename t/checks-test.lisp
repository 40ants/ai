;;;; Public extension API, independent of any Common Lisp source conventions.
(uiop:define-package #:40ants-ai-evals-tests/checks-test
  (:use #:cl)
  (:import-from #:serapeum #:-> #:dict)
  (:import-from #:rove #:deftest #:testing #:ok #:signals)
  (:import-from #:40ants-ai-evals/util #:field #:true-p #:decode #:encode #:root #:at
                #:run-command #:temporary-directory #:remove-directory #:copy-directory
                #:write-json #:write-text)
  (:import-from #:40ants-ai-evals/checks
                #:register-check #:register-profile #:validate-plan #:execute-plan
                #:make-context #:cached #:outcome)
  (:import-from #:40ants-ai-evals/grading/contracts #:grade))
(in-package #:40ants-ai-evals-tests/checks-test)

(defvar *computations* 0)

(-> cache-first (hash-table hash-table)
    hash-table)
(defun cache-first (context params)
  (declare (ignore params))
  (cached context :shared (lambda () (incf *computations*) nil))
  (outcome "first" t))

(-> cache-second (hash-table hash-table)
    hash-table)
(defun cache-second (context params)
  (declare (ignore params))
  (cached context :shared (lambda () (incf *computations*) nil))
  (outcome "second" t))

(-> typed-check (hash-table hash-table)
    hash-table)
(defun typed-check (context params)
  (declare (ignore context))
  (outcome "typed" (plusp (length (field params "file")))))

(-> skip-check (hash-table hash-table)
    null)
(defun skip-check (context params)
  (declare (ignore context params))
  nil)

(register-check "tests/cache-first" 'cache-first)
(register-check "tests/cache-second" 'cache-second)
(register-check "tests/typed" 'typed-check :parameters (dict "file" "string"))
(register-check "tests/skip" 'skip-check)
(register-profile "tests/recursive-a" (vector (dict "profile" "tests/recursive-b")))
(register-profile "tests/recursive-b" (vector (dict "profile" "tests/recursive-a")))

(deftest schema-validation
  (dolist (checks
           (list #() #("unknown/check") #("tests/typed")
                 (vector (dict "check" "tests/typed" "params" (dict "file" 42)))
                 (vector (dict "check" "tests/typed" "params" (dict "file" "x" "typo" 1)))
                 (vector (dict "check" "source/max-line-length"
                               "params" (dict "file" "x" "limit" 0)))
                 (vector (dict "check" "tests/typed"
                               "params" (dict "file" (dict "$var" "missing"))))
                 (vector (dict "profile" "tests/recursive-a"))))
    (ok (signals (validate-plan (dict "checks" checks)))))
  (ok (signals (register-check "tests/typed" 'cache-first))))

(deftest missing-handlers-and-empty-outcomes
  (ok (signals (register-check "tests/missing" 'undefined-handler)))
  (ok (signals
        (40ants-ai-evals/grading/contracts:grade
         (dict "files" (dict) "skillRead" 'yason:false)
         (dict "checks" #("tests/skip"))))))

(deftest profile-conditions-and-caching
  (let* ((*computations* 0)
         (vars (dict "checks" (vector "tests/cache-first" "tests/cache-second"
                                       (dict "check" "tests/typed" "when" "disabled"))))
         (plan (validate-plan vars))
         (context (make-context (dict) vars)))
    (ok (= 2 (length plan)))
    (ok (= 2 (length (execute-plan context plan))))
    (ok (= 1 *computations*)))
  (let* ((vars (dict "path" "example.txt"
                     "checks" (vector (dict "check" "tests/typed"
                                             "params" (dict "file" (dict "$var" "path"))))))
         (plan (validate-plan vars)))
    (ok (equal "example.txt" (field (first plan) "params" "file")))))

(deftest independent-asdf-extension
  (testing "a new ASDF check works through the CLI without core changes"
    (loop for content in '("Ready for review" "FIXME: unfinished")
          for expected in '(t nil) do
      (let* ((vars (dict "checkSystems"
                        (vector
                         (dict "system" "40ants-ai-evals-example-check"
                               "asd"
                               "t/fixtures/example-check/40ants-ai-evals-example-check.asd"))
                        "checks" (vector (dict "check" "example/no-fixme"
                                               "params" (dict "file" "review.txt")))))
             (request (dict "sample" (dict "files" (dict "review.txt" content)
                                            "skillRead" 'yason:false)
                            "vars" vars))
             (stdout (run-command
                      (list "ros" "-Q" "--" (namestring (at (root) "roswell/ai-evals.ros"))
                            "grade") :input (encode request)))
             (result (decode stdout)))
        (ok (eq expected (true-p (field result "pass"))))
        (ok (equal "example/no-fixme" (field (aref (field result "checks") 0) "checkId")))))))

(deftest preflight-precedes-provider
  (let ((scratch (temporary-directory "check-preflight")))
    (unwind-protect
         (progn
           (copy-directory (at (root) "src/") (at scratch "src/"))
           (copy-directory (at (root) "roswell/") (at scratch "roswell/"))
           (loop for asd-file in (directory (at (root) "*.asd")) do
             (uiop:copy-file asd-file (at scratch (file-namestring asd-file))))
           (ensure-directories-exist (at scratch "docs/changelog.lisp"))
           (uiop:copy-file (at (root) "docs/changelog.lisp")
                           (at scratch "docs/changelog.lisp"))
           (write-json (at scratch "evals/writing-common-lisp/promptfooconfig.json")
                       (dict "defaultTest" (dict "vars" (dict))))
           (write-json (at scratch "evals/writing-common-lisp/cases.json")
                       (vector (dict "description" "invalid check"
                                     "vars" (dict "id" "invalid" "group" "development"
                                                  "checks" #("preflight/missing")))))
           (let ((fake (at scratch "bin/promptfoo"))
                 (marker (at scratch "provider-was-called")))
             (write-text fake
                         (format nil "#!/bin/sh~%: > \"$PREFLIGHT_MODEL_MARKER\"~%exit 1~%"))
             (run-command (list "chmod" "+x" (namestring fake)))
             (multiple-value-bind (stdout stderr status)
                 (run-command
                  (list "env" (format nil "PREFLIGHT_MODEL_MARKER=~A" marker)
                        (format nil "SKILL_EVAL_TOOL_PATH=~A:~A" (at scratch "bin/")
                                (uiop:getenv "SKILL_EVAL_TOOL_PATH"))
                        "qlot" "exec" "ros" "-Q" "--"
                        (namestring (at scratch "roswell/ai-evals.ros")) "run")
                  ;; Runtime isolation follows cwd: launch the cloned project
                  ;; from its own workspace, using the supported Qlot entry point.
                  :directory scratch :allow-failure t)
               (declare (ignore stdout))
               (ok (= 2 status))
               (ok (search "Unknown check: preflight/missing" stderr))
               (ok (not (probe-file marker)))
               (ok (not (probe-file (at scratch ".evals/runs/")))))))
      (remove-directory scratch))))
