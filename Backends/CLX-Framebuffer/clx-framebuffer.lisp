(in-package #:clim3-clx-framebuffer)

(defparameter *port* nil)
(defparameter *hpos* nil)
(defparameter *vpos* nil)
(defparameter *hstart* nil)
(defparameter *vstart* nil)
(defparameter *hend* nil)
(defparameter *vend* nil)
(defparameter *pixel-array* nil)

(defgeneric call-with-zone (port zone function))

(defclass clx-framebuffer-port (clim3-port:port)
  ((%display :accessor display)
   (%screen :accessor screen)
   (%root :accessor root)
   (%white :accessor white)
   (%black :accessor black)
   (%shift-state :initform nil :accessor shift-state)
   (%zone-entries :initform '() :accessor zone-entries)
   ;; A vector of interpretations.  Each interpretation is a
   ;; short vector of keysyms
   (%keyboard-mapping :initform nil :accessor keyboard-mapping)
   ;; Implement text-style to font mappings instead
   (%font :accessor font)))

(defmethod clim3-port:call-with-zone ((port clx-framebuffer-port) function zone)
  (let ((zone-hpos (clim3-zone:hpos zone))
	(zone-vpos (clim3-zone:vpos zone))
	(zone-width (clim3-zone:width zone))
	(zone-height (clim3-zone:height zone)))
    (let ((new-hpos (+ *hpos* zone-hpos))
	  (new-vpos (+ *vpos* zone-vpos)))
      (let ((new-hstart (max *hstart* new-hpos))
	    (new-vstart (max *vstart* new-vpos))
	    (new-hend (min *hend* (+ new-hpos zone-width)))
	    (new-vend (min *vend* (+ new-vpos zone-height))))
	(when (and (< new-hstart new-hend)
		   (< new-vstart new-vend))
	  (let ((*vpos* new-vpos)
		(*hpos* new-hpos)
		(*hstart* new-hstart)
		(*vstart* new-vstart)
		(*hend* new-hend)
		(*vend* new-vend))
	    (funcall function)))))))
	
(defmethod clim3-port:call-with-area
    ((port clx-framebuffer-port) function hpos vpos width height)
  (let ((new-hpos (+ *hpos* hpos))
	(new-vpos (+ *vpos* vpos)))
    (let ((new-hstart (max *hstart* new-hpos))
	  (new-vstart (max *vstart* new-vpos))
	  (new-hend (min *hend* (+ new-hpos width)))
	  (new-vend (min *vend* (+ new-vpos height))))
      (when (and (< new-hstart new-hend)
		 (< new-vstart new-vend))
	(let ((*vpos* new-vpos)
	      (*hpos* new-hpos)
	      (*hstart* new-hstart)
	      (*vstart* new-vstart)
	      (*hend* new-hend)
	      (*vend* new-vend))
	  (funcall function))))))
	
(defmethod clim3-port:call-with-position
    ((port clx-framebuffer-port) function hpos vpos)
  (let ((new-hpos (+ *hpos* hpos))
	(new-vpos (+ *vpos* vpos)))
    (let ((new-hstart (max *hstart* new-hpos))
	  (new-vstart (max *vstart* new-vpos)))
      (when (and (< new-hstart *hend*)
		 (< new-vstart *vend*))
	(let ((*vpos* new-vpos)
	      (*hpos* new-hpos)
	      (*hstart* new-hstart)
	      (*vstart* new-vstart))
	  (funcall function))))))

(defmethod clim3-port:make-port ((display-server (eql :clx-framebuffer)))
  (let ((port (make-instance 'clx-framebuffer-port)))
    (setf (display port) (xlib:open-default-display))
    (setf (xlib:display-after-function (display port))
	  #'xlib:display-finish-output)
    (setf (screen port) (car (xlib:display-roots (display port))))
    (setf (white port) (xlib:screen-white-pixel (screen port)))
    (setf (black port) (xlib:screen-black-pixel (screen port)))
    (setf (root port) (xlib:screen-root (screen port)))
    (setf (keyboard-mapping port)
	  (let* ((temp (xlib:keyboard-mapping (display port)))
		 (result (make-array (array-dimension temp 0))))
	    (loop for row from 0 below (array-dimension temp 0)
		  do (let ((interpretations (make-array (array-dimension temp 1))))
		       (loop for col from 0 below (array-dimension temp 1)
			     do (setf (aref interpretations col)
				      (aref temp row col)))
		       (setf (aref result row) interpretations)))
	    result))
    ;; Implement text-style to font mappings instead
    (setf (font port) (camfer:make-font 12 100))
    port))

(defclass zone-entry ()
  ((%port :initarg :port :reader port)
   (%zone :initarg :zone :accessor zone)
   (%gcontext :accessor gcontext)
   (%window :accessor window)
   (%pixel-array :accessor pixel-array)
   (%image :accessor image)
   (%pointer-zones :initform '() :accessor pointer-zones)
   (%motion-zones :initform '() :accessor motion-zones)
   (%button-press-zone :initform nil :accessor button-press-zone)
   (%zone-containing-pointer :initform nil :accessor zone-containing-pointer)
   (%prev-pointer-hpos :initform 0 :accessor prev-pointer-hpos)
   (%prev-pointer-vpos :initform 0 :accessor prev-pointer-vpos)))

(defmethod clim3-zone:notify-child-hsprawl-changed
    (zone (port clx-framebuffer-port))
  nil)

(defmethod clim3-zone:notify-child-vsprawl-changed
    (zone (port clx-framebuffer-port))
  nil)

;;; Later, we might try to do something more fancy here, such as
;;; attempting to move the window on the screen.
(defmethod clim3-zone:notify-child-position-changed
    (zone (port clx-framebuffer-port))
  nil)

(defmethod clim3-zone:notify-child-depth-changed
    (zone (port clx-framebuffer-port))
  nil)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Handle pointer position

(defmethod (setf clim3-zone:client) :after
  ((new-client clx-framebuffer-port) (zone clim3-input:motion))
  ;; Find the root zone of the zone.
  (let ((root zone))
    (loop while (clim3-zone:zone-p (clim3-zone:parent root))
	  do (setf root (clim3-zone:parent root)))
    ;; Find the zone entry with that root zone.
    (let ((zone-entry (find root
			    (zone-entries new-client)
			    :key #'zone
			    :test #'eq)))
      (assert (not (null zone-entry)))
      ;; Add the motion zone to the list of motion zones. 
      (push zone (motion-zones zone-entry)))))

(defun handle-motion-zones (zone-entry)
  (multiple-value-bind (hpos vpos same-screen-p)
      (xlib:pointer-position (window zone-entry))
    ;; FIXME: Figure out what to do with same-screen-p
    (declare (ignore same-screen-p))
    ;; Only alert if the pointer is at a different position.
    ;; This optimization is valuable if many consecutive events
    ;; are non-pointer events such as key-press and key-release. 
    (unless (and (= hpos (prev-pointer-hpos zone-entry))
		 (= vpos (prev-pointer-vpos zone-entry)))
      (setf (prev-pointer-hpos zone-entry) hpos)
      (setf (prev-pointer-vpos zone-entry) vpos)
      ;; If any of the zones on the list has a client other than
      ;; the port of this zone-entry, then remove it. 
      (setf (motion-zones zone-entry)
	    (remove (port zone-entry)
		    (motion-zones zone-entry)
		    :key #'clim3-zone:client
		    :test-not #'eq))
      ;; For the remaining ones, call the handler.
      (loop for zone in (motion-zones zone-entry)
	    do (let ((absolute-hpos 0)
		     (absolute-vpos 0)
		     (parent zone))
		 ;; Find the absolute position of the zone.
		 (loop while (clim3-zone:zone-p parent)
		       do (incf absolute-hpos (clim3-zone:hpos parent))
			  (incf absolute-vpos (clim3-zone:vpos parent))
			  (setf parent (clim3-zone:parent parent)))
		 (funcall (clim3-input:handler zone)
			  zone
			  (- hpos absolute-hpos)
			  (- vpos absolute-vpos)))))))

(defun handle-visit (zone-entry)
  (let ((prev (zone-containing-pointer zone-entry)))
    (multiple-value-bind (hpos vpos same-screen-p)
	(xlib:pointer-position (window zone-entry))
      ;; FIXME: Figure out what to do with same-screen-p
      (declare (ignore same-screen-p))
      (labels ((traverse (zone hpos vpos)
		 (unless (or (< hpos 0)
			     (< vpos 0)
			     (> hpos (clim3-zone:width zone))
			     (> vpos (clim3-zone:height zone)))
		   (when (typep zone 'clim3-input:visit)
		     (unless (eq zone prev)
		       (unless (null prev)
			 (funcall (clim3-input:leave-handler prev) prev))
		       (funcall (clim3-input:enter-handler zone) zone)
		       (setf (zone-containing-pointer zone-entry) zone))
		     (return-from handle-visit nil))
		   (clim3-zone:map-over-children-top-to-bottom
		    (lambda (child)
		      (traverse child
				(- hpos (clim3-zone:hpos child))
				(- vpos (clim3-zone:vpos child))))
		    zone))))
	(traverse (zone zone-entry) hpos vpos)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Update zones.

(defgeneric paint (zone port hstart vstart hend vend))

(defun update (zone-entry)
  (with-accessors ((zone zone)
		   (gcontext gcontext)
		   (window window)
		   (pixel-array pixel-array)
		   (image image))
      zone-entry
    (let ((width (xlib:drawable-width window))
	  (height (xlib:drawable-height window)))
      (clim3-zone:impose-size zone width height)
      ;; Make sure the pixmap and the image object have the same
      ;; dimensions as the window.
      (if (and (= width (array-dimension pixel-array 1))
	       (= height (array-dimension pixel-array 0)))
	  (loop for r from 0 below (array-dimension pixel-array 0)
		do (loop for c from 0 below (array-dimension pixel-array 1)
			 do (setf (aref pixel-array r c) #xeeeeeeee)))
	  (progn
	    ;; FIXME: give the right pixel values
	    (setf pixel-array
		  (make-array (list height width)
			      :element-type '(unsigned-byte 32)
			      :initial-element #xeeeeeeee))	  
	    (setf (image zone-entry)
		  (xlib:create-image :bits-per-pixel 32
				     :data (pixel-array zone-entry)
				     :depth 24
				     :width width :height height
				     :format :z-pixmap))))
      ;; Paint.
      (let ((*hpos* 0)
	    (*vpos* 0)
	    (*pixel-array* pixel-array))
	(paint zone *port* 0 0 width height))
      ;; Transfer the image. 
      (xlib::put-image window
		       gcontext
		       image
		       :x 0 :y 0
		       :width width :height height))))

(defmethod clim3-port:connect ((zone clim3-zone:zone)
			       (port clx-framebuffer-port))
  (let ((zone-entry (make-instance 'zone-entry :port port :zone zone)))
    ;; Register this zone entry.  We need to do this right away, because 
    ;; it has to exist when we set the parent of the zone. 
    (push zone-entry (zone-entries port))
    (setf (clim3-zone:parent zone) port)
    (clim3-zone:ensure-hsprawl-valid zone)
    (clim3-zone:ensure-vsprawl-valid zone)
    ;; Ask for a window that has the natural size of the zone.  We may
    ;; not get it, though.
    ;;
    ;; FIXME: take into account the position of the zone
    (setf (window zone-entry)
	  (multiple-value-bind (width height) (clim3-zone:natural-size zone)
	    (xlib:create-window :parent (root port)
				:x 0 :y 0 :width width :height height
				:class :input-output
				:visual :copy
				:background (white port)
				:event-mask
				'(:key-press :key-release
				  :button-motion :button-press :button-release
				  :enter-window :leave-window
				  :exposure
				  :pointer-motion))))
    (xlib:map-window (window zone-entry))
    ;; Create an adequate gcontext for this window.
    (setf (gcontext zone-entry)
	  (xlib:create-gcontext :drawable (window zone-entry)
				:background (white port)
				:foreground (black port)))
    ;; Make the array of the pixels.  The dimensions don't matter,
    ;; because we reallocate it if necessary every time we need to
    ;; draw, so as to reflect the current size of the window.
    (setf (pixel-array zone-entry)
	  (make-array '(0 0)
		      :element-type '(unsigned-byte 32)))
	  
    ;; Make the image object.  Again, the size is of no importance, 
    ;; but we must remember to change it later. 
    (setf (image zone-entry)
	  (xlib:create-image :bits-per-pixel 32
			     :data (pixel-array zone-entry)
			     :depth 24
			     :width 0 :height 0
			     :format :z-pixmap))
    ;; Make sure the window has the right contents.
    (let ((*port* port))
      (update zone-entry))))

(defmethod clim3-port:disconnect (zone (port clx-framebuffer-port))
  (let ((zone-entry (find zone (zone-entries port) :key #'zone)))
    (xlib:free-gcontext (gcontext zone-entry))
    (xlib:destroy-window (window zone-entry))
    (setf (zone-entries port) (remove zone-entry (zone-entries port)))
    (when (null (zone-entries port))
      (xlib:close-display (display port)))
    (setf (clim3-zone:parent zone) nil)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Painting.

(defmethod paint ((zone clim3-zone:atomic-zone)
		  (port clx-framebuffer-port)
		  hstart vstart hend vend)
  (declare (ignore port hstart vstart hend vend))
  nil)

(defmethod paint ((zone clim3-zone:compound-zone)
		  (port clx-framebuffer-port)
		  hstart vstart hend vend)
  (clim3-zone:ensure-hsprawl-valid zone)
  (clim3-zone:ensure-vsprawl-valid zone)
  (clim3-zone:ensure-child-layouts-valid zone)
  (clim3-zone:map-over-children-bottom-to-top
   (lambda (child)
     (let ((chstart (max 0 (- hstart (clim3-zone:hpos child))))
	   (cvstart (max 0 (- vstart (clim3-zone:vpos child))))
	   (chend (min (clim3-zone:width child)
		       (- hend (clim3-zone:hpos child))))
	   (cvend (min (clim3-zone:height child)
		       (- vend (clim3-zone:vpos child)))))
       (when (and (> chend chstart)
		  (> cvend cvstart))
	 (let ((*hpos* (+ *hpos* (clim3-zone:hpos child)))
	       (*vpos* (+ *vpos* (clim3-zone:vpos child))))
	   (paint child port chstart cvstart chend cvend)))))
   zone))

(defmethod clim3-port:paint-pixel
    ((port clx-framebuffer-port) hpos vpos r g b alpha)
  (let* ((pa *pixel-array*)
	 (hp (+ hpos *hpos*))
	 (vp (+ vpos *vpos*))
	 (pixel (aref pa vp hp))
	 (old-r (/ (logand 255 (ash pixel -16)) 255d0))
	 (old-g (/ (logand 255 (ash pixel -8)) 255d0))
	 (old-b (/ (logand 255 pixel) 255d0))
	 (new-r (+ (* r alpha) (* old-r (- 1d0 alpha))))
	 (new-g (+ (* g alpha) (* old-g (- 1d0 alpha))))
	 (new-b (+ (* b alpha) (* old-b (- 1d0 alpha))))
	 (new-pixel (+ (ash (round (* 255 new-r)) 16)
		       (ash (round (* 255 new-g)) 8)
		       (ash (round (* 255 new-b)) 0))))
    (setf (aref pa vp hp) new-pixel)))

;;; Speed up painting of opaque zones by not calling
;;; paint-pixel in an inner loop.
(defun fill-area (color hstart vstart hend vend)
  (let ((pa *pixel-array*)
	(hs (+ hstart *hpos*))
	(vs (+ vstart *vpos*))
	(he (+ hend *hpos*))
	(ve (+ vend *vpos*))
	(pixel (+ (ash (round (* 255 (clim3-color:red color))) 16)
		  (ash (round (* 255 (clim3-color:green color))) 8)
		  (ash (round (* 255 (clim3-color:blue color))) 0))))
    (loop for vpos from vs below ve
	  do (loop for hpos from hs below he
		   do (setf (aref pa vpos hpos) pixel)))))

(defmethod paint ((zone clim3-graphics:opaque)
		  (port clx-framebuffer-port)
		  hstart vstart hend vend)
  (fill-area (clim3-graphics:color zone) hstart vstart hend vend))

;;; Pait an array of opacities.  The bounding rectangle defined by
;;; hstart, hend, vstart, and vend is not outside the array
;;; coordinates.  The special variables *vpos* and *hpos* must have
;;; values that correspond to the absolute upper-left corner of the
;;; position of the mask. 
(defun paint-mask (mask color hstart vstart hend vend)
  (loop for hpos from hstart below hend
	do (loop for vpos from vstart below vend
		 do (clim3-port:paint-pixel
		     *port* hpos vpos
		     (clim3-color:red color)
		     (clim3-color:green color)
		     (clim3-color:blue color)
		     (aref mask vpos hpos)))))

(defmethod paint ((zone clim3-graphics:masked)
		  (port clx-framebuffer-port)
		  hstart vstart hend vend)
  (let* ((opacities (clim3-graphics:opacities zone))
	 (width (min hend (array-dimension opacities 1)))
	 (height (min vend (array-dimension opacities 1))))
    (paint-mask opacities (clim3-graphics:color zone)
		hstart vstart width height)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Text styles.

(defmethod clim3-port:text-style-ascent ((port clx-framebuffer-port)
					 text-style)
  (camfer:ascent (font port)))

(defmethod clim3-port:text-style-descent ((port clx-framebuffer-port)
					  text-style)
  (camfer:descent (font port)))

(defmethod clim3-port:text-ascent ((port clx-framebuffer-port)
				   text-style
				   string)
  (let ((font (font port)))
    (reduce #'min string
	    :key (lambda (char)
		   (camfer:y-offset (camfer:find-glyph font char))))))

(defmethod clim3-port:text-descent ((port clx-framebuffer-port)
				    text-style
				    string)
  (let ((font (font port)))
    (reduce #'max string
	    :key (lambda (char)
		   (+ (array-dimension (camfer:mask (camfer:find-glyph font char)) 0)
		      (camfer:y-offset (camfer:find-glyph font char)))))))

(defun glyph-space (font char1 char2)
  (- (* 2 (camfer::stroke-width font))
     (camfer:kerning font
		     (camfer:find-glyph font char1)
		     (camfer:find-glyph font char2))))

(defun glyph-width (font char)
  (array-dimension (camfer:mask (camfer:find-glyph font char)) 1))

(defmethod clim3-port:text-width ((port clx-framebuffer-port)
				  text-style
				  string)
  (let ((font (font port)))
    (if (zerop (length string))
	0
	(+ (glyph-width font (char string 0))
	   (loop for i from 1 below (length string)
		 sum (+ (glyph-width font (char string i))
			(glyph-space font
				     (char string (1- i))
				     (char string i))))))))

(defmethod paint ((zone clim3-text:text)
		  (port clx-framebuffer-port)
		  hstart vstart hend vend)
  (let ((color (clim3-graphics:color zone))
	(font (font port))
	;; FIXME: either make chars external or move this method
	(string (clim3-text::chars zone))
	(ascent (clim3-port:text-style-ascent port (clim3-text:style zone))))
    (unless (zerop (length string))
      (flet ((paint-glyph (mask pos-x pos-y)
	       ;; pos-x and pos-y are the coordinates of the upper-left
	       ;; corner of the mask relative to the zone
	       (let ((width (array-dimension mask 1))
		     (height (array-dimension mask 0)))
		 (let ((*hpos* (+ *hpos* pos-x))
		       (*vpos* (+ *vpos* pos-y)))
		   (paint-mask mask color
			       (max 0 (- hstart pos-x))
			       (max 0 (- vstart pos-y))
			       (min width (- hend pos-x))
			       (min height (- vend pos-y)))))))
	;; paint the first character
	(paint-glyph (camfer:mask (camfer:find-glyph font (char string 0)))
		     0
		     ;; I don't know why the -1 is necessary
		     (+ -1 ascent (camfer:y-offset (camfer:find-glyph font (char string 0)))))
	(loop with pos-x = 0
	      for i from 1 below (length string)
	      for glyph = (camfer:find-glyph font (char string i))
	      do (progn
		   ;; compute the new x position
		   (incf pos-x
			 (+ (glyph-width font (char string (1- i)))
			    (glyph-space font (char string (1- i)) (char string i))))
		   (paint-glyph (camfer:mask glyph)
				pos-x
				;; I don't know why the -1 is necessary
				(+ -1 ascent (camfer:y-offset glyph)))))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Keycodes, keysyms, etc.

(defparameter *modifier-names*
  #(:shift :lock :control :meta :hyper :super :modifier-4 :modifier-5))

(defparameter +shift-mask+      #b00000001)
(defparameter +lock-mask+       #b00000010)
(defparameter +control-mask+    #b00000100)
(defparameter +meta-mask+       #b00001000)
(defparameter +hyper-mask+      #b00010000)
(defparameter +super-mask+      #b00100000)
(defparameter +modifier-4-mask+ #b01000000)
(defparameter +modifier-5-mask+ #b10000000)

(defun modifier-names (mask)
  (loop for i from 0 below 8
	when (plusp (logand (ash 1 i) mask))
	  collect (aref *modifier-names* i)))

(defun keycode-is-modifier-p (port keycode)
  (some (lambda (modifiers)
	  (member keycode modifiers))
	(multiple-value-list (xlib:modifier-mapping (display port)))))

(defmethod clim3-port:port-standard-key-processor
    ((port clx-framebuffer-port) handler-fun keycode modifiers)
  (if (keycode-is-modifier-p port keycode)
      nil
      (let ((keysyms (vector (xlib:keycode->keysym (display port) keycode 0)
			     (xlib:keycode->keysym (display port) keycode 1)
			     (xlib:keycode->keysym (display port) keycode 2)
			     (xlib:keycode->keysym (display port) keycode 3))))
	(funcall handler-fun
		 (cond ((= (aref keysyms 0) (aref keysyms 1))
			;; FIXME: do this better
			(if (= (aref keysyms 0) 65293)
			    (cons #\Return
				  (modifier-names modifiers))
			    (cons (code-char (aref keysyms 0))
				  (modifier-names modifiers))))
		       ((plusp (logand +shift-mask+ modifiers))
			(cons (code-char (aref keysyms 1))
			      (modifier-names
			       (logandc2 modifiers +shift-mask+))))
		       (t
			(cons (code-char (aref keysyms 0))
			      (modifier-names modifiers))))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Handling events.

(defun handle-other (zone-entry)
  (handle-visit zone-entry)
  (update zone-entry))

;;; Some code factoring is needed here. 
(defun handle-key-press (zone-entry code state hpos vpos)
  (labels ((traverse (zone hpos vpos)
	     (unless (or (< hpos 0)
			 (< vpos 0)
			 (> hpos (clim3-zone:width zone))
			 (> vpos (clim3-zone:height zone)))
	       (when (typep zone 'clim3-input:key)
		 (funcall (clim3-input:press-handler zone) zone code state))
	       (clim3-zone:map-over-children-top-to-bottom
		(lambda (child)
		  (traverse child
			    (- hpos (clim3-zone:hpos child))
			    (- vpos (clim3-zone:vpos child))))
		zone))))
	(traverse (zone zone-entry) hpos vpos))
  (update zone-entry))
  
(defun handle-key-release (zone-entry code state hpos vpos)
  (labels ((traverse (zone hpos vpos)
	     (unless (or (< hpos 0)
			 (< vpos 0)
			 (> hpos (clim3-zone:width zone))
			 (> vpos (clim3-zone:height zone)))
	       (when (typep zone 'clim3-input:key)
		 (funcall (clim3-input:release-handler zone) zone code state))
	       (clim3-zone:map-over-children-top-to-bottom
		(lambda (child)
		  (traverse child
			    (- hpos (clim3-zone:hpos child))
			    (- vpos (clim3-zone:vpos child))))
		zone))))
	(traverse (zone zone-entry) hpos vpos))
  (update zone-entry))
  
(defun handle-button-press (zone-entry code state hpos vpos)
  (labels ((traverse (zone hpos vpos)
	     (unless (or (< hpos 0)
			 (< vpos 0)
			 (> hpos (clim3-zone:width zone))
			 (> vpos (clim3-zone:height zone)))
	       (when (typep zone 'clim3-input:button)
		 (funcall (clim3-input:press-handler zone) zone code state)
		 (setf (button-press-zone zone-entry) zone)
		 (return-from handle-button-press nil))
	       (clim3-zone:map-over-children-top-to-bottom
		(lambda (child)
		  (traverse child
			    (- hpos (clim3-zone:hpos child))
			    (- vpos (clim3-zone:vpos child))))
		zone))))
	(traverse (zone zone-entry) hpos vpos))
  (update zone-entry))
  
(defun handle-button-release (zone-entry code state)
  (let ((zone (button-press-zone zone-entry)))
    (unless (null zone)
      (funcall (clim3-input:release-handler zone) zone code state)))
  (update zone-entry))

(defun event-loop (port)
  (let ((*port* port))
    (xlib:event-case ((display port))
      (:key-press
       (window code state x y)
       (let ((entry (find window (zone-entries port) :test #'eq :key #'window)))
	 (unless (null entry)
	   ;; FIXME: needs code factoring
	   (handle-motion-zones entry)
	   (handle-key-press entry code state x y)))
       nil)
      (:key-release
       (window code state x y)
       (let ((entry (find window (zone-entries port) :test #'eq :key #'window)))
	 (unless (null entry)
	   ;; FIXME: needs code factoring
	   (handle-motion-zones entry)
	   (handle-key-release entry code state x y)))
       nil)
      (:button-press
       (window code state x y)
       (let ((entry (find window (zone-entries port) :test #'eq :key #'window)))
	 (unless (null entry)
	   ;; FIXME: needs code factoring
	   (handle-motion-zones entry)
	   (handle-button-press entry code state x y)))
       nil)
      (:button-release
       (window code state)
       (let ((entry (find window (zone-entries port) :test #'eq :key #'window)))
	 (unless (null entry)
	   (handle-motion-zones entry)
	   (handle-button-release entry code state)))
       nil)
      ((:exposure :motion-notify :enter-notify :leave-notify)
       (window)
       (let ((entry (find window (zone-entries port) :test #'eq :key #'window)))
	 (unless (null entry)
	   (handle-motion-zones entry)
	   (handle-other entry))))
      (t
       ()
       (loop for zone-entry in (zone-entries port)
	     do ;; FIXME: needs code factoring
		(handle-motion-zones zone-entry)
		(handle-other zone-entry))
       nil))))
