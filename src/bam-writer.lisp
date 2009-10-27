;;;
;;; Copyright (C) 2009 Keith James. All rights reserved.
;;;
;;; This file is part of cl-sam.
;;;
;;; This program is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;;

(in-package :sam)

(defun write-bam-magic (bgzf)
  "Writes the BAM magic number to the handle BGZF."
  (write-bytes bgzf +bam-magic+ (length +bam-magic+)))

(defun write-bam-header (bgzf header &optional (null-padding 0))
  "Writes the BAM header string HEADER to handle BGZF, followed by
padding of NULL-PADDING null bytes. This function also writes the
header length, including padding, in the 4 bytes preceding the
header."
  (let* ((hlen (length header))
         (buffer (make-array (+ 4 hlen null-padding)
                             :element-type '(unsigned-byte 8)
                             :initial-element +null-byte+)))
    ;; store header length, including padding
    (encode-int32le (+ hlen null-padding) buffer)
    (when (plusp hlen)
      (copy-array header 0 (1- hlen) buffer 4 #'char-code))
    (write-bytes bgzf buffer (length buffer))))

(defun write-num-references (bgzf n)
  "Writes the number of reference sequences N to handle BGZF."
  (let ((buffer (make-array 4 :element-type '(unsigned-byte 8))))
    (encode-int32le n buffer)
    (write-bytes bgzf buffer 4)))

(defun write-reference-meta (bgzf ref-name ref-length)
  "Writes the metadata for a single reference sequence named REF-NAME,
of length REF-LENGTH bases, to handle BGZF."
  (let* ((name-len (1+ (length ref-name)))
         (buffer-len (+ 4 name-len 4))
         (name-offset 4)
         (ref-len-offset (+ name-offset name-len))
         (buffer (make-array buffer-len :element-type '(unsigned-byte 8)
                             :initial-element +null-byte+)))
    (encode-int32le name-len buffer)
    (copy-array ref-name 0 (- name-len 2)
                buffer name-offset #'char-code)
    (encode-int32le ref-length buffer ref-len-offset)
    (write-bytes bgzf buffer buffer-len)))

(defun write-alignment (bgzf alignment-record)
  "Writes one ALIGNMENT-RECORD to handle BGZF and returns the number
of bytes written."
  (let ((alen (length alignment-record))
        (alen-bytes (make-array 4 :element-type '(unsigned-byte 8))))
    (encode-int32le alen alen-bytes)
    (+ (write-bytes bgzf alen-bytes 4)
       (write-bytes bgzf alignment-record alen))))

(defun write-bam-meta (bgzf header num-refs ref-meta)
  "Writes BAM magic number and then all metadata to handle BGZF. The
metadata consist of the HEADER string, number of reference sequences
NUM-REFS and a list reference sequence metadata REF-META. The list
contains one element per reference sequence, each element being a list
of reference identifier, reference name and reference length. Returns
the number of bytes written."
  (+ (write-bam-magic bgzf)
     (write-bam-header bgzf header)
     (write-num-references bgzf num-refs)
     (loop
        for (ref-id ref-name ref-length) in ref-meta
        sum (write-reference-meta bgzf ref-name ref-length))))