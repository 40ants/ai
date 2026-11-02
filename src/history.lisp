;;;; Read old and new exports without modifying Promptfoo's database.
(uiop:define-package #:40ants-ai-evals/history
  (:use #:cl)
  (:import-from #:serapeum #:-> #:dict)
  (:import-from #:40ants-ai-evals/util
                #:field #:true-p #:bool #:decode #:read-json #:write-json
                #:sequence-list #:json-equal-p #:root #:at)
  (:export #:histories #:find-run #:make-summary #:summarize #:print-summary
           #:compare-runs #:print-history))
(in-package #:40ants-ai-evals/history)

(-> present (t)
    t)
(defun present (value)
  (unless (eq value :null) value))

(-> run-suite (hash-table)
    string)
(defun run-suite (run)
  "Legacy archives contain only the original Common Lisp suite."
  (or (present (field run "suite")) "writing-common-lisp"))

(-> split-provider-label (t)
    (values t t))
(defun split-provider-label (label)
  (if (stringp label)
      (let ((parts (loop for agent in '("codex" "opencode" "codex-cli")
                         for prefix = (concatenate 'string agent ":")
                         when (and (<= (length prefix) (length label))
                                   (string= prefix label :end2 (length prefix)))
                           return (list (if (equal agent "codex-cli") "codex" agent)
                                        (subseq label (length prefix))))))
        (if parts
            (values (first parts) (second parts))
            (values "codex" label)))
      (values "codex" label)))

(-> row-agent-variant (hash-table t)
    (values string t))
(defun row-agent-variant (result sample)
  (multiple-value-bind (provider-agent provider-variant)
      (split-provider-label (or (field result "provider" "label")
                                (field result "provider" "id")))
    (values (or (present (field sample "agent")) provider-agent "codex")
            (or (present (field sample "variant")) provider-variant :null))))

(-> summary-row-agent-variant (hash-table)
    (values string t))
(defun summary-row-agent-variant (row)
  "Read legacy summary rows, inferring Codex for rows without agent metadata."
  (multiple-value-bind (provider-agent provider-variant)
      (split-provider-label (field row "variant"))
    (values (or (present (field row "agent")) provider-agent "codex")
            (if (present (field row "agent"))
                (field row "variant")
                provider-variant))))

(-> median (list)
    t)
(defun median (values)
  (let* ((sorted (sort (remove-if-not #'numberp (copy-list values)) #'<))
         (count (length sorted)) (middle (floor count 2)))
    (cond ((zerop count) :null)
          ((oddp count) (nth middle sorted))
          (t (float (/ (+ (nth (1- middle) sorted) (nth middle sorted)) 2) 1d0)))))

(-> histories (&optional t)
    list)
(defun histories (&optional (runs-root (at (root) ".evals/runs/")))
  "Read accumulated summaries in run ID order, including pre-migration runs."
  (when (uiop:directory-exists-p runs-root)
    (loop for dir in (sort (uiop:subdirectories runs-root) #'string< :key #'namestring)
          for file = (at dir "summary.json")
          when (probe-file file) collect (read-json file))))

(-> find-run (string &rest t)
    t)
(defun find-run (id &rest options)
  "Resolve IDs, labels and relative selectors, optionally restricted with :SUITE.
An optional positional history list preserves the original reader API. Exact IDs
remain selectable across suites so comparison can report a clear identity error."
  (let* ((all (if (and options (not (keywordp (first options))))
                  (pop options) (histories)))
         (suite (getf options :suite))
         (selected (if suite
                       (remove-if-not (lambda (run) (equal suite (run-suite run))) all)
                       all)))
    (cond ((equal id "latest") (car (last selected)))
          ((equal id "previous")
           (when (> (length selected) 1) (nth (- (length selected) 2) selected)))
          (t (or (find id all :key (lambda (run) (field run "id")) :test #'equal)
                 (let ((labelled (remove-if-not
                                  (lambda (run) (equal id (field run "label"))) selected)))
                   (when (> (length labelled) 1)
                     (error "Ambiguous label ~A; use an exact run ID" id))
                   (first labelled)))))))

(-> result-row (hash-table &optional hash-table)
    hash-table)
(defun result-row (result &optional profiles)
  (let* ((response (field result "response"))
         (sample (or (present (field response "metadata" "skillEval"))
                      (handler-case
                          (if (stringp (field response "output"))
                              (decode (field response "output")) (field response "output"))
                        (error () nil))))
         (usage (field sample "usage"))
         (tokens (cond ((numberp (field usage "total_tokens"))
                        (field usage "total_tokens"))
                       ((and (numberp (field usage "input_tokens"))
                             (numberp (field usage "output_tokens")))
                        (+ (field usage "input_tokens") (field usage "output_tokens")))
                       ((not (hash-table-p usage))
                        (or (present (field response "tokenUsage" "total")) :null))
                       (t :null)))
         (cached-tokens (if (numberp (field usage "cached_input_tokens"))
                            (field usage "cached_input_tokens") :null))
         (infra (present (field sample "infrastructureError")))
         (provider-error (present (field response "error"))))
    (multiple-value-bind (agent variant) (row-agent-variant result sample)
      (dict "case" (or (field result "testCase" "vars" "id") (field result "vars" "id") :null)
          "agent" agent
          "profile" (or (present (field sample "profile"))
                        (present (field profiles agent)) :null)
          "variant" variant
          "pass" (bool (true-p (field result "success")))
          "score" (or (field result "score") :null)
          "error" (if (or infra (eql 2 (field result "failureReason")) provider-error)
                      (or infra (present (field result "error")) provider-error
                          "Provider/grader error") :null)
          "reason" (or (field result "gradingResult" "reason") :null)
          "tokens" tokens
          "cachedInputTokens" cached-tokens
          "durationMs" (or (present (field sample "durationMs")) (field result "latencyMs") :null)
          "commands" (or (field sample "commandCount") :null)
          "skillRead" (or (field sample "skillRead") :null)
          "trace" (or (field sample "trace") :null)))))

(-> error-p (hash-table)
    boolean)
(defun error-p (row)
  (not (member (field row "error") '(nil :null))))

(-> variant-statistics (list)
    hash-table)
(defun variant-statistics (rows)
  (dict "total" (length rows)
        "passed" (count-if (lambda (row) (true-p (field row "pass"))) rows)
        "failed" (count-if (lambda (row)
                              (and (not (true-p (field row "pass"))) (not (error-p row)))) rows)
        "errors" (count-if #'error-p rows)
        "medianTokens" (median (mapcar (lambda (row) (field row "tokens")) rows))
        "medianDurationMs" (median (mapcar (lambda (row) (field row "durationMs")) rows))
        "medianCommands" (median (mapcar (lambda (row) (field row "commands")) rows))))

(-> make-summary (hash-table t integer &optional t)
    hash-table)
(defun make-summary (manifest exported status &optional (signal :null))
  "Build a summary from either supported Promptfoo export shape."
  (let* ((body (field exported "results"))
         (raw (sequence-list (if (hash-table-p body) (field body "results") body)))
         (profiles (or (field manifest "profiles") (dict)))
         (rows (mapcar (lambda (result) (result-row result profiles)) raw))
         (cases (sequence-list (field manifest "cases")))
         (variants (sequence-list (field manifest "variants")))
         (agents (or (sequence-list (field manifest "agents")) (list "codex")))
         (repeat (field manifest "repeat"))
         (expected (* (length cases) repeat (length variants) (length agents)))
         (stats (dict))
         (agent-stats (dict))
         (summary (dict)))
    (dolist (agent agents)
      (let ((per-variant (dict)))
        (dolist (variant variants)
          (setf (gethash variant per-variant)
                (variant-statistics
                 (remove-if-not (lambda (row)
                                  (and (equal agent (field row "agent"))
                                       (equal variant (field row "variant")))) rows))))
        (setf (gethash agent agent-stats) per-variant)))
    ;; Keep the original variant map as the Codex view for existing consumers.
    (dolist (variant variants)
      (setf (gethash variant stats)
            (or (and (member "codex" agents :test #'equal)
                     (field agent-stats "codex" variant))
                (field agent-stats (first agents) variant)
                (variant-statistics nil))))
    (dolist (key '("id" "label" "started" "skillHash" "suiteHash" "model" "effort"
                   "group" "cases" "repeat" "tools" "environment"
                   "environmentVersions" "environmentFingerprint" "fixturesHash" "inputsHash"))
      (setf (gethash key summary) (field manifest key)))
    (setf (gethash "suite" summary) (run-suite manifest)
          (gethash "skillName" summary) (or (present (field manifest "skillName"))
                                           "writing-common-lisp")
          (gethash "processStatus" summary) status
          (gethash "processSignal" summary) signal
          (gethash "agents" summary) (coerce agents 'vector)
          (gethash "profiles" summary) profiles
          (gethash "expected" summary) expected
          (gethash "observed" summary) (length rows)
          (gethash "coverageComplete" summary)
          (bool (and (plusp expected) (= expected (length rows))
                     (every (lambda (case)
                              (every (lambda (variant)
                                       (every (lambda (agent)
                                                (= repeat
                                                   (count-if (lambda (row)
                                                               (and (equal case (field row "case"))
                                                                    (equal variant (field row "variant"))
                                                                    (equal agent (field row "agent"))))
                                                             rows))) agents)) variants)) cases)))
          (gethash "variants" summary) stats
          (gethash "agentVariants" summary) agent-stats
          (gethash "rows" summary) (coerce rows 'vector)
          (gethash "costUsd" summary) :null)
    summary))

(-> summarize (t hash-table integer)
    hash-table)
(defun summarize (run-dir manifest status)
  "Write a summary beside the original export; leave the database untouched."
  (let* ((file (at run-dir "results.json"))
         (summary (make-summary manifest (when (probe-file file) (read-json file)) status)))
    (write-json (at run-dir "summary.json") summary)
    summary))

(-> print-summary (hash-table)
    t)
(defun print-summary (summary)
  "Print scores and failures with artifact location."
  (format t "~%~A (~A) [~A]~%" (field summary "id") (field summary "label")
          (run-suite summary))
  (if (hash-table-p (field summary "agentVariants"))
      (maphash (lambda (agent variants)
                 (maphash (lambda (variant stats)
                            (format t "~A:~A: ~D/~D passed; ~D assertion failures; ~D infrastructure errors~%"
                                    agent variant (field stats "passed") (field stats "total")
                                    (field stats "failed") (field stats "errors")))
                          variants))
               (field summary "agentVariants"))
      (maphash (lambda (variant stats)
                 (format t "~A: ~D/~D passed; ~D assertion failures; ~D infrastructure errors~%"
                         variant (field stats "passed") (field stats "total")
                         (field stats "failed") (field stats "errors")))
               (field summary "variants")))
  (unless (true-p (field summary "coverageComplete"))
    (format t "INCOMPLETE COVERAGE: ~D/~D~%" (field summary "observed") (field summary "expected")))
  (loop for row across (field summary "rows") unless (true-p (field row "pass")) do
    (format t "~A [~A]: ~A~%" (field row "case")
            (if (> (length (sequence-list (field summary "agents"))) 1)
                (format nil "~A:~A" (field row "agent") (field row "variant"))
                (field row "variant"))
            (if (error-p row) (field row "error") (field row "reason"))))
  (format t "Artifacts: ~A~%" (at (root) (format nil ".evals/runs/~A/" (field summary "id")))))

(-> summary-row-agent-variant-agent (hash-table)
    string)
(defun summary-row-agent-variant-agent (row)
  (nth-value 0 (summary-row-agent-variant row)))

(-> run-agents (hash-table)
    list)
(defun run-agents (run)
  "Return configured or observed agents, defaulting legacy runs to Codex."
  (let* ((profiles (field run "profiles"))
         (profile-agents (when (hash-table-p profiles)
                           (loop for agent being the hash-keys of profiles collect agent)))
         (row-agents (mapcar #'summary-row-agent-variant-agent
                             (sequence-list (field run "rows"))))
         (agents (remove-duplicates
                  (append (sequence-list (field run "agents")) profile-agents row-agents)
                  :test #'equal :from-end t)))
    (or agents (list "codex"))))

(-> run-has-agent-p (hash-table string)
    boolean)
(defun run-has-agent-p (run agent)
  (not (null (member agent (run-agents run) :test #'equal))))

(-> print-history-runs (list t &optional t)
    t)
(defun print-history-runs (runs agent &optional suite)
  (when (and agent (not (member agent '("codex" "opencode") :test #'equal)))
    (error "Unknown agent ~A; supported agents are codex and opencode" agent))
  (dolist (run runs)
    (when (and (or (null suite) (equal suite (run-suite run)))
               (or (null agent) (run-has-agent-p run agent)))
      (let* ((rows (remove-if-not (lambda (row)
                                    (or (null agent)
                                        (equal agent (summary-row-agent-variant-agent row))))
                                  (sequence-list (field run "rows"))))
             (model (if agent
                        (or (field run "profiles" agent "model")
                            (field run "model") "unknown")
                        (field run "model")))
             (expected (if agent
                           (floor (field run "expected")
                                  (max 1 (length (sequence-list (field run "agents")))))
                           (field run "expected"))))
        (format t "~A  ~A  ~A  ~D/~D passed; coverage ~D/~D [~A; suite=~A]~%"
                (field run "id") (field run "label") model
                (count-if (lambda (row) (true-p (field row "pass"))) rows)
                (length rows) (length rows) expected (or agent "all") (run-suite run))))))

(-> print-history (&key (:agent t) (:suite t))
    t)
(defun print-history (&key agent suite)
  "List accumulated runs, optionally selecting SUITE and counting AGENT only."
  (print-history-runs (histories) agent suite))

(-> case-ratio (hash-table string string string)
    string)
(defun case-ratio (run case variant agent)
  (let ((rows (remove-if-not (lambda (row)
                               (multiple-value-bind (row-agent row-variant)
                                   (summary-row-agent-variant row)
                                 (and (equal case (field row "case"))
                                      (equal variant row-variant)
                                      (equal agent row-agent))))
                             (sequence-list (field run "rows")))))
    (format nil "~D/~D" (count-if (lambda (row) (true-p (field row "pass"))) rows) (length rows))))

(-> compare-runs (t t &key (:allow-mismatch t) (:agent t)
                    (:before-agent t) (:after-agent t) (:suite t))
    t)
(defun compare-runs (before after &key allow-mismatch agent before-agent after-agent suite)
  "Compare runs for AGENT, or select each side with BEFORE-AGENT and AFTER-AGENT.
Different agent selectors produce an agent/model comparison, not a skill regression.
ALLOW-MISMATCH prints fingerprint or same-agent profile differences instead of rejecting them.
Different suite identities are always rejected; SUITE restricts both selected runs."
  (unless (and before after) (error "Need two existing runs: ~A" (list before after)))
  (unless (equal (run-suite before) (run-suite after))
    (error "Cannot compare different suites: ~A vs ~A" (run-suite before) (run-suite after)))
  (when (and suite (not (equal suite (run-suite before))))
    (error "Selected runs belong to suite ~A, not ~A" (run-suite before) suite))
  (unless (or agent before-agent after-agent)
    (let ((common-agents (intersection (run-agents before) (run-agents after) :test #'equal)))
      (unless common-agents
        (error "Runs ~A and ~A have no common agent; select each side explicitly"
               (field before "id") (field after "id")))
      (dolist (common-agent common-agents)
        (compare-runs before after :agent common-agent :allow-mismatch allow-mismatch :suite suite))
      (return-from compare-runs nil)))
  (let* ((before-agent (or before-agent agent "codex"))
         (after-agent (or after-agent agent "codex"))
         (cross-agent (not (equal before-agent after-agent)))
         (before-profile (field before "profiles" before-agent))
         (after-profile (field after "profiles" after-agent))
         (ignored-profile-keys '("model" "effort" "tools" "mode" "timeout" "settings"
                                 "evaluationTimeoutMs" "executionTimeoutMs"))
         (mismatches (remove-if (lambda (key)
                                  (or (and cross-agent
                                           (member key ignored-profile-keys :test #'equal))
                                      (json-equal-p
                                      (if (member key ignored-profile-keys :test #'equal)
                                          (or (field before-profile key) (field before key))
                                          (field before key))
                                      (if (member key ignored-profile-keys :test #'equal)
                                          (or (field after-profile key) (field after key))
                                          (field after key)))))
                                '("suiteHash" "model" "effort" "group" "cases" "repeat"
                                  "tools" "mode" "timeout" "settings"
                                  "evaluationTimeoutMs" "executionTimeoutMs"
                                  "environment" "environmentVersions" "environmentFingerprint"
                                  "fixturesHash" "inputsHash"))))
    (unless (run-has-agent-p before before-agent)
      (error "Run ~A has no results or profile for agent ~A"
             (field before "id") before-agent))
    (unless (run-has-agent-p after after-agent)
      (error "Run ~A has no results or profile for agent ~A"
             (field after "id") after-agent))
    (when (and cross-agent
               (not (json-equal-p (field before "skillHash") (field after "skillHash"))))
      (error "Cross-agent comparison requires the same skill: ~A vs ~A"
             (field before "skillHash") (field after "skillHash")))
    (when cross-agent
      (format t "AGENT/MODEL COMPARISON: ~A (~A) -> ~A (~A); results are not skill regressions.~%"
              before-agent (or (field before-profile "model") (field before "model") "unknown")
              after-agent (or (field after-profile "model") (field after "model") "unknown")))
    (when (and mismatches (not allow-mismatch))
      (error "Not directly comparable: ~{~A~^, ~}. Use --allow-mismatch explicitly." mismatches))
    (when mismatches (format t "CAUTION: differing ~{~A~^, ~}~%" mismatches))
    (format t "~A -> ~A~%" (field before "id") (field after "id"))
    (loop for run in (list before after)
          for selected in (list before-agent after-agent) do
      (format t "~A [~A]: ~A~%" (field run "label") selected
              (40ants-ai-evals/util:encode
               (or (field run "agentVariants" selected) (field run "variants")))))
    (let ((seen (make-hash-table :test 'equal)))
      (dolist (row (append (remove-if-not (lambda (row)
                                            (equal before-agent
                                                   (summary-row-agent-variant-agent row)))
                                          (sequence-list (field before "rows")))
                          (remove-if-not (lambda (row)
                                           (equal after-agent
                                                  (summary-row-agent-variant-agent row)))
                                         (sequence-list (field after "rows")))))
        (multiple-value-bind (row-agent variant) (summary-row-agent-variant row)
          (let* ((case (field row "case"))
                 (key (list case variant)))
          (unless (gethash key seen)
            (setf (gethash key seen) t)
            (format t "~A [~A]: ~A -> ~A~%" case
                    (if cross-agent
                        (format nil "~A->~A:~A" before-agent after-agent variant)
                        (format nil "~A:~A" row-agent variant))
                    (case-ratio before case variant before-agent)
                    (case-ratio after case variant after-agent)))))))))
