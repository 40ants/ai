;;;; Make Qlot libraries available to ordinary SBCL commands in agent fixtures.
(require :asdf)
(let* ((root (uiop:ensure-directory-pathname (uiop:getenv "SKILL_EVAL_DEPENDENCY_ROOT")))
       (setup (merge-pathnames ".qlot/setup.lisp" root)))
  (unless (probe-file setup)
    (error "Missing project dependencies; run qlot install in ~A" root))
  (let ((*standard-output* *error-output*) (*trace-output* *error-output*))
    ;; Codex has a private XDG cache. Reuse dependency FASLs warmed by the
    ;; harness, so a sandboxed SBCL need only read the project dependency tree.
    (asdf:initialize-output-translations
     `(:output-translations
       (t (,(merge-pathnames ".evals/cache/common-lisp/" root) :implementation))
       :ignore-inherited-configuration))
    (asdf:initialize-source-registry '(:source-registry :ignore-inherited-configuration))
    (load setup :verbose nil :print nil)))
