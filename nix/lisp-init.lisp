;;;; Project-local Qlot sources and sample-owned ASDF outputs.
;; ASDF itself can emit pinned-distribution diagnostics before UIOP exists.
(let ((log (merge-pathnames ".eval-cache/lisp-startup.log"
             (pathname (concatenate 'string (sb-unix:posix-getcwd) "/")))))
  (ensure-directories-exist log)
  (handler-case
      (with-open-file (stream log :direction :output :if-exists :append
                                  :if-does-not-exist :create :external-format :utf-8)
        (let ((*standard-output* stream) (*error-output* stream) (*trace-output* stream))
          (require :asdf)))
    (error (condition)
      (format *error-output* "Pinned ASDF bootstrap failed; diagnostics: ~A~%" log)
      (error condition))))
(defun cl-user::skill-eval-initialize-output-translations (&optional (workspace (uiop:getcwd)))
  "Reuse pinned dependency outputs and preserve reversible source paths for test discovery."
  (let* ((root (truename (uiop:ensure-directory-pathname (uiop:getenv "SKILL_EVAL_DEPENDENCY_ROOT"))))
         (workspace (truename (uiop:ensure-directory-pathname workspace)))
         (candidate (merge-pathnames ".eval-cache/common-lisp/" workspace))
         (shared (merge-pathnames ".evals/cache/dependencies/" root))
         (candidate-cache (asdf:resolve-location `(,candidate :implementation) :ensure-directory t))
         (shared-cache (asdf:resolve-location `(,shared :implementation) :ensure-directory t))
         (project-root-p (equal workspace root)))
    ;; Rove reverses the standard ASDF cache prefix to recover a loaded file's
    ;; source pathname. Retain the absolute source directory below that prefix.
    (setf asdf:*user-cache* (if project-root-p shared-cache candidate-cache))
    (asdf:initialize-output-translations
     `(:output-translations
       ,@(unless project-root-p
           `(((,workspace :**/ :*.*.*)
              (,candidate-cache ,@(cdr (pathname-directory workspace)) :**/ :*.*.*))))
       ((,root :**/ :*.*.*)
        (,shared-cache ,@(cdr (pathname-directory root)) :**/ :*.*.*))
       (t (,candidate-cache :**/ :*.*.*))
       :ignore-inherited-configuration))))

(let* ((root (uiop:ensure-directory-pathname (uiop:getenv "SKILL_EVAL_DEPENDENCY_ROOT")))
       (setup (merge-pathnames ".qlot/setup.lisp" root))
       (log (merge-pathnames ".eval-cache/lisp-startup.log" (uiop:getcwd))))
  (unless (probe-file setup)
    (error "Missing project dependencies; run qlot install in ~A" root))
  (ensure-directories-exist log)
  (handler-case
      (with-open-file (stream log :direction :output :if-exists :append
                                  :if-does-not-exist :create :external-format :utf-8)
        (format stream "~&Pinned bootstrap: ~A~%" *load-truename*)
        ;; Bootstrap only: no candidate source or documentation system is loaded
        ;; under these bindings. Warnings remain recorded, not discarded.
        (let ((*standard-output* stream) (*error-output* stream) (*trace-output* stream))
          ;; UIOP's SETENV expands to REQUIRE SB-POSIX, which initializes ASDF's
          ;; implementation registry. Keep that pinned bootstrap inside the log.
          (when (uiop:getenv "SKILL_EVAL_TOOL_PATH")
            (setf (uiop:getenv "PATH") (uiop:getenv "SKILL_EVAL_TOOL_PATH")))
          (cl-user::skill-eval-initialize-output-translations)
          (asdf:initialize-source-registry '(:source-registry :ignore-inherited-configuration))
          (load setup :verbose nil :print nil)
          (asdf:load-system "uiop" :verbose nil)
          ;; Qlot may upgrade UIOP and its cache defaults during setup.
          (cl-user::skill-eval-initialize-output-translations)
          (if (equal (truename root) (truename (uiop:getcwd)))
              (pushnew (uiop:getcwd) asdf:*central-registry* :test (function equal))
              (progn
                ;; Qlot's extra searcher otherwise scans unrelated fixture projects.
                (let ((searcher (find-symbol "PROJECT-SYSTEM-SEARCHER" "QLOT/LOCAL-INIT/SETUP")))
                  (setf asdf:*system-definition-search-functions*
                        (remove searcher asdf:*system-definition-search-functions*)))
                (setf asdf:*central-registry* (list (uiop:getcwd)))
                (asdf:initialize-source-registry
                 `(:source-registry (:tree ,(uiop:getcwd)) :ignore-inherited-configuration))))
          (asdf:ensure-source-registry)
          (let ((descriptor (merge-pathnames ".eval-fixture.json" (uiop:getcwd))))
            (when (probe-file descriptor)
              (asdf:load-system "yason" :verbose nil)
              (let ((profile (with-open-file (input descriptor :external-format :utf-8)
                               (gethash "profile" (funcall (find-symbol "PARSE" "YASON") input)))))
                ;; Preload only pinned builder dependencies; the candidate docs
                ;; load later with their warnings and strict failures visible.
                (when (equal profile "docs")
                  (format stream "~&Preloading pinned documentation dependencies.~%")
                  (dolist (system '("40ants-doc" "40ants-doc-full" "docs-builder"))
                    (asdf:load-system system :verbose nil))))))))
    (error (condition)
      (format *error-output* "Pinned Lisp bootstrap failed; diagnostics: ~A~%" log)
      (error condition))))
