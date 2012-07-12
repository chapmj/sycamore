;;;; -*- Lisp -*-
;;;;
;;;; Copyright (c) 2012, Georgia Tech Research Corporation
;;;; All rights reserved.
;;;;
;;;; Author(s): Neil T. Dantam <ntd@gatech.edu>
;;;; Georgia Tech Humanoid Robotics Lab
;;;; Under Direction of Prof. Mike Stilman
;;;;
;;;; This file is provided under the following "BSD-style" License:
;;;;
;;;;   Redistribution and use in source and binary forms, with or
;;;;   without modification, are permitted provided that the following
;;;;   conditions are met:
;;;;   * Redistributions of source code must retain the above
;;;;     copyright notice, this list of conditions and the following
;;;;     disclaimer.
;;;;   * Redistributions in binary form must reproduce the above
;;;;     copyright notice, this list of conditions and the following
;;;;     disclaimer in the documentation and/or other materials
;;;;     provided with the distribution.
;;;;
;;;;   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
;;;;   CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
;;;;   INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
;;;;   MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
;;;;   DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
;;;;   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
;;;;   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
;;;;   NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
;;;;   LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
;;;;   HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
;;;;   CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
;;;;   OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
;;;;   EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


(in-package :sycamore)

;;;;;;;;;;;
;;  AVL  ;;
;;;;;;;;;;;

;; SEE: Adams, Stephen. Implementing Sets Efficiantly in a Functional Language

;; All leaf nodes are simple vectors.
;; We can assume a binary tree node will never have NULL left/right values

(defconstant +avl-tree-max-array-length+ 8)
(defparameter +avl-tree-rebalance-log+ 2)  ;; power two difference for rebalancing

(defstruct (avl-tree
             (:include binary-tree)
             (:constructor %make-avl-tree (weight left value right)))
  (weight 0 :type fixnum))

(defun avl-tree-count (tree)
  (etypecase tree
    (avl-tree (avl-tree-weight tree))
    (simple-vector (length tree))
    (null 0)))


(defun make-avl-tree (left value right)
  (%make-avl-tree (the fixnum (+ 1
                                 (avl-tree-count left)
                                 (avl-tree-count right)))
                  left value right))

(defmacro with-avl-tree((left value right &optional weight) tree &body body)
  (alexandria:with-gensyms (tree-sym)
    `(let ((,tree-sym ,tree))
       (let ((,left (binary-tree-left ,tree-sym))
             (,value (binary-tree-value ,tree-sym))
             (,right (binary-tree-right ,tree-sym))
             ,@(when weight `(,weight (avl-tree-weight ,tree-sym))))
         ,@body))))


(defun avl-tree-list (tree) (map-binary-tree :inorder 'list #'identity tree))

(defun right-avl-tree (constructor left value right)
  "Right rotation"
  (declare (type function constructor))
  (funcall constructor
           (binary-tree-left left)
           (binary-tree-value left)
           (funcall constructor
                    (binary-tree-right left)
                    value
                    right)))

(defun left-avl-tree (constructor left value right)
  "Left rotation"
  (declare (type function constructor))
  (funcall constructor
           (funcall constructor
                    left
                    value
                    (binary-tree-left right))
           (binary-tree-value right)
           (binary-tree-right right)))

(defun left-right-avl-tree (constructor left value right)
  "Right rotation then left rotation"
  (declare (type function constructor))
  (funcall constructor
           (funcall constructor left
                    value
                    (binary-tree-left-left right))
           (binary-tree-value-left right)
           (funcall constructor
                    (binary-tree-right-left right)
                    (binary-tree-value right)
                    (binary-tree-right right))))

(defun right-left-avl-tree (constructor left value right)
  "Left rotation then right rotation"
  (declare (type function constructor))
  (funcall constructor
           (funcall constructor
                    (binary-tree-left left)
                    (binary-tree-value left)
                    (binary-tree-left-right left))
           (binary-tree-value-right left)
           (funcall constructor
                    (binary-tree-right-right left)
                    value
                    right)))


;; TODO: specialize this function based on adding/subtracting from left/right
(defun balance-general-avl-tree (constructor rebalance-log left value right)
  (declare (type function constructor))
  ;;(format t "~&Balance-avl-tree~&")
  (let* ((w-l (avl-tree-count left))
         (w-r (avl-tree-count right))
         (w-t (+ w-l w-r 1)))
    (cond
      ;; condense to one vector
      ((<= w-t +avl-tree-max-array-length+)
       (let ((i -1)
             (array (make-array w-t)))
         (labels ((gather (x) (setf (aref array (incf i)) x)))
           (map-binary-tree :inorder nil #'gather left)
           (gather value)
           (map-binary-tree :inorder nil #'gather right))
         array))
      ;; TODO: maybe combine two vectors
      ;; left too tall
      ((and (> w-l (ash w-r rebalance-log))
            (avl-tree-p left))
       (if (and (> (avl-tree-count (binary-tree-right left))
                   (avl-tree-count (binary-tree-left left)))
                (avl-tree-p (binary-tree-right left)))
           (right-left-avl-tree constructor left value right)
           (right-avl-tree constructor left value right)))
      ;; right too tall
      ((and (> w-r (ash w-l rebalance-log))
            (avl-tree-p right))
       (if (and (< (avl-tree-count (binary-tree-right right))
                   (avl-tree-count (binary-tree-left right)))
                (avl-tree-p (binary-tree-left right)))
           (left-right-avl-tree constructor left value right)
           (left-avl-tree constructor left value right)))
      ;; close enough
      (t
       (funcall constructor left value right)))))

(defun balance-avl-tree (left value right)
  (balance-general-avl-tree #'make-avl-tree +avl-tree-rebalance-log+ left value right))

(defun avl-tree-smaller (tree-1 tree-2)
  "Is `tree-1' shorter than `tree-2'?"
  (cond
    ((null tree-2) nil)
    ((null tree-1) t)
    (t (< (avl-tree-count tree-1)
          (avl-tree-count tree-2)))))

(defmacro cond-avl-tree-compare ((value tree compare)
                                 null-case less-case equal-case greater-case)
  "Compare VALUE to value of TREE and execute the corresponding case."
  (alexandria:with-gensyms (c tree-sym)
    `(let ((,tree-sym ,tree))
       (if (null ,tree-sym)
           ,null-case
           (let ((,c (funcall ,compare ,value (binary-tree-value ,tree-sym))))
             (declare (type fixnum ,c))
             (cond
               ((< ,c 0) ,less-case)
               ((> ,c 0) ,greater-case)
               (t ,equal-case)))))))

(defmacro cond-avl-tree-vector-compare ((value tree compare)
                                        null-case vector-case less-case equal-case greater-case)
  "Compare VALUE to value of TREE and execute the corresponding case."
  (alexandria:with-gensyms (c tree-sym)
    `(let ((,tree-sym ,tree))
       (etypecase ,tree-sym
         (avl-tree
          (let ((,c (funcall ,compare ,value (binary-tree-value ,tree-sym))))
            (declare (type fixnum ,c))
            (cond
              ((< ,c 0) ,less-case)
              ((> ,c 0) ,greater-case)
              (t ,equal-case))))
         (simple-vector ,vector-case)
         (null ,null-case)))))


;; (defmacro cond-avl-tree-heights ((left right)
;;                                  null-left-case null-right-case left-short-case equiv-case right-short-case)
;;   (alexandria:with-gensyms (left-sym right-sym)
;;     `(let ((,left-sym ,left)
;;            (,right-sym ,right))
;;        (cond
;;          ((null ,left-sym)
;;           ,null-left-case)
;;          ((null ,right-sym)
;;           ,null-right-case)
;;          ((< (avl-tree-count ,left-sym)
;;              (ash (avl-tree-count ,right-sym) 2)) ;; FIXME
;;           ,left-short-case)
;;          ((< (avl-tree-count ,right-sym)
;;              (ash (avl-tree-count ,left-sym) 2)) ;; FIXME
;;           ,right-short-case)
;;          (t ,equiv-case)))))

(defun avl-tree-insert-vector (tree value compare)
  (declare (type simple-vector tree))
  (multiple-value-bind (i present)
      (array-tree-insert-position tree value compare)
    (declare (type fixnum i))
    (let* ((n (length tree))
           (n/2 (ash n -1)))
      (declare (type fixnum n n/2))
      (cond
        (present
         (array-tree-set tree value i))
        ((< n +avl-tree-max-array-length+)
         (array-tree-insert-at tree value i))
        ((< i n/2)
         (make-avl-tree (array-tree-insert-at tree value i 0 (1- n/2))
                        (aref tree (1- n/2))
                        (subseq tree  n/2)))
        ((> i n/2)
         (make-avl-tree (subseq tree 0 n/2)
                        (aref tree n/2)
                        (array-tree-insert-at tree value i (1+ n/2))))
        ((= i n/2)
         (make-avl-tree (subseq tree 0 n/2)
                        value
                        (subseq tree  n/2)))
        (t tree)))))


(defun avl-tree-insert (tree value compare)
  "Insert VALUE into TREE, returning new tree."
  (declare (type function compare))
  ;;(declare (optimize (speed 3) (safety 0)))
  (etypecase tree
    (avl-tree
     (with-avl-tree (l v r) tree
       (let ((c (funcall compare value v)))
         (declare (type fixnum c))
         (cond
           ((< c 0)
            (balance-avl-tree (avl-tree-insert l value compare)
                              v r))
           ((> c 0)
            (balance-avl-tree l v
                              (avl-tree-insert r value compare)))
           (t (make-avl-tree l value r))))))
    (simple-vector (avl-tree-insert-vector tree value compare))
    (null (vector value))))

;; (defun avl-tree-insert (tree value compare)
;;   "Insert VALUE into TREE, returning new tree."
;;   (declare (type function compare))
;;   (cond-avl-tree-compare (value tree compare)
;;     (make-avl-tree nil value nil)
;;     (balance-avl-tree (avl-tree-insert (avl-tree-left tree) value compare)
;;                       (binary-tree-value tree)
;;                       (binary-tree-right tree))
;;     tree
;;     (balance-avl-tree (binary-tree-left tree)
;;                       (binary-tree-value tree)
;;                       (avl-tree-insert (avl-tree-right tree) value compare))))


(defun avl-tree-builder (compare)
  (lambda (tree value) (avl-tree-insert tree value compare)))


;; (defun avl-tree-remove-min (tree)
;;   "Insert minimum element of TREE, returning new tree."
;;   (with-avl-tree (l v r) tree
;;     (if l
;;         (multiple-value-bind (min tree) (avl-tree-remove-min l)
;;           (values min
;;                   (balance-avl-tree tree v r)))
;;         (values v r))))

;; (defun avl-tree-remove-max (tree)
;;   "Insert minimum element of TREE, returning new tree."
;;   (with-avl-tree (l v r) tree
;;     (if r
;;         (multiple-value-bind (max tree) (avl-tree-remove-max r)
;;           (values max
;;                   (balance-avl-tree l v tree)))
;;         (values v l))))


(defun avl-tree-remove-min (tree)
  "Remove minimum element of TREE, returning element and tree."
  (etypecase tree
    (avl-tree
     (multiple-value-bind (new-left x) (avl-tree-remove-min (binary-tree-left tree))
       (values (balance-avl-tree new-left
                                 (binary-tree-value tree)
                                 (binary-tree-right tree))
               x)))
    (simple-vector (values (subseq tree 1) (aref tree 0)))
    (null nil)))

(defun avl-tree-remove-max (tree)
  "Remove maximum element of TREE, returning element and tree."
  (etypecase tree
    (avl-tree
     (multiple-value-bind (new-right x) (avl-tree-remove-max (binary-tree-right tree))
       (values (balance-avl-tree (binary-tree-left tree)
                                 (binary-tree-value tree)
                                 new-right)
               x)))
    (simple-vector (let ((n (1- (length tree))))
                     (values (subseq tree 0 n) (aref tree n))))
    (null nil)))


;; (defun join-avl-tree (left value right compare)
;;   (cond-avl-tree-heights (left right)
;;                          (avl-tree-insert right value compare)
;;                          (avl-tree-insert left value compare)
;;                          (balance-avl-tree (join-avl-tree left value (binary-tree-left right) compare)
;;                                            (binary-tree-value right)
;;                                            (binary-tree-right right))
;;                          (balance-avl-tree left value right)
;;                          (balance-avl-tree (binary-tree-left left)
;;                                            (binary-tree-value left)
;;                                            (join-avl-tree (binary-tree-right left) value right compare))))

(defun join-avl-tree (left value right compare)
  (cond
    ((null left) (avl-tree-insert right value compare))
    ((null right) (avl-tree-insert left value compare))
    ((simple-vector-p left)
     (avl-tree-insert (reduce (avl-tree-builder compare) left :initial-value right)
                      value compare))
    ((simple-vector-p right)
     (avl-tree-insert (reduce (avl-tree-builder compare) right :initial-value left)
                      value compare))
    ((< (avl-tree-weight left) (avl-tree-weight right))
     (balance-avl-tree (join-avl-tree left value (binary-tree-left right) compare)
                       (binary-tree-value right)
                       (binary-tree-right right)))
    ((< (avl-tree-weight right) (avl-tree-weight left))
     (balance-avl-tree (binary-tree-left left)
                       (binary-tree-value left)
                       (join-avl-tree (binary-tree-right left) value right compare)))
    (t (balance-avl-tree left value right))))

;; (defun avl-tree-concatenate (tree-1 tree-2)
;;   "Concatenate TREE-1 and TREE-2."
;;   (cond-avl-tree-heights (tree-1 tree-2)
;;                          tree-2
;;                          tree-1
;;                          (balance-avl-tree (avl-tree-concatenate tree-1 (binary-tree-left tree-2))
;;                            (binary-tree-value tree-2)
;;                            (binary-tree-right tree-2))
;;                          (multiple-value-bind (min tree) (avl-tree-remove-min tree-2)
;;                            (balance-avl-tree tree-1 min tree))
;;                          (balance-avl-tree (binary-tree-left tree-1)
;;                                            (binary-tree-value tree-1)
;;                                            (avl-tree-concatenate (binary-tree-right tree-1) tree-2))))


(defun avl-tree-concatenate (tree-1 tree-2 compare)
  "Concatenate TREE-1 and TREE-2."
  (cond
    ((null tree-1) tree-2)
    ((null tree-2) tree-1)
    ((simple-vector-p tree-1)
     (reduce (avl-tree-builder compare) tree-1 :initial-value tree-2))
    ((simple-vector-p tree-2)
     (reduce (avl-tree-builder compare) tree-2 :initial-value tree-1))
    ((< (avl-tree-weight tree-1) (avl-tree-weight tree-2))
     (balance-avl-tree (avl-tree-concatenate tree-1 (binary-tree-left tree-2) compare)
                       (binary-tree-value tree-2)
                       (binary-tree-right tree-2)))
    ((< (avl-tree-weight tree-2) (avl-tree-weight tree-1))
     (balance-avl-tree (binary-tree-left tree-1)
                       (binary-tree-value tree-1)
                       (avl-tree-concatenate (binary-tree-right tree-1) tree-2 compare)))
    (t (balance-avl-tree tree-1 (binary-tree-min tree-2) (avl-tree-remove-min tree-2)))))

;; (defun avl-tree-split (tree x compare)
;;   (declare (type function compare))
;;   (cond-avl-tree-compare (x tree compare)
;;     (values nil nil nil)
;;     (multiple-value-bind (left-left present right-left)
;;         (avl-tree-split (binary-tree-left tree) x compare)
;;       (values left-left present (join-avl-tree right-left
;;                                                (binary-tree-value tree)
;;                                                (binary-tree-right tree)
;;                                                compare)))
;;     (values (binary-tree-left tree) t (binary-tree-right tree))
;;     (multiple-value-bind (left-right present right-right)
;;         (avl-tree-split (binary-tree-right tree) x compare)
;;       (values (join-avl-tree (binary-tree-left tree)
;;                              (binary-tree-value tree)
;;                              left-right
;;                              compare)
;;               present
;;               right-right))))


(defun avl-tree-split (tree x compare)
  (declare (type function compare))
  (etypecase tree
    (avl-tree
     (with-avl-tree (l v r) tree
       (let ((c (funcall compare x v)))
         (cond
           ((< c 0)
            (multiple-value-bind (left-left present right-left)
                (avl-tree-split l x compare)
              (values left-left present (join-avl-tree right-left
                                                       v r compare))))
           ((> c 0)
            (multiple-value-bind (left-right present right-right)
                (avl-tree-split r x compare)
              (values (join-avl-tree l v left-right compare)
                      present right-right)))
           (t (values (binary-tree-left tree) t (binary-tree-right tree)))))))
    (simple-vector
     (array-tree-split tree x compare))
    (null
     (values nil nil nil))))


;; (defun avl-tree-remove (tree x compare)
;;   "Remove X from TREE, returning new tree."
;;   (declare (type function compare))
;;   (cond-avl-tree-compare (x tree compare)
;;     nil
;;     (balance-avl-tree (avl-tree-remove (avl-tree-left tree) x compare)
;;                       (binary-tree-value tree)
;;                       (binary-tree-right tree))
;;     (avl-tree-concatenate (avl-tree-left tree)
;;                           (avl-tree-right tree))
;;     (balance-avl-tree (avl-tree-left tree)
;;                       (avl-tree-value tree)
;;                       (avl-tree-remove (avl-tree-right tree) x compare))))


(defun avl-tree-remove (tree x compare)
  "Remove X from TREE, returning new tree."
  (declare (type function compare))
  (cond-avl-tree-vector-compare
   (x tree compare)
   nil
   (array-tree-remove tree x compare)
   (balance-avl-tree (avl-tree-remove (avl-tree-left tree) x compare)
                     (binary-tree-value tree)
                     (binary-tree-right tree))
   (avl-tree-concatenate (avl-tree-left tree)
                         (avl-tree-right tree)
                         compare)
   (balance-avl-tree (avl-tree-left tree)
                     (avl-tree-value tree)
                     (avl-tree-remove (avl-tree-right tree) x compare))))



(defun avl-tree-trim (tree lo hi compare)
  "Return subtree rooted between `lo' and `hi'."
  (declare (type function compare))
  ;(declare (optimize (speed 3) (safety 0)))
  (cond
    ((null tree) nil)
    ((< (the fixnum (funcall compare (binary-tree-value tree) lo)) 0)
     (avl-tree-trim (binary-tree-right tree) lo hi compare))
    ((< (the fixnum (funcall compare hi (binary-tree-value tree))) 0)
     (avl-tree-trim (binary-tree-left tree) lo hi compare))
    (t tree)))

;; root between lo and +infinity
(defun avl-tree-trim-lo (tree lo compare)
  (declare (type function compare))
  (cond
    ((null tree) nil)
    ((< (funcall compare lo (binary-tree-value tree)) 0)
     tree)
    (t (avl-tree-trim-lo (avl-tree-right tree) lo compare))))


;; root between -infinity and hi
(defun avl-tree-trim-hi (tree hi compare)
  (declare (type function compare))
  (cond
    ((null tree) nil)
    ((> (funcall compare hi (binary-tree-value tree)) 0)
     tree)
    (t (avl-tree-trim-hi (avl-tree-left tree) hi compare))))



(defun avl-tree-split-less (tree x compare)
  "Everything in tree before than x"
  (declare (type function compare))
  (cond-avl-tree-compare (x tree compare)
                         nil
                         (avl-tree-split-less (binary-tree-left tree) x compare)
                         (binary-tree-left tree)
                         (join-avl-tree (binary-tree-left tree)
                                        (binary-tree-value tree)
                                        (avl-tree-split-less (binary-tree-right tree) x compare)
                                        compare)))


(defun avl-tree-split-greater (tree x compare)
  "Everything in tree after than x"
  (declare (type function compare))
  ;(declare (optimize (speed 3) (safety 0)))
  (cond-avl-tree-compare (x tree compare)
                         nil
                         (join-avl-tree (avl-tree-split-greater (binary-tree-left tree) x compare)
                                        (binary-tree-value tree)
                                        (binary-tree-right tree)
                                        compare)
                         (binary-tree-right tree)
                         (avl-tree-split-greater (binary-tree-right tree) x compare)))


;; tree-2 rooted between lo and hi
(defun avl-tree-uni-bd (tree-1 tree-2 lo hi compare)
  (declare (type function compare))
  (let ((tree-2 (avl-tree-trim tree-2 lo hi compare)))
    (cond
      ((null tree-2) tree-1)
      ((null tree-1)
       (join-avl-tree (avl-tree-split-greater (avl-tree-left tree-2) lo compare)
                      (avl-tree-value tree-2)
                      (avl-tree-split-less (avl-tree-right tree-2) hi compare)
                      compare))
      (t (join-avl-tree (avl-tree-uni-bd (avl-tree-left tree-1)
                                         tree-2 lo (avl-tree-value tree-1) compare)
                        (avl-tree-value tree-1)
                        (avl-tree-uni-bd (avl-tree-right tree-1)
                                         tree-2 (avl-tree-value tree-1) hi compare)
                        compare)))))

;; tree-2 between -inf and hi
(defun avl-tree-uni-hi (tree-1 tree-2 hi compare)
  (let ((tree-2 (avl-tree-trim-hi tree-2 hi compare)))
    (cond
      ((null tree-2) tree-1)
      ((null tree-1) (avl-tree-split-less tree-2 hi compare))
      (t (join-avl-tree (avl-tree-uni-hi (avl-tree-left tree-1) tree-2 (avl-tree-value tree-1) compare)
                        (avl-tree-value tree-1)
                        (avl-tree-uni-bd (avl-tree-right tree-1) tree-2 (avl-tree-value tree-1) hi compare)
                        compare)))))

;; tree-2 between lo and +inf
(defun avl-tree-uni-lo (tree-1 tree-2 lo compare)
  (let ((tree-2 (avl-tree-trim-lo tree-2 lo compare)))
    (cond
      ((null tree-2) tree-1)
      ((null tree-1) (avl-tree-split-greater tree-2 lo compare))
      (t (join-avl-tree (avl-tree-uni-bd (avl-tree-left tree-1) tree-2 lo (avl-tree-value tree-1) compare)
                        (avl-tree-value tree-1)
                        (avl-tree-uni-lo (avl-tree-right tree-1) tree-2 (avl-tree-value tree-1) compare)
                        compare)))))

(defun avl-tree-hedge-union (tree-1 tree-2 compare)
  (declare (type function compare))
  (cond
    ((null tree-1) tree-2)
    ((null tree-2) tree-1)
    (t (with-avl-tree (l1 v1 r1) tree-1
         (join-avl-tree (avl-tree-uni-hi l1 tree-2 v1 compare)
                        v1
                        (avl-tree-uni-lo r1 tree-2 v1 compare)
                        compare)))))


(defun avl-tree-union (tree-1 tree-2 compare)
  (declare (type function compare))
  (cond
    ((null tree-1) tree-2)
    ((null tree-2) tree-1)
    ((simple-vector-p tree-1)
     (reduce (avl-tree-builder compare) tree-1 :initial-value tree-2))
    ((simple-vector-p tree-2)
     (reduce (avl-tree-builder compare) tree-2 :initial-value tree-1))
    ((>= (avl-tree-count tree-2)
         (avl-tree-count tree-1))
     (multiple-value-bind (left-2 p-2 right-2) (avl-tree-split tree-2 (avl-tree-value tree-1) compare)
       (declare (ignore p-2))
       (join-avl-tree (avl-tree-union (binary-tree-left tree-1) left-2 compare)
                      (avl-tree-value tree-1)
                      (avl-tree-union (binary-tree-right tree-1) right-2 compare)
                      compare)))
    (t
     (multiple-value-bind (left-1 p-1 right-1) (avl-tree-split tree-1 (avl-tree-value tree-2) compare)
       (declare (ignore p-1))
       (join-avl-tree (avl-tree-union left-1 (binary-tree-left tree-2) compare)
                      (avl-tree-value tree-2)
                      (avl-tree-union right-1 (binary-tree-right tree-2) compare)
                      compare)))))

(defun avl-tree-intersection (tree-1 tree-2 compare)
  (cond
    ((or (null tree-1)
         (null tree-2))
     nil)
    ((simple-vector-p tree-1)
     (if (simple-vector-p tree-2)
         ;; base intersection
         (array-tree-intersection tree-1 tree-2 compare)
         ;; swap args so tree-1 is the real tree
         (avl-tree-intersection tree-2 tree-1 compare)))
    ;; TODO: consider reording if would improve performance
    ;; general case
    (t (multiple-value-bind (left-2 present right-2)
           (avl-tree-split tree-2 (avl-tree-value tree-1) compare)
         (let ((i-left (avl-tree-intersection (avl-tree-left tree-1) left-2 compare))
               (i-right (avl-tree-intersection (avl-tree-right tree-1) right-2 compare)))
           (if present
               (join-avl-tree i-left (avl-tree-value tree-1) i-right compare)
               (avl-tree-concatenate i-left i-right compare)))))))

(defun avl-tree-difference (tree-1 tree-2 compare)
  (declare (type function compare))
  (cond
    ((null tree-1) nil)
    ((null tree-2) tree-1)
    ((simple-vector-p tree-1)
     (reduce (lambda (tree x)
               (if (binary-tree-member-p tree-2 x compare)
                   tree
                   (array-tree-insert tree x #'-)))
              tree-1 :initial-value (vector)))
    ;; general case
    (t (multiple-value-bind (left-2 present right-2)
           (avl-tree-split tree-2 (binary-tree-value tree-1) compare)
         (let ((left (avl-tree-difference (binary-tree-left tree-1) left-2 compare))
               (right (avl-tree-difference (binary-tree-right tree-1) right-2 compare)))
           (if present
               (avl-tree-concatenate left right compare)
               (join-avl-tree left (binary-tree-value tree-1) right compare)))))))



(defun avl-tree-subset (tree-1 tree-2 compare)
  (declare (type function compare))
  (labels ((rec (tree-1 tree-2)
             (cond
               ((> (avl-tree-count tree-1)
                   (avl-tree-count tree-2))
                nil)
               ((null tree-1) t)
               ((null tree-2) nil)
               ((simple-vector-p tree-1)
                (every (lambda (x) (binary-tree-member-p tree-2 x compare)) tree-1))
               ((simple-vector-p tree-2)
                (map-binary-tree :inorder nil
                                 (lambda (x) (unless (array-tree-position tree-2 x compare)
                                          (return-from rec nil)))
                                 tree-1)
                t)
               (t
                (let ((c (funcall compare (binary-tree-value tree-1) (binary-tree-value tree-2))))
                  (declare (type fixnum c))
                  (cond
                    ((< c 0) ; v1 < v2
                     (and (rec (make-avl-tree (binary-tree-left tree-1)
                                              (binary-tree-value tree-1)
                                               nil)
                               (binary-tree-left tree-2))
                          (rec (binary-tree-right tree-1)
                               tree-2)))
                    ((> c 0) ; v1 > v2
                     (and (rec (make-avl-tree nil
                                              (binary-tree-value tree-1)
                                              (binary-tree-right tree-1))
                               (binary-tree-right tree-2))
                          (rec (binary-tree-left tree-1)
                               tree-2)))
                    (t (and (rec (binary-tree-left tree-1)
                                 (binary-tree-left tree-2))
                            (rec (binary-tree-right tree-1)
                                 (binary-tree-right tree-2))))))))))
    (rec tree-1 tree-2)))


(defun avl-tree-dot (tree &key output)
  (output-dot output
              (lambda (s)
                (let ((i -1))
                  (labels ((helper (parent tree)
                             (let ((x (incf i)))
                               (format s "~&  ~A[label=\"~A (~D)\"~:[shape=none~;~]];~&"
                                       x (if tree
                                             (binary-tree-value tree)
                                             "")
                                       (avl-tree-count tree)
                                       tree)
                               (when parent
                                 (format s "~&  ~A -> ~A;~&"
                                         parent x))
                               (when tree
                                 (helper x (binary-tree-left tree))
                                 (helper x (binary-tree-right tree))))))
                    (format s "~&digraph {  ~&")
                    (helper nil tree)
                    (format s "~&}~&"))))))