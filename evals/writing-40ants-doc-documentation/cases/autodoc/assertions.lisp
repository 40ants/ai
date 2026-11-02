(let ((readme (uiop:read-file-string "README.md")))
  (assert (search "ADD" readme :test #'char-equal))
  (assert (search "Add two numbers" readme :test #'char-equal)))
