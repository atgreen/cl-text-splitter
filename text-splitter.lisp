;;; text-splitter.lisp
;;;
;;; SPDX-License-Identifier: MIT
;;;
;;; Copyright (C) 2024  Anthony Green <green@moxielogic.com>
;;;
;;; Permission is hereby granted, free of charge, to any person obtaining a copy
;;; of this software and associated documentation files (the "Software"), to deal
;;; in the Software without restriction, including without limitation the rights
;;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;;; copies of the Software, and to permit persons to whom the Software is
;;; furnished to do so, subject to the following conditions:
;;;
;;; The above copyright notice and this permission notice shall be included in all
;;; copies or substantial portions of the Software.
;;;
;;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;;; SOFTWARE.
;;;

(in-package :text-splitter)

(defparameter +default-size+ 5000)
(defparameter +default-overlap+ 200)

(defclass document ()
  ((text :initarg :text)))

(defclass plaintext-document (document)
  ())

(defclass markdown-document (plaintext-document)
  ())

(defclass html-document (plaintext-document)
  ())

(defclass org-mode-document (plaintext-document)
  ())

(defclass pdf-document (plaintext-document)
  ())

(defun detect-document-type (filename)
  "Detects the document type based on the file extension."
  (let ((extension (pathname-type filename)))
    (cond
      ((string-equal extension "txt") 'plaintext-document)
      ((string-equal extension "md") 'markdown-document)
      ((string-equal extension "html") 'html-document)
      ((string-equal extension "org") 'org-mode-document)
      ((string-equal extension "pdf") 'pdf-document)
      (t 'document))))

(defun make-document-from-file (filename)
  "Creates an instance of a document class based on the file's type."
  (let* ((document-type (detect-document-type filename)))
    (cond
      ((eq document-type 'pdf-document)
       (let ((text-content (uiop:run-program `("pdftotext" "-layout" "-enc" "UTF-8" ,filename "-")
                                             :output '(:string))))
         (make-instance 'pdf-document :text text-content)))
      (t
       (let ((text-content (with-open-file (stream filename)
                             (let ((content (make-string (file-length stream))))
                               (read-sequence content stream)
                               content))))
         (make-instance document-type :text text-content))))))

(defun merge-adjacent-strings (strings x)
  "Merges adjacent strings in STRINGS if their combined length is <= X, aiming for the shortest list."
  (loop with result = (list (first strings))
        for s in (cdr strings)
        do (if (<= (+ (length (car result)) (length s)) x)
               (setf (car result) (concatenate 'string (car result) s))
               (push s result))
        finally (return (nreverse result))))

(defun add-overlaps (strings overlap)
  (let* ((count (length strings))
         (sa (make-array count :initial-contents strings)))
    (loop for i from 0 below count
          collect (format nil "~A~A~A"
                          (if (> i 0)
                              (subseq (aref sa (1- i)) (max (- (length (aref sa (1- i))) overlap) 0))
                              "")
                          (aref sa i)
                          (if (< i (1- count))
                              (subseq (aref sa (1+ i)) 0 (min (length (aref sa (1+ i))) overlap))
                              "")))))

(defmethod split-internal (doc delimeters size overlap)
  "Split a DOC up into a list of strings around SIZE big and
 overlapping by OVERLAP characters on either end."
  (let ((usize (- size (* overlap 2))))
    (labels ((%split (text delimeters)
               (if (> (length text) usize)
                   (if delimeters
                       (let* ((matches (cl-ppcre:all-matches-as-strings (car delimeters) text))
                              (splits (cl-ppcre:split (car delimeters) text)))
                         (if matches
                             (mapcar (lambda (txt)
                                       (%split txt (cdr delimeters)))
                                     (mapcar (lambda (a b) (concatenate 'string a b)) splits matches))
                             (%split text (cdr delimeters))))
                       (loop for i from 0 below (length text) by usize
                             collect (subseq text i (min (+ i usize) (length text)))))
                   text)))
      (let ((small-chunks
              (alexandria:flatten
               (%split (slot-value doc 'text) delimiters))))
        (let ((strings (merge-adjacent-strings small-chunks usize)))
          (add-overlaps strings overlap))))))

(defmethod split ((doc plaintext-document) &key (size +default-size+) (overlap +default-overlap+))
  "Split a plaintext DOC up into a list of strings around SIZE big and
 overlapping by OVERLAP characters on either end."
  (split-internal doc '(,(format nil "~A" #\Page) "\\n\\n" "[.!]" "\\n" ",:=" "[ \\t]") size overlap))

(defmethod split ((doc markdown-document) &key (size +default-size+) (overlap +default-overlap+))
  "Split a markdown DOC up into a list of strings around SIZE big and
 overlapping by OVERLAP characters on either end."
  (split-internal doc '("^# " "^## " "^### " "^#### " "\\n\\n" "[.!]" "\\n" ",:=" "[ \\t]") size overlap))

(defmethod split ((doc org-mode-document) &key (size +default-size+) (overlap +default-overlap+))
  "Split an org-mode DOC up into a list of strings around SIZE big and
 overlapping by OVERLAP characters on either end."
  (split-internal doc '("^\* " "^\*\* " "^\*\*\* " "^\*\*\*\* " "\\n\\n" "[.!]" "\\n" ",:=" "[ \\t]") size overlap))

(defmethod split ((doc html-document) &key (size +default-size+) (overlap +default-overlap+))
  "Split an HTML DOC up into a list of strings around SIZE big and
 overlapping by OVERLAP characters on either end."
  (split-internal doc '("<h1" "<h2" "<h3" "<h4" "<h5" "<h6" "<div" "<p" "<table" "<ul" "[.!]" "\\n" ",:=" "[ \\t]") size overlap))
