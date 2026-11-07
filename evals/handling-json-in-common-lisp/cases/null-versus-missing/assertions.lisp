(assert (demo/src/json:null-field-p (serapeum:dict "x" :null) "x"))
(assert (not (demo/src/json:null-field-p (serapeum:dict "x" nil) "x")))
(assert (not (demo/src/json:null-field-p (serapeum:dict) "x")))
