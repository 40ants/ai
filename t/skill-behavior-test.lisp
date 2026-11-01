;;;; Good/bad calibration of each independent skill behavior assertion handler.
(uiop:define-package #:40ants-ai-evals-tests/skill-behavior-test
  (:use #:cl)
  (:import-from #:serapeum #:-> #:dict)
  (:import-from #:rove #:deftest #:ok #:testing)
  (:import-from #:40ants-ai-evals/util #:field #:true-p #:encode #:read-json #:root #:at)
  (:import-from #:40ants-ai-evals/checks #:validate-plan #:execute-plan #:make-context))
(in-package #:40ants-ai-evals-tests/skill-behavior-test)

(-> passes-p (string hash-table hash-table)
    boolean)
(defun passes-p (id sample params)
  (let* ((vars (dict "checkSystems"
                     (vector (dict "system" "40ants-ai-evals-skill-behavior-checks"
                                   "asd" "evals/checks/skill-behavior/40ants-ai-evals-skill-behavior-checks.asd"))
                     "checks" (vector (dict "check" id "params" params))))
         (plan (validate-plan vars))
         (results (execute-plan (make-context sample vars) plan)))
    (and (= 1 (length results)) (true-p (field (first results) "pass")))))

(-> evidence-sample (string hash-table)
    hash-table)
(defun evidence-sample (name data)
  (dict "files" (dict (format nil ".eval-evidence/~A.json" name) (encode data))))

(-> call (string string &optional t)
    hash-table)
(defun call (command result &optional (success 'yason:true))
  (dict "name" "exec_command" "arguments" (dict "cmd" command)
        "result" result "success" success))

(deftest exact-file-calibration
  (let ((params (dict "file" "note.txt" "text" (format nil "ready~%"))))
    (ok (passes-p "skill/exact-file" (dict "files" (dict "note.txt" (format nil "ready~%"))) params))
    (ok (not (passes-p "skill/exact-file" (dict "files" (dict "note.txt" "ready")) params)))
    (ok (not (passes-p "skill/exact-file" (dict "files" (dict)) params)))))

(deftest real-runtime-calibration
  (let ((params (dict "loadFiles" #("candidate.lisp") "systems" #()
                      "assertions" "(assert (= 6 (twice 3))) (assert (= -8 (twice -4)))")))
    (ok (passes-p "skill/lisp-runtime"
                  (dict "files" (dict "candidate.lisp" "(defun twice (value) (* 2 value))")) params))
    (ok (not (passes-p "skill/lisp-runtime"
                       (dict "files" (dict "candidate.lisp" "(defun twice (value) (+ 2 value))")) params)))
    (ok (not (passes-p "skill/lisp-runtime" (dict "files" (dict)) params)))))

(deftest completed-trace-calibration
  (let ((params (dict "requirements"
                      (vector (dict "pattern" "mallet.*core.lisp" "minimum" 2
                                    "forbiddenOutput" "WARNING:")))))
    (ok (passes-p "skill/tool-trace"
                  (dict "toolCalls" (vector (call "mallet core.lisp" "WARNING: unused")
                                             (call "mallet core.lisp" "Clean"))) params))
    (ok (not (passes-p "skill/tool-trace"
                       (dict "files" (dict "report.txt" "Ran mallet core.lisp twice; clean")) params)))
    (ok (not (passes-p "skill/tool-trace"
                       (dict "toolCalls" (vector (call "mallet core.lisp" "Clean")
                                                  (call "mallet core.lisp" "WARNING: unused"))) params)))
    (ok (not (passes-p "skill/tool-trace"
                       (dict "toolCalls" (vector (call "mallet core.lisp" "Clean")
                                                  (call "mallet core.lisp" "failed" 'yason:false))) params)))))

(deftest cache-calibration
  (let* ((before (dict "project/a.fasl" "old-a" "project/b.fasl" "old-b"
                       "foreign/a.fasl" "keep"))
         (data (dict "before" before "after" (dict "foreign/a.fasl" "keep")
                     "projectPaths" #("project/a.fasl" "project/b.fasl")
                     "foreignPaths" #("foreign/a.fasl"))))
    (ok (passes-p "skill/cache-state" (evidence-sample "cache" data) (dict)))
    (setf (gethash "after" data) (dict "project/b.fasl" "old-b" "foreign/a.fasl" "keep"))
    (ok (not (passes-p "skill/cache-state" (evidence-sample "cache" data) (dict))))
    (setf (gethash "after" data) (dict))
    (ok (not (passes-p "skill/cache-state" (evidence-sample "cache" data) (dict))))))

(deftest missing-cache-calibration
  (let ((data (dict "before" (dict "foreign/a.fasl" "keep")
                    "after" (dict "foreign/a.fasl" "keep")
                    "projectPaths" #("project/missing.fasl")
                    "foreignPaths" #("foreign/a.fasl")))
        (params (dict "missing" 'yason:true)))
    (ok (passes-p "skill/cache-state" (evidence-sample "cache" data) params))
    (setf (gethash "after" data) (dict "foreign/a.fasl" "changed"))
    (ok (not (passes-p "skill/cache-state" (evidence-sample "cache" data) params)))))

(-> fixture-sample (string hash-table)
    hash-table)
(defun fixture-sample (name state)
  (dict "files" (dict)
        "toolCalls" (vector (dict "name" (format nil "mcp__fixture__~A" name)
                                  "arguments" (dict "form" "fixture-operation")
                                  "success" 'yason:true
                                  "result" (dict "content"
                                                 (vector (dict "type" "text" "text"
                                                               (encode (dict "state" state)))))))))

(deftest persistent-repl-calibration
  (let* ((params (dict "expected" (dict "counter" 42 "value" 7)))
         (sample (fixture-sample "eval_lisp_form" (dict "counter" 42 "value" 7))))
    (ok (passes-p "skill/repl-state" sample params))
    (ok (not (passes-p "skill/repl-state"
                       (fixture-sample "eval_lisp_form" (dict "counter" 41 "value" 7)) params)))
    (let ((forged (evidence-sample "repl" (dict "counter" 42 "value" 7))))
      (setf (gethash "toolCalls" forged)
            (vector (dict "name" "mcp__fixture__eval_lisp_form"
                          "arguments" (dict "form" "(values)")
                          "result" "NIL" "success" 'yason:true)))
      (ok (not (passes-p "skill/repl-state" forged params))))
    (setf (gethash "toolCalls" sample)
          (concatenate 'vector (field sample "toolCalls")
                       (field (fixture-sample "eval_lisp_form" (dict "counter" 0 "value" 7))
                              "toolCalls")))
    (ok (not (passes-p "skill/repl-state" sample params)))))

(deftest deployment-calibration
  (let* ((protected (dict "config/service.env" "secret-hash" "data/state.sqlite" "data-hash"))
         (data (dict "initialCurrent" "releases/20261030-100000"
                     "current" "releases/20261101-100000"
                     "releases" #("20261030-100000" "20261101-100000")
                     "protectedBefore" protected "protectedAfter" protected
                     "events" (vector (dict "operation" "switch-current" "success" 'yason:true)
                                      (dict "operation" "health" "success" 'yason:true))))
         (params (dict "target" :null "maxReleases" 3 "changed" 'yason:true
                       "operations" #("switch-current" "health"))))
    (ok (passes-p "skill/deploy-state" (fixture-sample "remote_shell" data) params))
    (ok (not (passes-p "skill/deploy-state" (evidence-sample "deploy" data) params)))
    (let ((forged (evidence-sample "deploy" data)))
      (setf (gethash "toolCalls" forged)
            (vector (dict "name" "mcp__fixture__remote_shell" "arguments" (dict)
                          "result" "done" "success" 'yason:true)))
      (ok (not (passes-p "skill/deploy-state" forged params))))
    (setf (gethash "protectedAfter" data) (dict "config/service.env" "changed"))
    (ok (not (passes-p "skill/deploy-state" (fixture-sample "remote_shell" data) params)))
    (setf (gethash "protectedAfter" data) protected)
    (setf (gethash "events" data) (reverse (field data "events")))
    (ok (not (passes-p "skill/deploy-state" (fixture-sample "remote_shell" data) params)))
    (setf (gethash "current" data) "releases/deleted")
    (ok (not (passes-p "skill/deploy-state" (fixture-sample "remote_shell" data) params)))))

(deftest first-service-permissions-calibration
  (let* ((protected (dict "certificates" "keep"))
         (data (dict "initialCurrent" :null "current" "releases/20261101-100000"
                     "releases" #("20261101-100000")
                     "protectedBefore" protected
                     "protectedAfter" (dict "certificates" "keep" "config/service.env" "placeholder")
                     "serviceExists" 'yason:true "serviceUser" "demo"
                     "dataMode" "0700" "envMode" "0600" "events" #()))
         (params (dict "changed" 'yason:true
                       "expected" (dict "serviceExists" 'yason:true "serviceUser" "demo"
                                         "dataMode" "0700" "envMode" "0600"))))
    (ok (passes-p "skill/deploy-state" (fixture-sample "remote_shell" data) params))
    (setf (gethash "envMode" data) "0644")
    (ok (not (passes-p "skill/deploy-state" (fixture-sample "remote_shell" data) params)))
    (setf (gethash "envMode" data) "0600")
    (setf (gethash "serviceUser" data) "root")
    (ok (not (passes-p "skill/deploy-state" (fixture-sample "remote_shell" data) params)))))

(-> screenshot (integer integer)
    hash-table)
(defun screenshot (width height)
  (dict "kind" "png" "width" width "height" height "size" 4096
        "sha256" (make-string 64 :initial-element #\a)))

(deftest browser-artifact-calibration
  (let* ((artifacts (dict "test-shots/index-desktop.png" (screenshot 1440 900)
                          "test-shots/index-mobile.png" (screenshot 390 844)))
         (sample (dict "files" (dict "shell.nix" "{}" "run_smoke_test.sh" "script"
                                     "smoke_test.py" "browser test")
                       "artifacts" artifacts))
         (params (dict "pages" #("index"))))
    (ok (passes-p "skill/browser-artifacts" sample params))
    (remhash "test-shots/index-mobile.png" artifacts)
    (ok (not (passes-p "skill/browser-artifacts" sample params)))
    (setf (gethash "test-shots/index-mobile.png" artifacts) (screenshot 390 844))
    (setf (gethash "size" (field artifacts "test-shots/index-mobile.png")) 12)
    (ok (not (passes-p "skill/browser-artifacts" sample params)))
    (setf (gethash "artifacts" sample) (dict))
    (ok (not (passes-p "skill/browser-artifacts" sample params)))))

(deftest browser-missing-calibration
  (let* ((params (dict "report" "diagnostics.txt"))
         (sample (dict "files"
                       (dict "diagnostics.txt"
                             "The supplied browser executable is missing. Set PLAYWRIGHT_BROWSER_PATH to an installed local Chromium executable and rerun the existing helper; no download is needed.")
                       "toolCalls" (vector (call "./run_smoke_test.sh"
                                                 "BrowserType.launch: executable doesn't exist at .missing-browser/chromium"
                                                 'yason:false)))))
    (ok (passes-p "skill/browser-missing" sample params))
    (setf (gethash "success" (aref (field sample "toolCalls") 0)) 'yason:true)
    (ok (not (passes-p "skill/browser-missing" sample params)))
    (setf (gethash "success" (aref (field sample "toolCalls") 0)) 'yason:false)
    (setf (gethash "toolCalls" sample)
          (concatenate 'vector (field sample "toolCalls")
                       (vector (call "python3 -m playwright install chromium" "downloaded"))))
    (ok (not (passes-p "skill/browser-missing" sample params)))
    (setf (gethash "toolCalls" sample) #())
    (ok (not (passes-p "skill/browser-missing" sample params)))))

(deftest browser-http-and-marker-calibration
  (let* ((sample (dict "files" (dict "shell.nix" "# KEEP_CUSTOM"
                                      "run_smoke_test.sh" "script"
                                      "smoke_test.py" "page.goto('http://127.0.0.1'); assert message == 'HTTP fixture loaded'")
                       "artifacts" (dict "test-shots/server-desktop.png" (screenshot 1440 900)
                                         "test-shots/server-mobile.png" (screenshot 390 844))))
         (params (dict "pages" #("server") "http" 'yason:true "shellMarker" "KEEP_CUSTOM")))
    (ok (passes-p "skill/browser-artifacts" sample params))
    (setf (gethash "shell.nix" (field sample "files")) "custom marker lost")
    (ok (not (passes-p "skill/browser-artifacts" sample params)))
    (setf (gethash "shell.nix" (field sample "files")) "# KEEP_CUSTOM")
    (setf (gethash "smoke_test.py" (field sample "files")) "page.goto('file:///index.html')")
    (ok (not (passes-p "skill/browser-artifacts" sample params)))))

(deftest complete-suite-case-contracts
  (loop for suite in '("avoiding-common-lisp-pitfalls" "clearing-asdf-fasl-cache"
                       "defining-clos-classes" "deploy-40ants-project"
                       "handling-json-in-common-lisp" "lint-common-lisp"
                       "logging-with-log4cl" "nix-shell-playwright" "testing-with-rove"
                       "using-common-lisp-repl" "writing-40ants-doc-documentation") do
    (let* ((cases (read-json (at (root) (format nil "evals/~A/cases.json" suite))))
           (config (read-json (at (root) (format nil "evals/~A/promptfooconfig.json" suite))))
           (defaults (field config "defaultTest" "vars"))
           (ids (loop for test across cases collect (field test "vars" "id"))))
      (testing suite
        (ok (= 6 (length cases)))
        (ok (= 6 (length (remove-duplicates ids :test #'equal))))
        (ok (member "smoke" ids :test #'equal))
        (ok (= 1 (count "holdout" cases :test #'equal
                        :key (lambda (test) (field test "vars" "group")))))
        (ok (= 1 (count-if (lambda (test) (not (true-p (field test "vars" "shouldTrigger")))) cases)))
        (loop for test across cases for vars = (field test "vars") do
          (ok (equal suite (field vars "suite")))
          (ok (equal suite (field vars "skillName")))
          (ok (hash-table-p (field vars "fixtures")))
          (ok (hash-table-p (field vars "scenario")))
          (setf (gethash "checkSystems" vars) (field defaults "checkSystems"))
          (ok (validate-plan vars)))))))
