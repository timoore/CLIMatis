(in-package #:clim3-zone)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; The parent P of a zone Z may be another zone in which case the Z
;;; is a child of P, or it may be a client (typically a port), in
;;; which Z is the root zone of a hierarchy connected to that client,
;;; or it may be NIL, in which case Z is the root zone of a hierarchy
;;; not currently connected to any client.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Generic function PARENT.
;;;
;;; Return the current parent of the zone. 

(defgeneric parent (zone))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Generic function (SETF PARENT).
;;;
;;; Set the parent of a zone.
;;;
;;; This generic function is part of the internal zone protocols.  It
;;; should not be used directly by applications.  It is called
;;; indirectly as a result of connecting the zone to a client, or as a
;;; result of adding or removing the zone as a child of some other
;;; zone by calling (SETF CHILDREN). 

;;; FIXME: change (setf parent) to set-parent.

(defgeneric (setf parent) (new-parent zone))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Class PARENT-MIXIN.
;;;
;;; This class supplies a slot containing the parent and methods on
;;; PARENT and (SETF PARENT).  This class is a superclass of
;;; STANDARD-CLASS.

(defclass parent-mixin ()
  ((%parent :initarg :parent :initform nil :accessor parent)))