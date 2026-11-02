(assert (= 42 (demo/base:label (make-instance 'demo/base:item))))
(assert (string= "custom" (demo/base:label (demo/src/process:item-label))))
