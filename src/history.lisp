;;;; Read old and new exports without modifying Promptfoo's database.
(uiop:define-package #:40ants-ai-evals/src/history
  (:use #:cl)
  (:import-from #:serapeum #:-> #:dict)
  (:import-from #:40ants-ai-evals/src/util
                #:field #:true-p #:bool #:decode #:read-json #:write-json
                #:sequence-list #:json-equal-p #:root #:at)
  (:export #:histories #:find-run #:make-summary #:summarize #:print-summary
           #:compare-runs #:print-history))
(in-package #:40ants-ai-evals/src/history)

(-> present (t)
    t)
(defun present (value)
  (unless (eq value :null) value))

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

(-> find-run (string &optional list)
    t)
(defun find-run (id &optional (all (histories)))
  "Resolve an exact ID, unique label, latest or previous."
  (cond ((equal id "latest") (car (last all)))
        ((equal id "previous") (when (> (length all) 1) (nth (- (length all) 2) all)))
        (t (or (find id all :key (lambda (run) (field run "id")) :test #'equal)
               (let ((labelled (remove-if-not
                                (lambda (run) (equal id (field run "label"))) all)))
                 (when (> (length labelled) 1)
                   (error "Ambiguous label ~A; use an exact run ID" id))
                 (first labelled))))))

(-> result-row (hash-table)
    hash-table)
(defun result-row (result)
  (let* ((response (field result "response"))
         (sample (or (present (field response "metadata" "skillEval"))
                      (handler-case
                          (if (stringp (field response "output"))
                              (decode (field response "output")) (field response "output"))
                        (error () nil))))
         (usage (field sample "usage"))
         (infra (present (field sample "infrastructureError")))
         (provider-error (present (field response "error"))))
    (dict "case" (or (field result "testCase" "vars" "id") (field result "vars" "id") :null)
          "variant" (or (field sample "variant") (field result "provider" "label")
                        (field result "provider" "id") :null)
          "pass" (bool (true-p (field result "success")))
          "score" (or (field result "score") :null)
          "error" (if (or infra (eql 2 (field result "failureReason")) provider-error)
                      (or infra (present (field result "error")) provider-error
                          "Provider/grader error") :null)
          "reason" (or (field result "gradingResult" "reason") :null)
          "tokens" (if (hash-table-p usage)
                       (+ (or (field usage "input_tokens") 0)
                          (or (field usage "output_tokens") 0))
                       (or (field response "tokenUsage" "total") :null))
          "cachedInputTokens" (or (field usage "cached_input_tokens") 0)
          "durationMs" (or (present (field sample "durationMs")) (field result "latencyMs") :null)
          "commands" (or (field sample "commandCount") :null)
          "skillRead" (or (field sample "skillRead") :null)
          "trace" (or (field sample "trace") :null))))

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
         (rows (mapcar #'result-row raw))
         (cases (sequence-list (field manifest "cases")))
         (variants (sequence-list (field manifest "variants")))
         (repeat (field manifest "repeat"))
         (expected (* (length cases) repeat (length variants)))
         (stats (dict))
         (summary (dict)))
    (dolist (variant variants)
      (setf (gethash variant stats)
            (variant-statistics
             (remove-if-not
              (lambda (row)
                (member (field row "variant")
                        (list variant (concatenate 'string "codex-cli:" variant)) :test #'equal))
              rows))))
    (dolist (key '("id" "label" "started" "skillHash" "suiteHash" "model" "effort"
                   "group" "cases" "repeat" "tools"))
      (setf (gethash key summary) (field manifest key)))
    (setf (gethash "processStatus" summary) status
          (gethash "processSignal" summary) signal
          (gethash "expected" summary) expected
          (gethash "observed" summary) (length rows)
          (gethash "coverageComplete" summary)
          (bool (and (plusp expected) (= expected (length rows))
                     (every (lambda (case)
                              (every (lambda (variant)
                                       (= repeat
                                          (count-if
                                           (lambda (row)
                                             (and (equal case (field row "case"))
                                                  (member (field row "variant")
                                                   (list variant
                                                    (concatenate 'string "codex-cli:" variant))
                                                   :test #'equal))) rows))) variants)) cases)))
          (gethash "variants" summary) stats
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
  (format t "~%~A (~A)~%" (field summary "id") (field summary "label"))
  (maphash (lambda (variant stats)
             (format t "~A: ~D/~D passed; ~D assertion failures; ~D infrastructure errors~%"
                     variant (field stats "passed") (field stats "total")
                     (field stats "failed") (field stats "errors")))
           (field summary "variants"))
  (unless (true-p (field summary "coverageComplete"))
    (format t "INCOMPLETE COVERAGE: ~D/~D~%" (field summary "observed") (field summary "expected")))
  (loop for row across (field summary "rows") unless (true-p (field row "pass")) do
    (format t "~A [~A]: ~A~%" (field row "case") (field row "variant")
            (if (error-p row) (field row "error") (field row "reason"))))
  (format t "Artifacts: ~A~%" (at (root) (format nil ".evals/runs/~A/" (field summary "id")))))

(-> print-history ()
    t)
(defun print-history ()
  "List all accumulated runs, preserving access to deeper history."
  (dolist (run (histories))
    (format t "~A  ~A  ~A  ~D/~D passed; coverage ~D/~D~%"
            (field run "id") (field run "label") (field run "model")
            (count-if (lambda (row) (true-p (field row "pass")))
                      (sequence-list (field run "rows")))
            (length (field run "rows")) (field run "observed") (field run "expected"))))

(-> case-ratio (hash-table string string)
    string)
(defun case-ratio (run case variant)
  (let ((rows (remove-if-not (lambda (row) (and (equal case (field row "case"))
                                               (equal variant (field row "variant"))))
                             (sequence-list (field run "rows")))))
    (format nil "~D/~D" (count-if (lambda (row) (true-p (field row "pass"))) rows) (length rows))))

(-> compare-runs (t t &key (:allow-mismatch t))
    t)
(defun compare-runs (before after &key allow-mismatch)
  "Compare compatible runs, or explicitly print mismatched settings."
  (unless (and before after) (error "Need two existing runs: ~A" (list before after)))
  (let ((mismatches (remove-if (lambda (key) (json-equal-p (field before key) (field after key)))
                              '("suiteHash" "model" "effort" "group" "cases" "repeat" "tools"))))
    (when (and mismatches (not allow-mismatch))
      (error "Not directly comparable: ~{~A~^, ~}. Use --allow-mismatch explicitly." mismatches))
    (when mismatches (format t "CAUTION: differing ~{~A~^, ~}~%" mismatches))
    (format t "~A -> ~A~%" (field before "id") (field after "id"))
    (dolist (run (list before after))
      (format t "~A: ~A~%" (field run "label")
              (40ants-ai-evals/src/util:encode (field run "variants"))))
    (let ((seen (make-hash-table :test 'equal)))
      (dolist (row (append (sequence-list (field before "rows"))
                          (sequence-list (field after "rows"))))
        (let* ((case (field row "case")) (variant (field row "variant"))
               (key (list case variant)))
          (unless (gethash key seen)
            (setf (gethash key seen) t)
            (format t "~A [~A]: ~A -> ~A~%" case variant
                    (case-ratio before case variant) (case-ratio after case variant))))))))
