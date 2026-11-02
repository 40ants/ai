;;;; Generic checks supplied as an extension, not wired into the grading engine.
(uiop:define-package #:40ants-ai-evals-common-checks/checks
  (:use #:cl)
  (:import-from #:40ants-ai-evals/case-resources
                #:baseline-manifest #:sample-manifest #:metadata-equal-p #:manifest-equal-p)
  (:import-from #:serapeum #:-> #:dict)
  (:import-from #:40ants-ai-evals/util
                #:field #:true-p #:json-equal-p #:sequence-list)
  (:import-from #:40ants-ai-evals/checks
                #:register-check #:register-profile #:context-sample #:context-vars #:outcome))
(in-package #:40ants-ai-evals-common-checks/checks)

(-> source (hash-table hash-table)
    (or null string))
(defun source (context params)
  (let ((text (field (context-sample context) "files" (field params "file"))))
    (when (and (stringp text) (plusp (length text))) text)))

(-> skill-read (hash-table hash-table)
    t)
(defun skill-read (context params)
  (let ((sample (context-sample context)))
    (unless (equal (field sample "variant") "without-skill")
      (outcome "skill-read" (eq (true-p (field sample "skillRead"))
                               (true-p (field params "expected")))))))

(-> preserved (hash-table hash-table)
    vector)
(defun preserved (context params)
  (let ((results nil) (files (sample-manifest (context-sample context))))
    (maphash (lambda (file metadata)
               (when (or (equal file "AGENTS.md") (equal file (field params "protected")))
                 (push (outcome (format nil "preserved:~A" file)
                                (metadata-equal-p metadata (field files file))) results)))
             (baseline-manifest (context-vars context) (field params "fixtures")))
    (coerce (nreverse results) 'vector)))

(-> no-changes (hash-table hash-table)
    hash-table)
(defun no-changes (context params)
  (outcome "no-changes"
           (manifest-equal-p (baseline-manifest (context-vars context) (field params "fixtures"))
                             (sample-manifest (context-sample context)))))

(-> text-contains (hash-table hash-table)
    hash-table)
(defun text-contains (context params)
  (let ((text (field (context-sample context) "files" (field params "file"))))
    (outcome "text-output" (and (stringp text) (search (field params "contains") text)))))

(-> target-file (hash-table hash-table)
    hash-table)
(defun target-file (context params)
  (outcome "target-file" (source context params)))

(-> source-scope (hash-table hash-table)
    t)
(defun source-scope (context params)
  (when (source context params)
    (let ((baseline (baseline-manifest (context-vars context) (field params "fixtures"))))
      (outcome "scope"
               (loop for file being the hash-keys of (sample-manifest (context-sample context))
                     always (or (equal file (field params "file"))
                                (nth-value 1 (gethash file baseline))))))))

(-> no-tabs (hash-table hash-table)
    t)
(defun no-tabs (context params)
  (let ((text (source context params)))
    (when text (outcome "no-tabs" (not (find #\Tab text))))))

(-> line-length (hash-table hash-table)
    t)
(defun line-length (context params)
  (let ((text (source context params)) (limit (field params "limit")))
    (unless (plusp limit) (error "Line length limit must be positive: ~D" limit))
    (when text
      (outcome (format nil "~D-columns" limit)
               (every (lambda (line)
                        (<= (loop for char across line
                                  sum (if (> (char-code char) #xffff) 2 1)) limit))
                      (uiop:split-string text :separator '(#\Newline)))))))

(-> positive-limit-p (hash-table)
    boolean)
(defun positive-limit-p (params)
  (plusp (field params "limit")))

(register-check "agent/skill-read" 'skill-read :parameters (dict "expected" "boolean"))
(register-check "files/preserved" 'preserved
                :parameters (dict "fixtures" "any" "protected" "nullable-string")
                :defaults (dict "fixtures" (dict) "protected" :null))
(register-check "files/no-changes" 'no-changes :parameters (dict "fixtures" "any")
                :defaults (dict "fixtures" (dict)))
(register-check "files/text-contains" 'text-contains
                :parameters (dict "file" "string" "contains" "string"))
(register-check "source/target-file" 'target-file :parameters (dict "file" "string"))
(register-check "source/scope" 'source-scope
                :parameters (dict "file" "string" "fixtures" "any")
                :defaults (dict "fixtures" (dict)))
(register-check "source/no-tabs" 'no-tabs :parameters (dict "file" "string"))
(register-check "source/max-line-length" 'line-length
                :parameters (dict "file" "string" "limit" "integer")
                :defaults (dict "limit" 100) :validate 'positive-limit-p)

(register-profile "common/contract"
 (vector
  (dict "check" "agent/skill-read" "params" (dict "expected" (dict "$var" "shouldTrigger")))
  (dict "check" "files/preserved"
        "params" (dict "fixtures" (dict "$var" "fixtures" "default" (dict))
                       "protected" (dict "$var" "protected" "default" :null)))
  (dict "check" "files/no-changes"
        "when" "noChanges"
        "params" (dict "fixtures" (dict "$var" "fixtures" "default" (dict))))
  (dict "check" "files/text-contains" "when" "textFile"
        "params" (dict "file" (dict "$var" "textFile")
                       "contains" (dict "$var" "textContains")))
  (dict "check" "source/target-file"
        "when" "file"
        "params" (dict "file" (dict "$var" "file")))
  (dict "check" "source/scope"
        "when" "sourceOnly"
        "params" (dict "file" (dict "$var" "file")
                       "fixtures" (dict "$var" "fixtures" "default" (dict))))
  (dict "check" "source/no-tabs"
        "when" "file"
        "params" (dict "file" (dict "$var" "file")))
  (dict "check" "source/max-line-length"
        "when" "file"
        "params" (dict "file" (dict "$var" "file")))))
