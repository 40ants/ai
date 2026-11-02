(let ((readme (uiop:read-file-string "README.md")))
  (assert (search "deterministic queue" readme :test #'char-equal))
  (assert (> (length readme) 100)))
