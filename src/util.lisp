;;;; JSON, files and bounded subprocesses shared by the harness.
(uiop:define-package #:40ants-ai-evals/src/util
  (:use #:cl)
  (:import-from #:serapeum #:-> #:dict)
  (:export #:field #:true-p #:bool #:decode #:encode #:read-json #:write-json
           #:write-text #:root #:at #:temporary-directory #:remove-directory
           #:run-command #:tree-files #:copy-directory #:digest-tree #:digest-file
           #:unique-id #:now #:sequence-list #:json-equal-p #:safe-relative-p))
(in-package #:40ants-ai-evals/src/util)

(eval-when (:compile-toplevel :load-toplevel :execute) (require :sb-posix))

(-> field (t &rest string)
    t)
(defun field (object &rest keys)
  "Read nested JSON object fields, returning NIL for missing keys."
  (reduce (lambda (value key) (when (hash-table-p value) (gethash key value)))
          keys :initial-value object))

(-> true-p (t)
    boolean)
(defun true-p (value)
  "Recognize Lisp T or a decoded JSON true."
  (not (null (or (eq value t) (eq value 'yason:true)))))

(-> bool (t)
    symbol)
(defun bool (value)
  "Represent a Lisp predicate as an unambiguous JSON boolean."
  (if value 'yason:true 'yason:false))

(-> decode (t)
    t)
(defun decode (input)
  "Decode JSON with distinct arrays, booleans and null values."
  (yason:parse input :json-arrays-as-vectors t :json-booleans-as-symbols t
                     :json-nulls-as-keyword t))

(-> encode (t)
    string)
(defun encode (value)
  "Encode a JSON value into a UTF-8 compatible Lisp string."
  (yason:with-output-to-string* () (yason:encode value)))

(-> read-json (t)
    t)
(defun read-json (file)
  "Read JSON from FILE."
  (decode (uiop:read-file-string file :external-format :utf-8)))

(-> write-text (t string)
    t)
(defun write-text (file text)
  "Write UTF-8 TEXT, creating parent directories."
  (ensure-directories-exist file)
  (with-open-file (stream file :direction :output :if-exists :supersede
                               :if-does-not-exist :create :external-format :utf-8)
    (write-string text stream))
  file)

(-> write-json (t t)
    t)
(defun write-json (file value)
  "Persist a JSON document with a trailing newline."
  (write-text file (format nil "~A~%" (encode value))))

(-> root ()
    pathname)
(defun root ()
  "Return this loaded harness's project root, including archived harnesses."
  (asdf:system-source-directory "40ants-ai-evals"))

(-> at (t string)
    pathname)
(defun at (directory relative)
  "Resolve RELATIVE inside DIRECTORY."
  (merge-pathnames relative (uiop:ensure-directory-pathname directory)))

(-> unique-id ()
    string)
(defun unique-id ()
  "Return a fresh identifier allocated by the operating system."
  (string-downcase
   (uiop:run-program '("uuidgen") :output '(:string :stripped t))))

(-> now ()
    string)
(defun now ()
  "Return an ISO timestamp in UTC."
  (local-time:format-timestring nil (local-time:now) :timezone local-time:+utc-zone+
                               :format local-time:+iso-8601-format+))

(-> temporary-directory (&optional string)
    pathname)
(defun temporary-directory (&optional (prefix "ai-evals"))
  "Allocate a private directory under the operating system's temporary root."
  (uiop:ensure-directory-pathname
   (uiop:run-program
    (list "mktemp" "-d" (namestring (at (uiop:temporary-directory)
                                          (format nil "~A.XXXXXX" prefix))))
    :output '(:string :stripped t))))

(-> remove-directory (t)
    t)
(defun remove-directory (directory)
  "Remove a directory created or owned by the harness."
  (uiop:delete-directory-tree (uiop:ensure-directory-pathname directory)
                              :validate t :if-does-not-exist :ignore))

(-> run-command (list &key (:directory t) (:input (or null string))
                     (:timeout real) (:log-prefix t) (:allow-failure t))
    (values string string integer &optional))
(defun run-command (argv &key (directory (root)) input (timeout 120)
                             log-prefix allow-failure)
  "Run ARGV without a shell; capture logs and kill timed-out subprocesses."
  (let* ((scratch (temporary-directory "ai-command"))
         (out (if log-prefix (pathname (format nil "~A.stdout.log" log-prefix))
                  (at scratch "stdout")))
         (err (if log-prefix (pathname (format nil "~A.stderr.log" log-prefix))
                  (at scratch "stderr")))
         (in (at scratch "stdin"))
         (process nil))
    (unwind-protect
         (progn
           (when input (write-text in input))
           (ensure-directories-exist out)
           (setf process
                 (uiop:launch-program argv :directory directory
                   :input (when input in) :output out :error-output err
                   :if-output-exists :supersede :if-error-output-exists :supersede))
           (let* ((status (handler-case
                             (sb-ext:with-timeout timeout (uiop:wait-process process))
                           (sb-ext:timeout ()
                             (uiop:terminate-process process :urgent t)
                             (uiop:wait-process process)
                             (error "Subprocess timeout (~As): ~A" timeout (first argv)))))
                  (stdout (uiop:read-file-string out :external-format :utf-8))
                  (stderr (uiop:read-file-string err :external-format :utf-8)))
             (unless (or allow-failure (zerop status))
               (error "~A exited ~D: ~A" (first argv) status stderr))
             (values stdout stderr status)))
      (when (and process (uiop:process-alive-p process))
        (uiop:terminate-process process :urgent t)
        (uiop:wait-process process))
      (remove-directory scratch))))

(-> tree-files (t &key (:exclude list))
    list)
(defun tree-files (directory &key exclude)
  "Return sorted relative files; reject symlinks before following directories."
  (labels ((visit (dir)
             (loop for entry in (sort (uiop:directory* (at dir "*.*") :resolve-symlinks nil)
                                   #'string< :key (lambda (path)
                                                    (string-right-trim "/" (namestring path))))
                   for stat = (sb-posix:lstat (string-right-trim "/" (namestring entry)))
                   for name = (car (last (uiop:split-string
                                         (string-right-trim "/" (namestring entry))
                                         :separator "/")))
                   unless (member name exclude :test #'string=)
                     append (cond
                              ((sb-posix:s-islnk (sb-posix:stat-mode stat))
                               (error "Snapshot contains symlink: ~A" entry))
                              ((uiop:directory-pathname-p entry) (visit entry))
                              (t (list (enough-namestring entry directory)))))))
    (visit (uiop:ensure-directory-pathname directory))))

(-> copy-directory (t t)
    t)
(defun copy-directory (source destination)
  "Copy a plain tree without following symbolic links."
  (ensure-directories-exist (at destination ".keep"))
  (dolist (relative (tree-files source))
    (let ((target (at destination relative)))
      (ensure-directories-exist target)
      (uiop:copy-file (at source relative) target)))
  destination)

(-> digest-file (t)
    string)
(defun digest-file (file)
  "Return a file's SHA-256 digest."
  (ironclad:byte-array-to-hex-string (ironclad:digest-file :sha256 file)))

(-> file-octets (t)
    (simple-array (unsigned-byte 8) (*)))
(defun file-octets (file)
  (with-open-file (stream file :element-type '(unsigned-byte 8))
    (let ((bytes (make-array (file-length stream) :element-type '(unsigned-byte 8))))
      (read-sequence bytes stream)
      bytes)))

(-> digest-tree (t)
    string)
(defun digest-tree (directory)
  "Hash sorted relative paths and bytes using the legacy runner's format."
  (let ((digest (ironclad:make-digest :sha256)))
    (dolist (relative (tree-files directory))
      (ironclad:update-digest digest (babel:string-to-octets relative :encoding :utf-8))
      (ironclad:update-digest digest (make-array 1 :element-type '(unsigned-byte 8)
                                                :initial-element 0))
      (ironclad:update-digest digest (file-octets (at directory relative)))
      (ironclad:update-digest digest (make-array 1 :element-type '(unsigned-byte 8)
                                                :initial-element 0)))
    (ironclad:byte-array-to-hex-string (ironclad:produce-digest digest))))

(-> sequence-list (t)
    list)
(defun sequence-list (value)
  "Convert a JSON array to a list; treat absent/null arrays as empty."
  (if (and (not (stringp value)) (typep value 'sequence)) (coerce value 'list) nil))

(-> json-equal-p (t t)
    boolean)
(defun json-equal-p (left right)
  "Compare JSON values independently of object key order."
  (cond ((and (hash-table-p left) (hash-table-p right))
         (and (= (hash-table-count left) (hash-table-count right))
              (loop for key being the hash-keys of left
                    always (multiple-value-bind (value found) (gethash key right)
                             (and found (json-equal-p (gethash key left) value))))))
        (t (equalp left right))))

(-> safe-relative-p (string)
    boolean)
(defun safe-relative-p (relative)
  "Recognize portable fixture paths confined to a workspace."
  (and (plusp (length relative))
       (not (uiop:absolute-pathname-p relative))
       (not (find #\\ relative))
       (notany (lambda (part) (member part '("" "." "..") :test #'string=))
               (uiop:split-string relative :separator "/"))))
