;;;; Confined case inputs and byte-oriented fixture baselines.
(uiop:define-package #:40ants-ai-evals/case-resources
    (:use #:cl)
  (:import-from #:asdf)
  (:import-from #:babel)
  (:import-from #:ironclad)
  (:import-from #:sb-posix)
  (:import-from #:serapeum #:-> #:dict)
  (:import-from #:40ants-ai-evals/suites #:suite-path)
  (:import-from #:40ants-ai-evals/util
                #:field #:root #:at #:safe-relative-p #:tree-files #:digest-file #:encode
                #:write-text #:sequence-list)
  (:export #:*inputs-root* #:*sample-directory* #:resolve-resource #:fixture-manifest
           #:baseline-manifest #:sample-manifest #:copy-fixtures #:file-metadata
           #:metadata-equal-p #:manifest-equal-p #:product-path-p #:restore-sample
           #:input-fingerprint #:validate-fixtures #:file-references))
(in-package #:40ants-ai-evals/case-resources)

(defvar *inputs-root* nil "Input tree for this operation; NIL uses the loaded harness.")
(defvar *sample-directory* nil "Trusted archive directory of the sample being graded.")

(-> resource-error (hash-table t string)
    t)
(defun resource-error (vars reference message)
  (error "Suite ~A, case ~A, resource ~S: ~A"
         (or (field vars "suite") "writing-common-lisp")
         (or (field vars "id") "<unknown>") reference message))

(-> resolve-resource (hash-table string &key (:directory boolean))
    pathname)
(defun resolve-resource (vars reference &key directory)
  "Resolve a suite-relative input, rejecting symlinks in every path component."
  (let* ((relative (if directory (string-right-trim "/" reference) reference))
         (suite (suite-path (field vars "suite")))
         (base (uiop:ensure-directory-pathname (or *inputs-root* (root)))))
    (unless (safe-relative-p relative)
      (resource-error vars reference "expected a confined relative path"))
    (let* ((parts (uiop:split-string (concatenate 'string suite relative) :separator "/"))
           (path base))
      (loop for tail on parts for part = (first tail) do
            (setf path (at path part))
            (let ((stat (handler-case (sb-posix:lstat (namestring path))
                          (error () (resource-error vars reference "path does not exist")))))
              (when (sb-posix:s-islnk (sb-posix:stat-mode stat))
                (resource-error vars reference "symbolic links are not allowed"))
              (unless (if (or (rest tail) directory)
                          (sb-posix:s-isdir (sb-posix:stat-mode stat))
                          (sb-posix:s-isreg (sb-posix:stat-mode stat)))
                (resource-error vars reference "unexpected file type")))
            (when (or (rest tail) directory)
              (setf path (uiop:ensure-directory-pathname path))))
      path)))

(-> file-metadata (t)
    hash-table)
(defun file-metadata (path)
  "Describe regular-file bytes and executable bits without following symlinks."
  (let ((stat (sb-posix:lstat (namestring path))))
    (unless (sb-posix:s-isreg (sb-posix:stat-mode stat))
      (error "Expected a regular file: ~A" path))
    (dict "size" (sb-posix:stat-size stat) "sha256" (digest-file path)
          "executableBits" (logand #o111 (sb-posix:stat-mode stat)))))

(-> text-metadata (string)
    hash-table)
(defun text-metadata (text)
  (let ((bytes (babel:string-to-octets text :encoding :utf-8)))
    ;; Historical inline fixtures did not capture executable permissions.
    (dict "size" (length bytes) "sha256"
          (ironclad:byte-array-to-hex-string (ironclad:digest-sequence :sha256 bytes)))))

(-> validate-fixture-size (hash-table string t)
    t)
(defun validate-fixture-size (vars reference path)
  (let* ((metadata (file-metadata path)) (size (field metadata "size")))
    (when (> size (* 20 1024 1024))
      (resource-error vars reference "fixture exceeds the 20 MiB artifact limit"))
    (when (> size (* 2 1024 1024))
      (let* ((bytes (40ants-ai-evals/util::file-octets path))
             (text (unless (or (find 0 bytes)
                               (and (>= size 8)
                                    (equalp (subseq bytes 0 8) #(137 80 78 71 13 10 26 10))))
                     (handler-case (babel:octets-to-string bytes :encoding :utf-8 :errorp t)
                       (error () nil)))))
        (when text (resource-error vars reference "text fixture exceeds the 2 MiB text limit"))))
    metadata))

(-> fixture-manifest (hash-table &optional t)
    hash-table)
(defun fixture-manifest (vars &optional (spec (field vars "fixtures")))
  "Read a fixture directory, or normalize a historical inline fixture object."
  (let ((manifest (dict)))
    (cond
      ((null spec))
      ((hash-table-p spec)
       (maphash (lambda (relative content)
                  (unless (and (stringp relative) (safe-relative-p relative) (stringp content))
                    (resource-error vars relative "invalid historical text fixture"))
                  (setf (gethash relative manifest) (text-metadata content))) spec))
      ((stringp spec)
       (let ((directory (resolve-resource vars spec :directory t)))
         (handler-case
             (dolist (relative (tree-files directory))
               (setf (gethash relative manifest)
                     (validate-fixture-size vars (concatenate 'string spec "/" relative)
                                            (at directory relative))))
           (error (condition) (resource-error vars spec (princ-to-string condition))))))
      (t (resource-error vars spec "fixtures must be a directory path or a legacy object")))
    manifest))

(-> validate-fixtures (hash-table)
    hash-table)
(defun validate-fixtures (vars)
  "Validate fixture inputs before any paid evaluation starts."
  (fixture-manifest vars))

(-> copy-regular-file (t t)
    t)
(defun copy-regular-file (source target)
  (let ((metadata (file-metadata source)))
    (ensure-directories-exist target)
    (uiop:copy-file source target)
    (sb-posix:chmod (namestring target) (logior #o600 (field metadata "executableBits")))
    target))

(-> copy-fixtures (hash-table t)
    t)
(defun copy-fixtures (vars workspace)
  "Copy inputs from the selected input tree without decoding or following links."
  (let ((spec (field vars "fixtures")))
    (validate-fixtures vars)
    (cond
      ((hash-table-p spec)
       (maphash (lambda (relative content) (write-text (at workspace relative) content)) spec))
      ((stringp spec)
       (let ((directory (resolve-resource vars spec :directory t)))
         (dolist (relative (tree-files directory))
           (copy-regular-file (at directory relative) (at workspace relative)))))))
  workspace)

(-> baseline-manifest (hash-table &optional t)
    hash-table)
(defun baseline-manifest (vars &optional (spec (field vars "fixtures")))
  "Use the frozen baseline including supervisor-added files, or normalize old vars."
  (if (and (hash-table-p (field vars "fixtureManifest"))
           (or (equalp spec (field vars "fixtures"))
               (and (not (field vars "fixtures"))
                    (hash-table-p spec) (zerop (hash-table-count spec)))))
      (field vars "fixtureManifest")
      (fixture-manifest vars spec)))

(-> product-path-p (string)
    boolean)
(defun product-path-p (path)
  "Exclude evaluation machinery from product file comparisons."
  (not (or (member path '(".eval-fixture.json" ".eval-environment.json" ".eval-shell-env"
                          ".eval-cache-before.json" "opencode.json"
                          ".eval-evidence" ".eval-cache") :test #'equal)
           (uiop:string-prefix-p ".eval-evidence/" path)
           (uiop:string-prefix-p ".eval-cache/" path)
           (some (lambda (part) (member part '(".git" ".agents" ".opencode") :test #'equal))
                 (uiop:split-string path :separator "/")))))

(-> sample-manifest (hash-table)
    hash-table)
(defun sample-manifest (sample)
  "Describe product evidence, retaining compatibility with text-only archives."
  (let ((result (dict)))
    (when (hash-table-p (field sample "files"))
      (maphash (lambda (path text)
                 (when (product-path-p path) (setf (gethash path result) (text-metadata text))))
               (field sample "files")))
    (when (hash-table-p (field sample "artifacts"))
      (maphash (lambda (path metadata)
                 (when (product-path-p path) (setf (gethash path result) metadata)))
               (field sample "artifacts")))
    result))

(-> metadata-equal-p (t t)
    boolean)
(defun metadata-equal-p (expected actual)
  "Compare byte identity and permissions when that evidence is available."
  (and (hash-table-p expected) (hash-table-p actual)
       (not (equal "symlink" (field actual "kind")))
       (equal (field expected "sha256") (field actual "sha256"))
       (eql (field expected "size") (field actual "size"))
       (or (not (nth-value 1 (gethash "executableBits" expected)))
           (and (nth-value 1 (gethash "executableBits" actual))
                (eql (field expected "executableBits") (field actual "executableBits"))))))

(-> manifest-equal-p (hash-table hash-table)
    boolean)
(defun manifest-equal-p (expected actual)
  "Compare complete file sets, bytes and captured executable permissions."
  (and (= (hash-table-count expected) (hash-table-count actual))
       (loop for path being the hash-keys of expected
             always (metadata-equal-p (field expected path) (field actual path)))))

(-> restore-sample (hash-table t)
    t)
(defun restore-sample (sample destination)
  "Restore regular candidate files from verified archives, including binary inputs."
  (let ((artifacts (field sample "artifacts")))
    (when (hash-table-p (field sample "files"))
      (maphash (lambda (relative text)
                 (unless (safe-relative-p relative) (error "Unsafe candidate path: ~A" relative))
                 (write-text (at destination relative) text)) (field sample "files")))
    (when (hash-table-p artifacts)
      (maphash
       (lambda (relative metadata)
         (unless (safe-relative-p relative) (error "Unsafe candidate path: ~A" relative))
         (when (equal "symlink" (field metadata "kind"))
           (error "Runtime checks cannot restore candidate symlink: ~A" relative))
         (let ((target (at destination relative)))
           (when *sample-directory*
             (let ((source (at *sample-directory*
                               (concatenate 'string
                                            (if (equal "text" (field metadata "kind"))
                                                "files/" "artifacts/") relative))))
               ;; Validate every parent as well as the leaf before copying.
               (let ((cursor (uiop:ensure-directory-pathname *sample-directory*)))
                 (dolist (part (uiop:split-string (enough-namestring source cursor) :separator "/"))
                   (setf cursor (at cursor part))
                   (when (sb-posix:s-islnk (sb-posix:stat-mode (sb-posix:lstat (namestring cursor))))
                     (error "Archived candidate path contains a symlink: ~A" relative))
                   (unless (equal cursor source)
                     (setf cursor (uiop:ensure-directory-pathname cursor)))))
               (unless (metadata-equal-p metadata (file-metadata source))
                 (error "Corrupt archived candidate: ~A" relative))
               (copy-regular-file source target)))
           (unless (probe-file target)
             (error "Binary candidate evidence requires an archive directory: ~A" relative))
           (when (nth-value 1 (gethash "executableBits" metadata))
             (sb-posix:chmod (namestring target) (logior #o600 (field metadata "executableBits"))))))
       artifacts)))
  destination)

(-> file-references (hash-table)
    list)
(defun file-references (vars)
  "Read a resource set or a historical array without expanding Promptfoo cases."
  (let ((references (field vars "fileResources")))
    (if (hash-table-p references)
        (loop for path being the hash-keys of references collect path)
        (sequence-list references))))

(-> input-fingerprint (list &key (:fixtures-only boolean))
    string)
(defun input-fingerprint (cases &key fixtures-only)
  "Hash actual case resource bytes and modes from the selected input tree."
  (let ((digest (ironclad:make-digest :sha256)))
    (labels ((feed (value)
               (ironclad:update-digest digest (babel:string-to-octets (encode value) :encoding :utf-8)))
             (feed-table (table)
               (dolist (path (sort (loop for key being the hash-keys of table collect key) #'string<))
                 (feed (list path (field table path))))))
      (dolist (case cases)
        (let ((vars (field case "vars")))
          (feed (list (field vars "id") (field vars "scenario")))
          (feed-table (fixture-manifest vars))
          (unless fixtures-only
            (dolist (reference (sort (file-references vars) #'string<))
              (feed (list reference (file-metadata (resolve-resource vars reference)))))))))
    (ironclad:byte-array-to-hex-string (ironclad:produce-digest digest))))
