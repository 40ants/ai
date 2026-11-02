(require :asdf)
(require :sb-bsd-sockets)
(require :sb-posix)
(let ((listener (make-instance 'sb-bsd-sockets:inet-socket :type :stream :protocol :tcp)))
  (setf (sb-bsd-sockets:sockopt-reuse-address listener) t)
  (sb-bsd-sockets:socket-bind listener #(127 0 0 1) 0)
  (sb-bsd-sockets:socket-listen listener 5)
  (with-open-file (out ".eval-server.pid" :direction :output :if-exists :supersede)
    (format out "~D~%" (sb-posix:getpid)))
  (multiple-value-bind (address port) (sb-bsd-sockets:socket-name listener)
    (declare (ignore address))
    (with-open-file (out ".fixture-server.port" :direction :output :if-exists :supersede)
      (format out "~D~%" port)))
  (loop
    (let* ((client (sb-bsd-sockets:socket-accept listener))
           (stream (sb-bsd-sockets:socket-make-stream client :input t :output t :buffering :none :external-format :utf-8)))
      (unwind-protect
           (handler-case
               (let* ((request (read-line stream nil ""))
                      (path (second (uiop:split-string request :separator " ")))
                      (api (equal path "/api/message"))
                      (payload (if api "{\"message\":\"HTTP fixture loaded\"}"
                                   (uiop:read-file-string "index.html"))))
                 (loop for line = (read-line stream nil "")
                       until (zerop (length (string-trim '(#\Return #\Newline) line))))
                 (format stream "HTTP/1.1 200 OK~C~CContent-Type: ~A~C~CContent-Length: ~D~C~CConnection: close~C~C~C~C~A"
                         #\Return #\Newline (if api "application/json" "text/html")
                         #\Return #\Newline (length payload) #\Return #\Newline
                         #\Return #\Newline #\Return #\Newline payload)
                 (finish-output stream))
             (error () nil))
        (ignore-errors (close stream))
        (ignore-errors (sb-bsd-sockets:socket-close client))))))
