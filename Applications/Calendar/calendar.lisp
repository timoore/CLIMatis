(cl:in-package #:clim3-calendar)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Date manipulation.

;;; This function is similar to DECODE-UNIVERSAL-TIME, except that it
;;; does not return seconds and minutes; only hour, day, month, year,
;;; and day-of-week. 
(defun dut (universal-time)
  (multiple-value-bind (ss mm hh d m y dow)
      (decode-universal-time universal-time 0)
    (declare (ignore ss mm))
    (values hh d m y dow)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Butcon (name taken from the book by Alan Cooper).
;;;
;;; It is a combination of a button and an icon.  When the pointer
;;; enters the zone, then it becomes darker.  When the button is
;;; pressed when the pointer is in the zone, the buton becomes aremed.
;;; When the button is released and the butcon is armed, then the
;;; action is executed.  The butcon becomes disarmed if the pointer
;;; leaves the zone, so that leaving the zone while the button is
;;; pressed prevents the action from being executed when the button is
;;; released.

(defclass action-button-handler (clim3-port:button-handler)
  ((%armedp :initform nil :accessor armedp)
   (%action :initarg :action :reader action)))

(defmethod clim3-port:handle-button-press
    ((handler action-button-handler) button-code modifiers)
  (declare (ignore button-code modifiers))
  (setf (armedp handler) t))

(defmethod clim3-port:handle-button-release
    ((handler action-button-handler) button-code modifiers)
  (declare (ignore button-code modifiers))
  (when (armedp handler)
    (setf (armedp handler) nil)
    (funcall (action handler))))

(defun butcon (label action)
  (let* ((normal (clim3-layout:sponge))
	 (darker (clim3-graphics:translucent *black* 0.2d0))
	 (wrap (clim3-layout:wrap normal))
	 (handler (make-instance 'action-button-handler :action action)))
    (clim3-layout:pile*
     (clim3-input:visit
      (lambda (zone)
	(declare (ignore zone))
	(setf clim3-port:*button-handler* handler)
	(setf (clim3-zone:children wrap) darker))
      (lambda (zone)
	(declare (ignore zone))
	(setf (armedp handler) nil)
	(setf clim3-port:*button-handler* clim3-port:*null-button-handler*)
	(setf (clim3-zone:children wrap) normal)))
     (clim3-text:text label *toolbar-text-style* *black*)
     wrap)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; GUI.

;;; The value is the current absolute week number, where the first
;;; week of year 1900 is considered to be absolute week number 0.
;;; Lucky for us, the first week of 1900 started on a Monday, and that
;;; is also how ISO 8601 defines the week. 
(defparameter *current-week* 0)

(defparameter *dayname-text-style*
  (clim3-text-style:text-style :free :sans :roman 10))

(defparameter *day-number-text-style*
  (clim3-text-style:text-style :free :sans :bold 20))

(defparameter *hour-text-style*
  (clim3-text-style:text-style :free :fixed :roman 10))

(defparameter *toolbar-text-style*
  (clim3-text-style:text-style :free :fixed :roman 20))

(defparameter *follow-hour-space* 5)

(defparameter *background* (clim3-color:make-color 0.95d0 0.95d0 0.95d0))

(defparameter *black* (clim3-color:make-color 0.0d0 0.0d0 0.0d0))

(defun hour-zone ()
  (clim3-layout:sponge))

(defun vline ()
  (clim3-layout:hbrick
   1
   (clim3-graphics:opaque (clim3-color:make-color 0.3d0 0d0 0d0))))

(defun hline ()
  (clim3-layout:vbrick
   1
   (clim3-graphics:opaque (clim3-color:make-color 0.3d0 0d0 0d0))))

;;; The day numbers are wrap zones, and the child of each such wrap
;;; zone will be modified to reflect what is currently on display. 
(defparameter *day-numbers-of-week*
  (loop repeat 7
	collect (clim3-layout:wrap)))

(defun set-day-numbers ()
  (let ((utime (* *current-week* #.(* 7 24 60 60))))
    (loop for i from 0 below 7
	  for dno = (second (multiple-value-list
			     (dut (+ utime (* i #.(* 24 60 60))))))
	  for wrap in *day-numbers-of-week*
	  do (setf (clim3-zone:children wrap)
		   (clim3-text:text
		    (format nil "~2,'0d" dno)
		    *day-number-text-style*
		    *black*)))))

(defun dayname-zone (name number)
  (clim3-layout:vbrick
   40
   (clim3-layout:vbox*
    (clim3-layout:sponge)
    (clim3-layout:hbox*
     (clim3-layout:hbrick 5)
     (clim3-layout:hbrick
      40
      (clim3-layout:vbox*
       (clim3-layout:sponge)
       number))
     (clim3-layout:hbrick
      40
      (clim3-layout:vbox*
       (clim3-layout:sponge)
       (clim3-text:text name
			*dayname-text-style*
			*black*)
       (clim3-layout:sponge)))
     (clim3-layout:sponge))
    (clim3-layout:vbrick 2))))

(defun day-names ()
  (clim3-layout:hbox 
   (loop for name in '("Mon" "Tue" "Wed" "Thu" "Fri" "Sat" "Sun")
	 for number in *day-numbers-of-week*
	 collect (dayname-zone name number))))

(defun day-zone ()
  (clim3-layout:hbox*
   (clim3-layout:vbox
    (cons (hline)
	  (loop repeat 24
		collect (hour-zone)
		collect (hline))))
   (vline)))

(defun grid-zones ()
  (clim3-layout:hbox
   (cons (vline)
	 (loop repeat 7
	       collect (day-zone)))))

(defun hours ()
  (let ((color (clim3-color:make-color 0.0d0 0.0d0 0.0d0 )))
    (clim3-layout:vbox
     (cons (clim3-text:text "00:00" *hour-text-style* color)
	   (loop for hour from 1 to 24
		 collect (clim3-layout:sponge)
		 collect (clim3-text:text (format nil "~2,'0d:00" (mod hour 24))
					  *hour-text-style* color))))))
(defun time-plane ()
  (clim3-layout:hbox*
   (hours)
   (clim3-layout:hbrick *follow-hour-space*)
   (clim3-layout:vbox*
    (clim3-layout:vbrick 10)
    (grid-zones)
    (clim3-layout:vbrick 10))))

(defun calendar-zones ()
  (clim3-layout:pile*
   (clim3-layout:brick
    1000 700
    (clim3-layout:hbox*
     (clim3-layout:vbox*
      (clim3-layout:hbox*
       (clim3-layout:hbrick 60)
       (day-names))
      (time-plane))
     (clim3-layout:hbrick 10)))
   (clim3-graphics:opaque *background*)))

(defun previous-week ()
  (decf *current-week*)
  (set-day-numbers))

(defun next-week ()
  (incf *current-week*)
  (set-day-numbers))

(defun toolbar ()
  (clim3-layout:pile*
   (clim3-layout:hbox*
    (clim3-layout:sponge)
    (butcon "<" #'previous-week)
    (clim3-layout:hbrick 20)
    (butcon ">" #'next-week)
    (clim3-layout:sponge))
   (clim3-graphics:opaque *background*)))

(defun calendar ()
  (setf *current-week* (floor (get-universal-time) #.(* 7 24 60 60)))
  (set-day-numbers)
  (let ((port (clim3-port:make-port :clx-framebuffer))
	(root (clim3-layout:vbox*
	       (toolbar)
	       (calendar-zones))))
    (clim3-port:connect root port)
    (let ((clim3-port:*new-port* port))
      (loop for keystroke = (clim3-port:read-keystroke)
	    until (eql (car keystroke) #\q)))))