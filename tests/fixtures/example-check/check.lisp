;;;; Minimal third-party check: add this system to checkSystems to enable it.
(uiop:define-package #:40ants-ai-evals-example-check/check
  (:use #:cl)
  (:import-from #:serapeum #:-> #:dict)
  (:import-from #:40ants-ai-evals/src/util #:field)
  (:import-from #:40ants-ai-evals/src/checks #:register-check #:context-sample #:outcome))
(in-package #:40ants-ai-evals-example-check/check)

(-> no-fixme (hash-table hash-table)
    hash-table)
(defun no-fixme (context params)
  (let ((text (field (context-sample context) "files" (field params "file"))))
    (outcome "no-fixme" (and (stringp text) (not (search (field params "marker") text))))))

(register-check "example/no-fixme" 'no-fixme
                :parameters (dict "file" "string" "marker" "string")
                :defaults (dict "marker" "FIXME"))
