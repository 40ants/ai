(let ((text (uiop:read-file-string "ChangeLog.md")))
  (assert (search "0.2.0" text))
  (assert (search "third" text :test #'char-equal)))
