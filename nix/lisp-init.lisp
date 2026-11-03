;;;; Project-local Qlot sources and sample-owned ASDF outputs.
(require :asdf)
(when (uiop:getenv "SKILL_EVAL_TOOL_PATH")
  (setf (uiop:getenv "PATH") (uiop:getenv "SKILL_EVAL_TOOL_PATH")))
(defun cl-user::skill-eval-initialize-output-translations (&optional (workspace (uiop:getcwd)))
  "Reuse provisioned dependency FASLs while confining candidate outputs to WORKSPACE."
  (let* ((root (uiop:ensure-directory-pathname (uiop:getenv "SKILL_EVAL_DEPENDENCY_ROOT")))
         (workspace (uiop:ensure-directory-pathname workspace))
         (candidate (merge-pathnames ".eval-cache/common-lisp/" workspace))
         (shared (merge-pathnames ".evals/cache/dependencies/" root)))
    (asdf:initialize-output-translations
     `(:output-translations
       ,@(unless (equal (truename workspace) (truename root))
           `(((,workspace :**/ :*.*.*) (,candidate :implementation))))
       ((,root :**/ :*.*.*) (,shared :implementation))
       (t (,candidate :implementation))
       :ignore-inherited-configuration))))
(let* ((root (uiop:ensure-directory-pathname (uiop:getenv "SKILL_EVAL_DEPENDENCY_ROOT")))
       (setup (merge-pathnames ".qlot/setup.lisp" root)))
  (unless (probe-file setup)
    (error "Missing project dependencies; run qlot install in ~A" root))
  (let ((*standard-output* *error-output*) (*trace-output* *error-output*))
    (cl-user::skill-eval-initialize-output-translations)
    (asdf:initialize-source-registry '(:source-registry :ignore-inherited-configuration))
    (load setup :verbose nil :print nil)
    ;; The bundled ASDF initially provides an older UIOP than this Qlot release.
    ;; Retain its expected upgrade diagnostics without flooding each tool result.
    ;; This handler covers only bootstrap redefinitions, never candidate warnings.
    (let ((log (merge-pathnames ".eval-cache/lisp-startup.log" (uiop:getcwd))))
      (ensure-directories-exist log)
      (with-open-file (stream log :direction :output :if-exists :append
                                  :if-does-not-exist :create :external-format :utf-8)
        (handler-bind ((sb-kernel:redefinition-warning
                         (lambda (condition)
                           (format stream "~A~%" condition)
                           (muffle-warning condition))))
          (asdf:load-system "uiop" :verbose nil))))
    (if (equal (truename root) (truename (uiop:getcwd)))
        (pushnew (uiop:getcwd) asdf:*central-registry* :test (function equal))
        (progn
          ;; Qlot adds a second searcher which otherwise scans every fixture in
          ;; the harness repository, independently of ASDF source-registry rules.
          (let ((searcher (find-symbol "PROJECT-SYSTEM-SEARCHER"
                                       "QLOT/LOCAL-INIT/SETUP")))
            (setf asdf:*system-definition-search-functions*
                  (remove searcher asdf:*system-definition-search-functions*)))
          (setf asdf:*central-registry* (list (uiop:getcwd)))
          (asdf:initialize-source-registry
           `(:source-registry (:tree ,(uiop:getcwd))
             :ignore-inherited-configuration))))))
