;;;; Reproducible environments, materialized before native sample copies.
(uiop:define-package #:40ants-ai-evals/environments
  (:use #:cl)
  (:import-from #:serapeum #:dict #:->)
  (:import-from #:babel)
  (:import-from #:ironclad)
  (:import-from #:40ants-ai-evals/util
                #:field #:at #:root #:write-json #:read-json #:write-text
                #:digest-file #:run-command #:tree-files #:copy-directory #:bool
                #:temporary-directory #:remove-directory)
  (:export #:preflight #:prepare #:codex-config #:opencode-config #:finalize
           #:profile-name #:environment-variables #:workspace-instructions))
(in-package #:40ants-ai-evals/environments)

(-> profile-name (t)
    string)
(defun profile-name (value)
  "Normalize the environment profile declared by a suite."
  (let ((name (string-downcase (or value "lisp"))))
    (if (string= name "browser") "playwright" name)))

(-> workspace-instructions ()
    string)
(defun workspace-instructions ()
  "Describe runtime facts without revealing any skill or assertion requirement."
  (format nil "~{~A~^ ~}"
          '("Prepared workspace: run every shell command through `qlot exec` from this"
            "directory (including inspection, Lisp, builds and tests). The pinned"
            "project Qlot libraries are installed. Do not install dependencies or"
            "search personal Quicklisp, /nix/store, or other projects. Read"
            "`.eval-environment.json` for runtime facts. For a standalone Lisp file,"
            "use `qlot exec sbcl --non-interactive --eval '(asdf:load-system \"LIBRARY\")'"
            "--load path/to/file.lisp`, replacing LIBRARY with its declared dependency."
            "Load a project through ASDF only when its .asd file is present;"
            "package-inferred roots do not automatically load every source file."
            "No ASDF scaffolding is needed to verify a standalone file. Bootstrap"
            "diagnostics are in `.eval-cache/lisp-startup.log`; candidate errors"
            "remain in stderr.")))

(-> check-sample-runtime ()
    t)
(defun check-sample-runtime ()
  "Exercise the copied sample entry point before contacting any model."
  (let ((workspace (temporary-directory "qlot-preflight")))
    (unwind-protect
         (run-command
          (list "qlot" "exec" "sbcl" "--non-interactive" "--eval"
                "(let ((searcher (find-symbol \"PROJECT-SYSTEM-SEARCHER\" \"QLOT/LOCAL-INIT/SETUP\"))) (assert (not (member searcher asdf:*system-definition-search-functions*))))"
                "--eval" "(asdf:load-system \"serapeum\")"
                "--eval" "(assert (macro-function (find-symbol \"->\" \"SERAPEUM\")))")
          :directory workspace :timeout 60)
      (remove-directory workspace))))

(-> preflight (t &key (:check-tools t))
    hash-table)
(defun preflight (profile &key (check-tools t))
  "Return pinned environment identity; fail before a run if tools are missing."
  (let* ((profile (profile-name profile))
         (versions (dict "nixpkgs" "885ba4d038f10c3d17d7a92e8c3cc185b99c9158"
                         "quicklisp" "2026-01-01"
                         "mallet" "553c9092239e8a215dfb88650cc8facd2569be2b"
                         "40ants-linter" "1a1ec50537c2167a61c533b56b252768ec986fd1"
                         "python" (or (uiop:getenv "SKILL_EVAL_PYTHON_VERSION") "3.13.16")
                         "sbcl" (or (uiop:getenv "SKILL_EVAL_SBCL_VERSION") "2.6.8")
                         "roswell" (or (uiop:getenv "SKILL_EVAL_ROSWELL_VERSION") "26.10.117")
                         "playwright" (or (uiop:getenv "SKILL_EVAL_PLAYWRIGHT_VERSION") "1.64.0")
                         "playwrightDriver" "1.64.1"
                         "chromium" (or (uiop:getenv "SKILL_EVAL_CHROMIUM_VERSION") "156.0.8078.4")
                         "chromiumRevision" (or (uiop:getenv "SKILL_EVAL_CHROMIUM_REVISION") "1248")
                         "trivial-glob" "0c2675d9452ed164970f2fc4a0e41784ebee819a"
                         "sblint" "1037296f604c3210ce073a53539d4ae95b0c2f8c"
                         "fixtureProtocol" 2)))
    (unless (member profile '("lisp" "cache" "repl" "lint" "docs" "deploy" "playwright" "all") :test #'equal)
      (error "Unknown eval environment: ~A" profile))
    (when check-tools
      (run-command '("sbcl" "--version") :timeout 20)
      (unless (probe-file (at (or (uiop:getenv "SKILL_EVAL_DEPENDENCY_ROOT") (root)) ".qlot/setup.lisp"))
        (error "Project-local Qlot dependencies are missing."))
      ;; Quickload here is the provisioning boundary. No package installation is
      ;; needed while a model is running in a sample workspace.
      (run-command
       (list "qlot" "exec" "sbcl" "--noinform" "--non-interactive" "--eval"
             (format nil "(ql:quickload '~S :silent t)"
                     (append '("serapeum" "rove" "event-emitter" "global-vars" "defmain" "log4cl" "yason")
                             (when (member profile '("lint" "all") :test #'equal)
                               '("mallet" "40ants-linter"))
                             (when (member profile '("docs" "all") :test #'equal)
                               '("40ants-doc" "40ants-doc-full" "docs-builder")))))
       :timeout 300)
      (check-sample-runtime)
      (when (member profile '("playwright" "all") :test #'equal)
        ;; Launch Chromium as well as importing Python; this detects unusable apps.
        (run-command
         (list (or (uiop:getenv "SKILL_EVAL_PYTHON") "python3") "-c"
               "import os,importlib.metadata; from playwright.sync_api import sync_playwright; print(importlib.metadata.version('playwright')); p=sync_playwright().start(); b=p.chromium.launch(executable_path=os.environ['PLAYWRIGHT_BROWSER_PATH'],headless=True); page=b.new_page(); page.set_content('<title>eval-preflight</title>'); assert page.title()=='eval-preflight'; print(b.version); b.close(); p.stop()")
         :timeout 60)))
    (let ((descriptor (dict "schemaVersion" 1 "profile" profile "versions" versions)))
      (when (uiop:getenv "SKILL_EVAL_SHELL")
        (setf (gethash "shell" descriptor) (uiop:getenv "SKILL_EVAL_SHELL")))
      descriptor)))

(-> cache-relative-paths (string &optional t)
    list)
(defun cache-relative-paths (kind &optional scenario)
  (loop for version in '("sbcl-2.6.6-macosx-arm64" "sbcl-2.5.10-macosx-arm64")
        collect (format nil ".eval-cache/~A/~A/src/counter.fasl" version
                        (if (and (equal kind "project") (equal scenario "path-spaces"))
                            "project with spaces" kind))))

(-> cache-snapshot (t &optional t)
    hash-table)
(defun cache-snapshot (workspace &optional scenario)
  "Hash only explicitly modeled sample-owned cache files."
  (let ((result (dict)))
    (let ((cache (at workspace ".eval-cache/")))
      (when (probe-file cache)
        (when (sb-posix:s-islnk (sb-posix:stat-mode
                               (sb-posix:lstat (string-right-trim "/" (namestring cache)))))
          (error "Cache root must not be a symlink"))
        (tree-files cache)))
    (dolist (relative (append (cache-relative-paths "project" scenario) (cache-relative-paths "foreign" scenario)))
      (let ((file (at workspace relative)))
        (when (probe-file file)
          (when (sb-posix:s-islnk (sb-posix:stat-mode (sb-posix:lstat (namestring file))))
            (error "Cache fixture was replaced with a symlink: ~A" file))
          (setf (gethash (namestring file) result) (digest-file file)))))
    result))

(-> ensure-evidence-safe (t)
    boolean)
(defun ensure-evidence-safe (workspace)
  "Refuse evidence directories redirected outside a copied sample."
  (let ((path (at workspace ".eval-evidence/")))
    (when (probe-file path)
      (when (sb-posix:s-islnk (sb-posix:stat-mode
                             (sb-posix:lstat (string-right-trim "/" (namestring path)))))
        (error "Evidence directory must not be a symlink"))
      (tree-files path)))
  t)

(-> prepare (t t)
    hash-table)
(defun prepare (workspace vars)
  "Materialize a copyable fixture descriptor; live state starts in the copied cwd."
  (let* ((profile (profile-name (field vars "environmentProfile")))
         (descriptor (preflight profile :check-tools nil))
         (scenario (or (field vars "scenario") (dict "name" "default")))
         (scenario-name (field scenario "name")))
    (setf (gethash "scenario" descriptor) scenario
          (gethash "fixtureScript" descriptor) (namestring (at (root) "roswell/fixture-mcp.ros")))
    (when (equal profile "cache")
      (let ((before (dict)))
        (dolist (kind '("project" "foreign"))
          (dolist (relative (cache-relative-paths kind scenario-name))
            (unless (and (equal kind "project") (equal scenario-name "heldout-missing-cache"))
              (let ((file (at workspace relative)))
              (write-text file (format nil "deterministic cached ~A~%" kind))
              (setf (gethash relative before) (digest-file file))))))
        (setf (gethash "cacheBefore" descriptor) before
              (gethash "cacheProjectPaths" descriptor) (coerce (cache-relative-paths "project" scenario-name) 'vector)
              (gethash "cacheForeignPaths" descriptor) (coerce (cache-relative-paths "foreign" scenario-name) 'vector))))
    (write-json (at workspace ".eval-environment.json")
                (dict "profile" profile "scenario" scenario
                      "commandPrefix" (vector "qlot" "exec")
                      "lispSystems" (vector "serapeum" "rove" "event-emitter"
                                            "global-vars" "defmain" "log4cl" "yason")
                      "systemSearch" "workspace-and-pinned-qlot"
                      "verificationMode" (if (uiop:directory-files workspace "*.asd")
                                               "asdf-system" "source-file")
                      "startupLog" ".eval-cache/lisp-startup.log"
                      "service" "demo" "projectPath" "."
                      "browserAvailable" (bool (not (equal scenario-name "missing-browser")))
                      "browserPath" (if (equal scenario-name "missing-browser")
                                        ".missing-browser/chromium"
                                        (or (uiop:getenv "PLAYWRIGHT_BROWSER_PATH") :null))
                      "cacheRoot" ".eval-cache/" "projectPaths" (coerce (cache-relative-paths "project" scenario-name) 'vector)
                      "foreignPaths" (coerce (cache-relative-paths "foreign" scenario-name) 'vector)
                      "mcp" (cond ((equal profile "repl") (dict "tool" "eval_lisp_form" "initialCounter" 41))
                                  ((equal profile "deploy")
                                   (dict "tool" "remote_shell"
                                         "operations" (vector "inspect" "create-service" "configure-service" "build" "install-release" "switch-current"
                                                              "update-unit" "daemon-reload" "restart" "health"
                                                              "cleanup" "update-caddy" "validate-caddy" "caddy-reload")
                                         "revision" "YYYYMMDD-HHMMSS" "atomic" (bool t)
                                         "serviceUser" "demo" "dataMode" "0700" "envMode" "0600"
                                         "noRealSecrets" (bool t)
                                         "root" "/srv/services/demo/current/public" "upstream" "127.0.0.1:8081"
                                         "unit" (dict "ProtectHome" "read-only" "ProtectSystem" "strict"
                                                      "PrivateTmp" "true" "NoNewPrivileges" "true"
                                                      "ReadWritePaths" "/srv/services/demo/data")))
                                  (t :null))))
    (write-json (at workspace ".eval-fixture.json") descriptor)
    (when (hash-table-p vars) (setf (gethash "fixtureEnvironment" vars) descriptor))
    descriptor))

(-> environment-variables (t &optional t)
    hash-table)
(defun environment-variables (descriptor &optional workspace)
  "Environment inherited by the sample's MCP process."
  (let ((env (dict "SKILL_EVAL_DEPENDENCY_ROOT"
                   (namestring (uiop:ensure-directory-pathname
                                (or (uiop:getenv "SKILL_EVAL_DEPENDENCY_ROOT") (root)))))))
    (when (equal (field descriptor "profile") "playwright")
      (dolist (name '("SKILL_EVAL_PYTHON" "SKILL_EVAL_SHELL" "SKILL_EVAL_TOOL_PATH"
                      "PLAYWRIGHT_BROWSER_PATH" "PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH"
                      "PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD" "NIX_PATH" "SKILL_EVAL_NIXPKGS_PATH"))
        (when (uiop:getenv name) (setf (gethash name env) (uiop:getenv name)))))
    (when workspace
      (setf (gethash "SKILL_EVAL_WORKSPACE" env) (namestring (uiop:ensure-directory-pathname workspace))))
    env))

(-> fixture-tool-name (hash-table)
    (or null string))
(defun fixture-tool-name (descriptor)
  (cond ((equal (field descriptor "profile") "repl") "eval_lisp_form")
        ((equal (field descriptor "profile") "deploy") "remote_shell")
        ((equal (field descriptor "profile") "playwright") "run_browser_smoke")))

(-> codex-config (t)
    hash-table)
(defun codex-config (descriptor)
  "Native Codex cli_config injection. Cwd is inherited after native copying."
  (let ((tool (fixture-tool-name descriptor)))
    (if tool
        (dict "mcp_servers"
              (dict "eval_fixture" (dict "command" "ros"
                                         "args" (vector (field descriptor "fixtureScript"))
                                         "env" (environment-variables descriptor)
                                         "startup_timeout_sec" 120 "tool_timeout_sec" 90
                                         "required" (bool t)
                                         "enabled_tools" (vector tool)
                                         ;; Only the prepared fixture tool is approved.
                                         "tools" (dict tool (dict "approval_mode" "approve")))))
        (dict))))

(-> opencode-config (t)
    hash-table)
(defun opencode-config (descriptor)
  "Always select the pinned shell; add sample-local MCP servers when needed."
  (let ((config (dict "shell" (or (field descriptor "shell")
                                  (uiop:getenv "SKILL_EVAL_SHELL")
                                  (error "Missing pinned eval shell; enter nix-shell before running evaluations.")))))
    (when (member (field descriptor "profile") '("repl" "deploy" "playwright") :test #'equal)
      (setf (gethash "mcp" config)
            (dict "eval_fixture"
                  (dict "type" "local" "command" (vector "ros" (field descriptor "fixtureScript"))
                        "cwd" "." "environment" (environment-variables descriptor)
                        "enabled" (bool t) "codemode" (bool nil) "timeout" 90000))))
    config))

(-> cleanup-fixture-server (t)
    t)
(defun cleanup-fixture-server (workspace)
  "Stop only a recorded child whose command names this sample's server source."
  (let ((record (at workspace ".eval-server.pid"))
        (script (namestring (at workspace "server.lisp"))))
    (when (probe-file record)
      (when (sb-posix:s-islnk (sb-posix:stat-mode (sb-posix:lstat (namestring record))))
        (error "Fixture PID record must not be a symlink"))
      (let ((pid (ignore-errors (parse-integer (string-trim '(#\Space #\Tab #\Newline #\Return)
                                                           (uiop:read-file-string record))))))
        (when (and pid (> pid 1))
          (multiple-value-bind (command stderr status)
              (run-command (list "/bin/ps" "-p" (princ-to-string pid) "-o" "command=")
                           :timeout 5 :allow-failure t)
            (declare (ignore stderr))
            (when (and (zerop status) (search script command)
                       (search "sbcl" command))
              (handler-case (sb-posix:kill pid sb-posix:sigterm)
                (sb-posix:syscall-error () nil))
              (write-json (at workspace ".eval-evidence/server-cleanup.json")
                          (dict "pid" pid "script" script "signal" "SIGTERM")))))))))

(-> finalize (t &key (:vars t) (:archive-directory t))
    hash-table)
(defun finalize (workspace &key vars archive-directory)
  "Collect sample-local state after the provider exits and optionally archive it."
  (ensure-evidence-safe workspace)
  (cleanup-fixture-server workspace)
  (let* ((descriptor (or (field vars "fixtureEnvironment")
                         (read-json (at workspace ".eval-fixture.json"))))
         (scenario-name (or (field vars "scenario" "name") (field descriptor "scenario" "name"))))
    (when (and (field vars "environmentProfile")
               (not (equal (profile-name (field vars "environmentProfile")) (field descriptor "profile"))))
      (error "Sample environment profile changed during evaluation"))
    (when (equal (field descriptor "profile") "cache")
      (let ((before (dict)))
        ;; Reconstruct known fixture hashes independently of agent-writable files.
        (dolist (kind '("project" "foreign"))
          (dolist (relative (cache-relative-paths kind scenario-name))
            (unless (and (equal kind "project") (equal scenario-name "heldout-missing-cache"))
              (let ((octets (babel:string-to-octets (format nil "deterministic cached ~A~%" kind) :encoding :utf-8)))
              (setf (gethash (namestring (at workspace relative)) before)
                    (ironclad:byte-array-to-hex-string (ironclad:digest-sequence :sha256 octets)))))))
        (write-json (at workspace ".eval-evidence/cache.json")
                    (dict "before" before "after" (cache-snapshot workspace scenario-name)
                          "projectPaths" (map 'vector (lambda (path) (namestring (at workspace path)))
                                               (cache-relative-paths "project" scenario-name))
                          "foreignPaths" (map 'vector (lambda (path) (namestring (at workspace path)))
                                               (cache-relative-paths "foreign" scenario-name))))))
    (write-json (at workspace ".eval-evidence/environment.json") descriptor)
    (when archive-directory
      (copy-directory (at workspace ".eval-evidence/") (at archive-directory ".eval-evidence/")))
    descriptor))
