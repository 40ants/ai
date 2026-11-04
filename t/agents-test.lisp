;;;; Agent configuration and transport tests do not call a model.
(uiop:define-package #:40ants-ai-evals-tests/agents-test
  (:use #:cl)
  (:import-from #:serapeum #:-> #:dict)
  (:import-from #:rove #:deftest #:ok #:signals)
  (:import-from #:40ants-ai-evals/agents
                #:selected-agents #:profile-for #:provider-identity #:render-task)
  (:import-from #:40ants-ai-evals/util
                #:field #:at #:root #:read-json #:write-text #:write-json #:encode #:decode
                #:temporary-directory #:remove-directory #:run-command)
  (:import-from #:40ants-ai-evals/runner #:validate-options))
(in-package #:40ants-ai-evals-tests/agents-test)

(deftest profiles-and-options
  (ok (equal '("codex") (selected-agents (dict))))
  (ok (equal '("codex" "opencode") (selected-agents (dict "agent" "all"))))
  (ok (equal "zai-coding-plan/glm-5.3" (field (profile-for "opencode" (dict)) "model")))
  (let ((profile (profile-for "codex" (dict))))
    (setf (gethash "model" profile) "changed")
    (ok (equal "gpt-6-sol" (field (profile-for "codex" (dict)) "model"))))
  (let ((profile (profile-for "codex" (dict) (dict "codex" "version" "opencode" "other"))))
    (ok (equal "version" (field profile "tools" "codex")))
    (ok (not (field profile "tools" "opencode"))))
  (dolist (flags (list (dict "agent" "unknown")
                       (dict "agent" "all" "model" "ambiguous")
                       (dict "agent" "all" "effort" "high")
                       (dict "agent" "opencode" "effort" "medium")
                       (dict "agent" "opencode" "model" "missing-provider")))
    (ok (signals (validate-options flags))))
  (validate-options (dict "agent" "opencode"))
  (validate-options (dict "agent" "all")))

(deftest native-task-rendering
  (let ((task "Use $writing-common-lisp. Create a file."))
    (ok (equal task (render-task task "codex")))
    (ok (equal "Use writing-common-lisp skill. Create a file." (render-task task "opencode"))))
  (multiple-value-bind (agent variant) (provider-identity "opencode:without-skill")
    (ok (equal "opencode" agent)) (ok (equal "without-skill" variant)))
  (multiple-value-bind (agent variant) (provider-identity "codex-cli:with-skill")
    (ok (equal "codex" agent)) (ok (equal "with-skill" variant))))

(deftest independent-fixture-matrix
  (let* ((scratch (temporary-directory "agent-fixtures"))
         (vars (dict "id" "one" "task" "Use $writing-common-lisp. Create code."
                     "fixtures" (dict "AGENTS.md" "Project instructions")))
         (cases (list (dict "vars" vars))))
    (unwind-protect
         (progn
           (write-text (at scratch "skill/SKILL.md") "Skill instructions")
           (40ants-ai-evals/runner::prepare-fixtures
            scratch cases '("with-skill" "without-skill") '("codex" "opencode"))
           (ok (equal "Create code." (field vars "taskWithoutSkill")))
           (ok (equal "Use writing-common-lisp skill. Create code." (field vars "task_opencode")))
           (let ((codex (field vars "workspaces" "codex" "with-skill"))
                 (open (field vars "workspaces" "opencode" "with-skill"))
                 (control (field vars "workspaces" "opencode" "without-skill")))
             (ok (not (equal codex open)))
             (ok (probe-file (at codex ".agents/skills/writing-common-lisp/SKILL.md")))
             (ok (probe-file (at open ".opencode/skills/writing-common-lisp/SKILL.md")))
             (ok (not (probe-file (at control ".opencode/skills/writing-common-lisp/SKILL.md"))))
             (ok (equal "Project instructions" (uiop:read-file-string (at control "AGENTS.md")))))
           (uiop:copy-file (at (root) "evals/writing-common-lisp/promptfooconfig.json")
                           (ensure-directories-exist
                            (at scratch "harness/evals/writing-common-lisp/promptfooconfig.json")))
           (let* ((profiles (dict "codex" (profile-for "codex" (dict))
                                  "opencode" (profile-for "opencode" (dict))))
                  (config (read-json
                           (40ants-ai-evals/runner::effective-config
                            scratch cases (dict "agent" "all" "ablation" t) scratch profiles
                            (dict "baseUrl" "http://127.0.0.1:1234")))))
             (ok (= 4 (length (field config "providers"))))
             (ok (= 4 (length (field config "prompts"))))
             (loop for provider across (field config "providers") do
               (ok (= 1 (length (field provider "prompts"))))
               (ok (equal (field provider "label") (aref (field provider "prompts") 0))))))
      (remove-directory scratch))))

(-> invoke-provider-transport (pathname string integer)
    hash-table)
(defun invoke-provider-transport (scratch body timeout)
  (let ((fake (at scratch "bin/ros")))
    (write-text fake (format nil "#!/bin/sh~%cat >/dev/null~%~A~%" body))
    (run-command (list "chmod" "+x" (namestring fake)))
    (decode
     (run-command
      (list "env" (format nil "PATH=~A:~A" (at scratch "bin/") (uiop:getenv "PATH"))
            "node" "-e"
            (concatenate 'string
             "const Provider=require(process.argv[1]);"
             "const provider=new Provider({config:{timeout:Number(process.argv[2])}});"
             "provider.callApi('task',{vars:{id:'one'}})"
             ".then(r=>console.log(JSON.stringify(r)))"
             ".catch(e=>console.log(JSON.stringify({transportError:e.message})));" )
            (namestring (at (root) "evals/lib/opencode-provider.cjs"))
            (princ-to-string timeout)) :timeout 40))))

(deftest provider-transport-protocol
  (let ((scratch (temporary-directory "provider-transport")))
    (unwind-protect
         (progn
           (let ((response (invoke-provider-transport
                            scratch "printf '{\"output\":\"done\",\"metadata\":{\"agent\":\"opencode\"}}'" 1000)))
             (ok (equal "done" (field response "output")))
             (ok (equal "opencode" (field response "metadata" "agent"))))
           (dolist (body '("printf 'not-json'" "printf '{}'" "exit 3"))
             (ok (stringp (field (invoke-provider-transport scratch body 1000) "transportError")))))
      (remove-directory scratch))))

(deftest agent-specific-timeouts
  (ok (= 240000 (40ants-ai-evals/runner::evaluation-timeout (dict))))
  (ok (= 660000 (40ants-ai-evals/runner::evaluation-timeout (dict "agent" "opencode"))))
  (ok (= 660000 (40ants-ai-evals/runner::evaluation-timeout (dict "agent" "all"))))
  (ok (= 630000 (40ants-ai-evals/runner::opencode-execution-timeout (dict "agent" "opencode"))))
  (ok (= 210000 (40ants-ai-evals/runner::opencode-execution-timeout
                 (dict "agent" "opencode" "timeout" "240000")))))
