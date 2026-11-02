(let ((text "literal ; $(printf BAD) `echo BAD` a b"))
  (assert (string= text (demo/src/process:capture-argument text))))
