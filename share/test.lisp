;;; -*- Lisp -*-
;;;;
;;;; Copyright (c) 2011, Georgia Tech Research Corporation
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

(defvar *test-list-1*)
(defvar *test-list-2*)
(defvar *test-sort-1*)
(defvar *test-sort-2*)
(defvar *test-wb-1*)
(defvar *test-wb-2*)

;; number of fuzz test iterations
#-(or clisp ecl)
(defparameter *test-iterations* 1000)
#+ecl
(defparameter *test-iterations* 100)
#+clisp
(defparameter *test-iterations* 10)


(defun make-test-vars (list1 list2)
  (setq *test-list-1*  list1
        *test-list-2*  list2
        *test-sort-1* (remove-duplicates (sort (copy-list list1) #'<))
        *test-sort-2* (remove-duplicates (sort (copy-list list2) #'<))
        *test-wb-1* (fold (wb-tree-builder #'-) nil list1)
        *test-wb-2* (fold (wb-tree-builder #'-) nil list2)))


(defun test-list (count &optional (max 100))
  (loop for i below count collect (random max)))

(defun test-wb (count &optional (max 100))
  (fold (wb-tree-builder #'-) nil (test-list count max)))

(lisp-unit:define-test array
  ;; remove
  (let ((v (vector 1 2 3 4 5)))
    (lisp-unit:assert-equalp (vector 1 2 4 5)
                             (array-tree-remove v 3 #'-))
    (lisp-unit:assert-equalp (vector 2 3 4 5)
                             (array-tree-remove v 1 #'-))
    (lisp-unit:assert-equalp (vector 1 2 3 4)
                             (array-tree-remove v 5 #'-)))
  (let ((v (vector 1 2 3 4)))
    (lisp-unit:assert-equalp (vector 2 3 4 )
                             (array-tree-remove v 1 #'-))
    (lisp-unit:assert-equalp (vector 1 3 4)
                             (array-tree-remove v 2 #'-))
    (lisp-unit:assert-equalp (vector 1 2 4)
                             (array-tree-remove v 3 #'-))
    (lisp-unit:assert-equalp (vector 1 2 3)
                             (array-tree-remove v 4 #'-)))

  ;; insert
  (dotimes (i *test-iterations*)
    (let* ((list (loop for i below (random 100) collect (random 100)))
           (sort (remove-duplicates (sort (copy-list list) #'<)))
           (array (fold (array-tree-builder #'-) (vector) list)))
      (lisp-unit:assert-equal (map 'list #'identity array)
                              sort)))

  ;; split
  (multiple-value-bind (l p r)
      (array-tree-split (vector 1 2 4 5) 3 #'-)
    (lisp-unit:assert-equalp (vector 1 2) l)
    (lisp-unit:assert-equalp (vector 4 5) r)
    (lisp-unit:assert-false p)
  )

  (multiple-value-bind (l p r)
      (array-tree-split (vector 1 2 4 5) 4 #'-)
    (lisp-unit:assert-equalp (vector 1 2) l)
    (lisp-unit:assert-equalp (vector 5) r)
    (lisp-unit:assert-true p))

  (multiple-value-bind (l p r)
      (array-tree-split (vector 94 96 97 99 111) 101 #'-)
    (lisp-unit:assert-equalp (vector 94 96 97 99) l)
    (lisp-unit:assert-equalp (vector 111) r)
    (lisp-unit:assert-false p))


  )



(lisp-unit:define-test tree

  ;; equal
  (let ((a (binary-tree-from-list '(2 (1) (3)))))
    (lisp-unit:assert-true (binary-tree-equal a
                                              (binary-tree-from-list '(1 nil (3 (2))))
                                              #'-))
    (lisp-unit:assert-true (binary-tree-equal a
                                              (binary-tree-from-list '(1 nil (2 nil (3))))
                                              #'-))
    (lisp-unit:assert-true (binary-tree-equal a
                                              (binary-tree-from-list '(3 (2 (1))))
                                              #'-))

    (lisp-unit:assert-false (binary-tree-equal a
                                              (binary-tree-from-list '(1 (0) (3 (2))))
                                              #'-))
    (lisp-unit:assert-false (binary-tree-equal a
                                              (binary-tree-from-list '(1 nil (3 (2) (4))))
                                              #'-))
    (lisp-unit:assert-false (binary-tree-equal a
                                              (binary-tree-from-list '(3 (2 (1 (0)))))
                                              #'-))
   )

  ;; wb-tree

  (let ((a (make-wb-tree nil 1 nil))
        (b (make-wb-tree nil 3 nil))
        (c (make-wb-tree nil 5 nil))
        (d (make-wb-tree nil 7 nil)))
    (let ((bal (make-wb-tree (make-wb-tree a 2 b) 4 (make-wb-tree c 6 d)))
          (right-right (make-wb-tree a 2 (make-wb-tree b 4 (make-wb-tree c 6 d))))
          (right-left (make-wb-tree a 2 (make-wb-tree (make-wb-tree b 4 c) 6 d)))
          (left-left (make-wb-tree (make-wb-tree (make-wb-tree a 2 b) 4 c) 6 d))
          (left-right (make-wb-tree (make-wb-tree a 2 (make-wb-tree b 4 c)) 6 d)) )
      (let ((bal-right-right (left-wb-tree (binary-tree-left right-right)
                                            (binary-tree-value right-right)
                                            (binary-tree-right right-right)))
            (bal-right-left (left-right-wb-tree (binary-tree-left right-left)
                                                 (binary-tree-value right-left)
                                                 (binary-tree-right right-left)))
            (bal-left-left (right-wb-tree (binary-tree-left left-left)
                                           (binary-tree-value left-left)
                                           (binary-tree-right left-left)))
            (bal-left-right (right-left-wb-tree (binary-tree-left left-right)
                                                 (binary-tree-value left-right)
                                                 (binary-tree-right left-right))))
        (lisp-unit:assert-equalp bal bal-right-right)
        (lisp-unit:assert-equalp bal bal-left-right)
        (lisp-unit:assert-equalp bal bal-right-left)
        (lisp-unit:assert-equalp bal bal-left-left))))

  (dotimes (i *test-iterations*)
    (let* ((list-1 (loop for i below 50 collect (random 100)))
           (list-2 (loop for i below 100 collect (+ 110 (random 100))))
           (sort-1 (remove-duplicates (sort (copy-list list-1) #'<)))
           (sort-2 (remove-duplicates (sort (copy-list list-2) #'<)))
           (wb-tree-1 (fold (wb-tree-builder #'-) nil list-1))
           (wb-tree-2 (fold (wb-tree-builder #'-) nil list-2))
           (wb-tree-12 (fold (lambda (a x) (wb-tree-insert a x #'-)) wb-tree-1 list-2))
           (wb-tree-cat (wb-tree-concatenate wb-tree-1 wb-tree-2 #'-)))
      (make-test-vars list-1 list-2)
      ;; construction
      (lisp-unit:assert-equal sort-1 (wb-tree-list wb-tree-1))
      (lisp-unit:assert-equal sort-2 (wb-tree-list wb-tree-2))

      ;; concatenate
      (lisp-unit:assert-equal (wb-tree-list wb-tree-cat)
                              (append sort-1 sort-2))
      (lisp-unit:assert-equal (wb-tree-list wb-tree-cat)
                              (wb-tree-list wb-tree-12))

      ;; equal
      (lisp-unit:assert-true (binary-tree-equal wb-tree-cat wb-tree-12 #'-))

      (lisp-unit:assert-true (not (binary-tree-equal wb-tree-1 wb-tree-2 #'-)))

      ;; subset
      (lisp-unit:assert-true (wb-tree-subset wb-tree-1 wb-tree-12 #'-))
      (lisp-unit:assert-true (wb-tree-subset wb-tree-2 wb-tree-12 #'-))
      (lisp-unit:assert-true (wb-tree-subset wb-tree-cat wb-tree-12 #'-))

      (lisp-unit:assert-true (not (wb-tree-subset wb-tree-12 wb-tree-1 #'-)))
      (lisp-unit:assert-true (not (wb-tree-subset wb-tree-12 wb-tree-2 #'-)))

      ;; min
      (lisp-unit:assert-equal (car sort-1)
                              (binary-tree-min wb-tree-1))
      (lisp-unit:assert-equal (car sort-2)
                              (binary-tree-min wb-tree-2))

      ;; remove-min
      (loop
         with tree = wb-tree-1
         for sort on sort-1
         do (multiple-value-bind (tree-x min) (wb-tree-remove-min tree)
              (lisp-unit:assert-equal (cdr sort)
                                      (wb-tree-list tree-x))
              (lisp-unit:assert-equal (car sort)
                                      min)
              (setq tree tree-x)))

      (multiple-value-bind (tree x) (wb-tree-remove-min wb-tree-1)
        (lisp-unit:assert-equal (cdr sort-1) (wb-tree-list tree))
        (lisp-unit:assert-equal (car sort-1) x))

      (multiple-value-bind (tree x)  (wb-tree-remove-min wb-tree-2)
        (lisp-unit:assert-equal (cdr sort-2) (wb-tree-list tree))
        (lisp-unit:assert-equal (car sort-2) x))

      ;; remove-max
      (loop
         with tree = wb-tree-1
         for sort on (reverse sort-1)
         do (multiple-value-bind (tree-x max) (wb-tree-remove-max tree)
              (lisp-unit:assert-equal (reverse (cdr sort))
                                      (wb-tree-list tree-x))
              (lisp-unit:assert-equal (car sort)
                                      max)
              (setq tree tree-x)))

      (multiple-value-bind (tree x) (wb-tree-remove-max wb-tree-1)
        (lisp-unit:assert-equal (wb-tree-list tree)
                                (subseq sort-1 0 (1- (length sort-1))))
        (lisp-unit:assert-equal x (car (last sort-1))))

      (multiple-value-bind (tree x) (wb-tree-remove-max wb-tree-2)
        (lisp-unit:assert-equal (wb-tree-list tree)
                                (subseq sort-2 0 (1- (length sort-2))))
        (lisp-unit:assert-equal x (car (last sort-2))))

      ;; remove
      (let ((list (append sort-1 sort-2)))
        (dotimes (i 10)
          (let ((i (random (length list))))
            (lisp-unit:assert-equal (wb-tree-list (wb-tree-remove wb-tree-cat (elt list i) #'-))
                                    (append (subseq list 0 i)
                                            (subseq list (1+ i)))))))


      ;; split
      (multiple-value-bind (left present right)
          (wb-tree-split wb-tree-12 101 #'-)
        (lisp-unit:assert-equal sort-1 (wb-tree-list left))
        (lisp-unit:assert-equal sort-2 (wb-tree-list right))
        (lisp-unit:assert-false present)
        )
      )))

(lisp-unit:define-test wb-tree-compare
  ;; divide and conquer
  (lisp-unit:assert-true (= 0
                            (wb-tree-compare (wb-tree #'- 1 3 5 7)
                                              (wb-tree #'- 1 3 5 7) #'-)))
  (lisp-unit:assert-true (> 0
                            (wb-tree-compare (wb-tree #'- 1 3 5 7)
                                              (wb-tree #'- 1 3 5 7 9) #'-)))
  (lisp-unit:assert-true (< 0
                            (wb-tree-compare (wb-tree #'- 1 3 5 7 9)
                                              (wb-tree #'- 1 3 5 7) #'-)))

  (lisp-unit:assert-true (< 0
                            (wb-tree-compare (wb-tree #'- 2 3 5 7)
                                              (wb-tree #'- 1 3 5 7) #'-)))
  (lisp-unit:assert-true (> 0
                            (wb-tree-compare (wb-tree #'- 1 3 5 7)
                                              (wb-tree #'- 2 3 5 7) #'-)))

  (lisp-unit:assert-true (< 0
                            (wb-tree-compare (wb-tree #'- 1 3 5 9)
                                              (wb-tree #'- 1 3 5 7) #'-)))
  (lisp-unit:assert-true (> 0
                            (wb-tree-compare (wb-tree #'- 1 3 5 7)
                                              (wb-tree #'- 1 3 5 9) #'-)))
  (lisp-unit:assert-true (< 0
                            (wb-tree-compare (wb-tree #'- 1 3 6 7 9)
                                              (wb-tree #'- 1 3 5 7 9) #'-)))
  (lisp-unit:assert-true (> 0
                            (wb-tree-compare (wb-tree #'- 1 3 5 7 9)
                                              (wb-tree #'- 1 3 6 7 9) #'-)))


  )



(lisp-unit:define-test set
  (dotimes (i *test-iterations*)
    (let* ((list-1 (loop for i below (random 100) collect (random 100)))
           (list-2 (loop for i below (random 100) collect (random 100)))
           (list-set-1 (remove-duplicates (sort (copy-list list-1) #'<)))
           (set-1 (apply #'tree-set #'- list-1))
           (set-2 (apply #'tree-set #'- list-2)))
      ;; union
      (lisp-unit:assert-equal (remove-duplicates (sort (copy-list (union list-1 list-2)) #'<))
                              (map-tree-set 'list #'identity (tree-set-union set-1 set-2)))
      ;; intersection
      (lisp-unit:assert-equal (remove-duplicates (sort (copy-list (intersection list-1 list-2)) #'<))
                              (map-tree-set 'list #'identity (tree-set-intersection set-1 set-2)))
      ;; difference
      (lisp-unit:assert-equal (remove-duplicates (sort (copy-list (set-difference list-1 list-2)) #'<))
                              (map-tree-set 'list #'identity (tree-set-difference set-1 set-2)))
      ;; member
      (dolist (x list-1)
        (lisp-unit:assert-true (tree-set-member-p set-1 x)))
      (dolist (x list-2)
        (lisp-unit:assert-true (tree-set-member-p set-2 x)))
      (let ((set-i (tree-set-difference set-1 set-2)))
        (dolist (x list-2)
          (lisp-unit:assert-false (tree-set-member-p set-i x))))
      ;; remove
      (lisp-unit:assert-equal (remove-duplicates (sort (copy-list (set-difference list-1 list-2)) #'<))
                              (map-tree-set 'list #'identity (fold #'tree-set-remove set-1 list-2)))

      ;; subset
      (lisp-unit::assert-true (tree-set-subset-p set-1 (tree-set-union set-1 set-2)))
      (lisp-unit::assert-true (tree-set-subset-p set-2 (tree-set-union set-1 set-2)))

      (if (subsetp list-1 list-2)
          (lisp-unit::assert-true (subsetp list-1 list-2))
          (lisp-unit::assert-false (tree-set-subset-p set-1 set-2)))
      (if (subsetp list-2 list-1)
          (lisp-unit::assert-true (tree-set-subset-p set-2 set-1))
          (lisp-unit::assert-false (tree-set-subset-p set-2 set-1)))
      ;; position
      (loop
         for i from 0
         for x in list-set-1
         do
           (lisp-unit::assert-equal x (tree-set-ref set-1 i))
           (lisp-unit::assert-equal i (tree-set-position set-1 x)))
      )))

;; (lisp-unit:define-test t-tree
;;   (dotimes (i 20)
;;     (let* ((list-1 (loop for i below 1000 collect (random 100000)))
;;            (list-2 (loop for i below 1000 collect (random 1000000)))
;;            (s-1 (remove-duplicates (sort (copy-list list-1) #'<)))
;;            (s-2 (remove-duplicates (sort (copy-list list-2) #'<)))
;;            (t-1 (fold (lambda (a x) (t-tree-insert a x #'-)) nil list-1))
;;            (t-2 (fold (lambda (a x) (t-tree-insert a x #'-)) nil list-2)))
;;       (lisp-unit:assert-equalp s-1
;;                                (map-t-tree 'list #'identity t-1))
;;       (lisp-unit:assert-equalp s-2
;;                                (map-t-tree 'list #'identity t-2)))))


(lisp-unit:define-test heap
  (dotimes (i (ash *test-iterations* -2))
    (let* ((list-1 (loop for i below 1000 collect (random 100000)))
           (list-2 (loop for i below 1000 collect (random 1000000)))
           ;(s-1 (remove-duplicates (sort (copy-list list-1) #'<)))
           ;(s-2 (remove-duplicates (sort (copy-list list-2) #'<)))
           ;(t-1 (fold #'tree-heap-insert (make-tree-heap #'identity) list-1))
           ;(t-2 (fold #'tree-heap-insert (make-tree-heap #'identity) list-2))
           (p-1 (fold (pairing-heap-builder #'-) nil list-1))
           (p-2 (fold (pairing-heap-builder #'-) nil list-2))
           )
      (labels (
              ; (heap-list (heap)
              ;   (map 'list #'cdr (wb-tree-list (tree-heap-root heap))))
               )
        ;(lisp-unit:assert-equalp s-1
                                 ;(heap-list t-1))
        ;(lisp-unit:assert-equalp s-2
                                 ;(heap-list t-2))

        ;; ;; find min
        ;; (lisp-unit:assert-equalp (car s-1) (tree-heap-find-min t-1))

        ;; ;; find max
        ;; (lisp-unit:assert-equalp (car (last s-1)) (tree-heap-find-max t-1))

        ;; remove min
        ;; (multiple-value-bind (tree value) (tree-heap-remove-min t-1)
        ;;   (lisp-unit:assert-equalp (cdr s-1)
        ;;                            (heap-list tree))
        ;;   (lisp-unit:assert-equalp (car s-1) value))

        ;; remove max
        ;; (multiple-value-bind (tree value) (tree-heap-remove-max t-1)
        ;;   (lisp-unit:assert-equalp (subseq s-1 0 (1- (length s-1)))
        ;;                            (heap-list tree))
        ;;   (lisp-unit:assert-equalp (car (last s-1)) value))

        (lisp-unit:assert-equalp (pairing-heap-list p-1 #'-)
                                 (sort (copy-list list-1) #'<))
        (lisp-unit:assert-equalp (pairing-heap-list p-2 #'-)
                                 (sort (copy-list list-2) #'<))
        ))))



(lisp-unit:define-test map
  (let ((data '((1 . a) (2 . b) (3 . c) (4 . d)))
        (map (make-tree-map #'-)))
    (loop for (key . value) in data
         do (setq map (tree-map-insert map key value)))
    (loop for (key . value) in data
       do (lisp-unit:assert-true (eq value (tree-map-find map key))))))


(lisp-unit:define-test regression
  ;; remove min/max with null
  (lisp-unit:assert-equal '((2 3 4 5) 1)
                          (multiple-value-bind (tree min)
                              (wb-tree-remove-min (make-wb-tree nil 1 (vector 2 3 4 5)))
                            (list (wb-tree-list tree) min)))

  (lisp-unit:assert-equal '((1 2 3 4) 5)
                          (multiple-value-bind (tree min)
                              (wb-tree-remove-max (make-wb-tree (vector 1 2 3 4) 5 nil))
                            (list (wb-tree-list tree) min))))

;; (lisp-unit:define-test red-black
;;   ;; red-black
;;   (let ((bal (make-red-black t
;;                              (make-red-black nil 'a 'x 'b)
;;                              'y
;;                              (make-red-black nil 'c 'z 'd))))

;;     (lisp-unit:assert-equalp bal
;;                              (balance-red-black nil (make-red-black t 'a
;;                                                                     'x
;;                                                                     (make-red-black t 'b 'y 'c))
;;                                                 'z 'd))
;;     (lisp-unit:assert-equalp bal
;;                              (balance-red-black t
;;                                                 (make-red-black nil 'a 'x 'b)
;;                                                 'y
;;                                                 (make-red-black nil 'c 'z 'd)))

;;     (lisp-unit:assert-equalp bal
;;                              (balance-red-black nil
;;                                                 (make-red-black t (make-red-black t 'a 'x 'b)
;;                                                                 'y
;;                                                                 'c)
;;                                                 'z
;;                                                 'd))
;;     (lisp-unit:assert-equalp bal
;;                              (balance-red-black nil
;;                                                 'a
;;                                                 'x
;;                                                 (make-red-black t
;;                                                                 'b
;;                                                                 'y
;;                                                                 (make-red-black t 'c 'z 'd))))
;;     (lisp-unit:assert-equalp bal
;;                              (balance-red-black nil 'a 'x
;;                                                 (make-red-black t (make-red-black t 'b 'y 'c)
;;                                                                 'z 'd)))))
