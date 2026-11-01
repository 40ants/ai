;;;; Agent identity and task rendering, independent of skill variants.
(uiop:define-package #:40ants-ai-evals/agents
  (:use #:cl)
  (:import-from #:cl-ppcre)
  (:import-from #:serapeum #:-> #:dict)
  (:import-from #:40ants-ai-evals/util #:field #:decode #:encode)
  (:export #:*profiles* #:selected-agents #:profile-for #:provider-label #:provider-identity
           #:render-task))
(in-package #:40ants-ai-evals/agents)

(defparameter *profiles*
  (dict "codex" (dict "agent" "codex" "model" "gpt-6-sol" "effort" "medium")
        "opencode" (dict "agent" "opencode" "model" "zai-coding-plan/glm-5.3"
                         "mode" "build"))
  "Default agent profiles. PROFILE-FOR returns a copy; callers may override one run's model.
EFFORT is a Codex setting and is never translated into an OpenCode reasoning option.")

(-> selected-agents (hash-table)
    list)
(defun selected-agents (flags)
  "Resolve `--agent`; preserve Codex as the default for existing commands."
  (let ((agent (or (field flags "agent") "codex")))
    (cond ((equal agent "all") (list "codex" "opencode"))
          ((member agent '("codex" "opencode") :test #'equal) (list agent))
          (t (error "Unknown agent: ~A" agent)))))

(-> profile-for (string hash-table &optional hash-table)
    hash-table)
(defun profile-for (agent flags &optional tools)
  "Copy AGENT's profile, recording only tools relevant to that agent."
  (let ((profile (decode (encode (or (field *profiles* agent)
                                     (error "Unknown agent profile: ~A" agent)))))
        (versions (dict)))
    (when (field flags "model")
      (setf (gethash "model" profile) (field flags "model")))
    (when (and (equal agent "codex") (field flags "effort"))
      (setf (gethash "effort" profile) (field flags "effort")))
    (when tools
      (dolist (name (append '("promptfoo" "sbcl" "node" "ros" "qlot" "asdfSystem"
                              "qlfileLockSha256")
                            (if (equal agent "codex") '("codex" "codexSdk") '("opencode"))))
        (when (field tools name)
          (setf (gethash name versions) (field tools name))))
      (setf (gethash "tools" profile) versions))
    profile))

(-> provider-label (string string)
    string)
(defun provider-label (agent variant)
  "Return an unambiguous provider label for one agent/skill combination."
  (format nil "~A:~A" agent variant))

(-> provider-identity (string)
    (values string string &optional))
(defun provider-identity (label)
  "Decode current labels and historical Codex-only labels into agent and variant."
  (let ((separator (position #\: label)))
    (if separator
        (let ((agent (subseq label 0 separator)))
          (values (if (equal agent "codex-cli") "codex" agent) (subseq label (1+ separator))))
        (values "codex" label))))

(-> render-task (string string)
    string)
(defun render-task (task agent)
  "Adapt explicit native skill references while leaving the requested task intact."
  (if (equal agent "opencode")
      (cl-ppcre:regex-replace-all "\\$writing-common-lisp" task "writing-common-lisp skill")
      task))
