;;;; Declarative suite discovery; legacy archives retain their original suite identity.
(uiop:define-package #:40ants-ai-evals/suites
  (:use #:cl)
  (:import-from #:serapeum #:-> #:dict)
  (:import-from #:40ants-ai-evals/util #:field #:root #:at #:read-json #:sequence-list
                #:safe-relative-p)
  (:export #:catalog #:find-suite #:suite-path #:selected-suites #:describe-suites))
(in-package #:40ants-ai-evals/suites)

(-> catalog ()
    list)
(defun catalog ()
  "Read the project catalog, accepting old snapshots without a catalog."
  (let* ((file (at (root) "evals/suites.json"))
         (entries (if (probe-file file) (sequence-list (read-json file))
                      (list (dict "id" "writing-common-lisp" "skillName" "writing-common-lisp"
                                  "skillPath" "plugins/common-lisp-skills/skills/writing-common-lisp/"
                                  "config" "evals/writing-common-lisp/promptfooconfig.json"
                                  "environmentProfile" "lisp"))))
         (seen (make-hash-table :test 'equal)))
    (dolist (entry entries)
      (let ((id (field entry "id")))
        (unless (and (stringp id) (safe-relative-p id) (not (find #\/ id))
                     (not (gethash id seen)))
          (error "Invalid or duplicate suite ID: ~S" id))
        (setf (gethash id seen) t)
        (dolist (key '("skillPath" "config"))
          (let ((path (string-right-trim "/" (or (field entry key) ""))))
            (unless (safe-relative-p path) (error "Unsafe suite ~A path: ~A" id path))))
        (unless (equal id (field entry "skillName"))
          (error "Suite ~A must name its native skill exactly" id))))
    entries))

(-> find-suite (&optional (or null string))
    hash-table)
(defun find-suite (&optional id)
  "Resolve a suite, defaulting to the original writing-common-lisp suite."
  (or (find (or id "writing-common-lisp") (catalog) :key (lambda (entry) (field entry "id"))
            :test #'equal)
      (error "Unknown suite: ~A" id)))

(-> suite-path (&optional (or null string))
    string)
(defun suite-path (&optional id)
  "Return the suite configuration's relative directory."
  (namestring (uiop:pathname-directory-pathname (field (find-suite id) "config"))))

(-> selected-suites (hash-table)
    list)
(defun selected-suites (flags)
  (let ((name (field flags "suite")))
    (if (equal name "all") (catalog) (list (find-suite name)))))

(-> describe-suites ()
    vector)
(defun describe-suites ()
  "Describe case counts without evaluating tools or contacting a model."
  (map 'vector
       (lambda (entry)
         (let* ((id (field entry "id"))
                (file (at (at (root) (suite-path id)) "cases.json"))
                (cases (when (probe-file file) (sequence-list (read-json file)))))
           (dict "id" id "skillPath" (field entry "skillPath")
                 "environmentProfile" (field entry "environmentProfile")
                 "cases" (length cases)
                 "holdout" (count "holdout" cases :test #'equal
                                  :key (lambda (case) (field case "vars" "group"))))))
       (catalog)))
