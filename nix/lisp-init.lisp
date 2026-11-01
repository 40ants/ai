;;;; Project-local Qlot sources and sample-owned ASDF outputs.
(require :asdf)
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
    (pushnew (uiop:getcwd) asdf:*central-registry* :test (function equal))))
