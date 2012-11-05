(defpackage #:clim3-port
  (:use #:common-lisp)
  (:export
   #:port
   #:make-port
   #:connect
   #:disconnect
   #:text-ascent
   #:text-descent
   #:text-width
   #:text-style-ascent
   #:text-style-descent
   #:port-standard-key-processor
   #:standard-key-processor
   #:paint-pixel
   #:with-zone #:call-with-zone
   #:with-area #:call-with-area
   #:with-pixel #:call-with-pixel
   #:*new-port*
   #:new-paint-image
   #:new-paint-pixel
   #:new-port-paint-pixel
   #:new-paint-mask
   #:new-port-paint-mask
   #:new-paint-text
   #:new-port-paint-text
   #:new-paint-opaque
   #:new-port-paint-opaque
   #:new-paint-trapezoids
   #:new-port-paint-trapezoids
   ))
  