;; string.scm -- cursor-oriented string library
;; Copyright (c) 2012-2017 Alex Shinn.  All rights reserved.
;; BSD-style license: http://synthcode.com/license.txt

(define (string-cursor->index str i) i)

(define (string-index->cursor str i) i)

(define string-cursor? integer?)

(define string-cursor<? <)

(define string-cursor>? >)

(define string-cursor=? =)

(define string-cursor<=? <=)

(define string-cursor>=? >=)

(define string-cursor-ref string-ref)

(define (string-cursor-start s) 0)

(define string-cursor-end string-length)

(define (string-cursor-next s i) (+ i 1))

(define (string-cursor-prev s i) (- i 1))

(define (string-cursor-forward str cursor n)
  (if (positive? n)
      (string-cursor-forward str (string-cursor-next str cursor) (- n 1))
      cursor))

(define (string-cursor-back str cursor n)
  (if (positive? n)
      (string-cursor-back str (string-cursor-prev str cursor) (- n 1))
      cursor))

(define (substring-cursor s start . o)
  (substring s start (if (pair? o) (car o) (string-length s))))

(define (string-concatenate orig-ls . o)
  (let ((sep (if (pair? o) (car o) ""))
        (out (open-output-string)))
    (let lp ((ls orig-ls))
      (cond
       ((pair? ls)
        (if (and sep (not (eq? ls orig-ls)))
            (write-string sep out))
        (write-string (car ls) out)
        (lp (cdr ls)))))
    (get-output-string out)))

(define string-size string-length)

(define (call-with-output-string proc)
  (let ((out (open-output-string)))
    (proc out)
    (get-output-string out)))

(define (string-contains a b . o)  ; really, stupidly slow
  (let ((alen (string-length a))
        (blen (string-length b)))
    (let lp ((i (if (pair? o) (car o) 0)))
      (and (<= (+ i blen) alen)
           (if (string=? b (substring a i (+ i blen)))
               i
               (lp (+ i 1)))))))

(define (string-null? str)
  (equal? str ""))

(define (make-char-predicate x)
  (cond ((procedure? x) x)
        ((char? x) (lambda (ch) (eq? ch x)))
        (else (error "invalid character predicate" x))))

(define (complement pred) (lambda (x) (not (pred x))))

(define (string-any check str)
  (let ((pred (make-char-predicate check))
        (end (string-cursor-end str)))
    (and (string-cursor>? end (string-cursor-start str))
         (let lp ((i (string-cursor-start str)))
           (let ((i2 (string-cursor-next str i))
                 (ch (string-cursor-ref str i)))
             (if (string-cursor>=? i2 end)
                 (pred ch)  ;; tail call
                 (or (pred ch) (lp i2))))))))

(define (string-every check str)
  (not (string-any (complement (make-char-predicate check)) str)))

(define (string-find str check . o)
  (let ((pred (make-char-predicate check))
        (end (if (and (pair? o) (pair? (cdr o)))
                 (cadr o)
                 (string-cursor-end str))))
    (let lp ((i (if (pair? o) (car o) (string-cursor-start str))))
      (cond ((string-cursor>=? i end) end)
            ((pred (string-cursor-ref str i)) i)
            (else (lp (string-cursor-next str i)))))))

(define (string-find? str check . o)
  (let ((start (if (pair? o) (car o) (string-cursor-start str)))
        (end (if (and (pair? o) (pair? (cdr o)))
                 (cadr o)
                 (string-cursor-end str))))
    (string-cursor<? (string-find str check start end) end)))

(define (string-find-right str check . o)
  (let ((pred (make-char-predicate check))
        (start (if (pair? o) (car o) (string-cursor-start str))))
    (let lp ((i (if (and (pair? o) (pair? (cdr o)))
                    (cadr o)
                    (string-cursor-end str))))
      (let ((i2 (string-cursor-prev str i)))
        (cond ((string-cursor<? i2 start) start)
              ((pred (string-cursor-ref str i2)) i)
              (else (lp i2)))))))

(define (string-skip str check . o)
  (apply string-find str (complement (make-char-predicate check)) o))

(define (string-skip-right str check . o)
  (apply string-find-right str (complement (make-char-predicate check)) o))

(define string-join string-concatenate)

(define (string-split str . o)
  (let ((pred (make-char-predicate (if (pair? o) (car o) #\space)))
        (limit (if (and (pair? o) (pair? (cdr o)))
                   (cadr o)
                   (+ 1 (string-size str))))
        (start (string-cursor-start str))
        (end (string-cursor-end str)))
    (if (string-cursor>=? start end)
        '()
        (let lp ((i start) (n 1) (res '()))
          (cond
           ((>= n limit)
            (reverse (cons (substring-cursor str i) res)))
           (else
            (let* ((j (string-find str pred i))
                   (res (cons (substring-cursor str i j) res)))
              (if (string-cursor>=? j end)
                  (reverse res)
                  (lp (string-cursor-next str j) (+ n 1) res)))))))))

(define (string-trim-left str . o)
  (let ((pred (make-char-predicate (if (pair? o) (car o) #\space))))
    (substring-cursor str (string-skip str pred))))

(define (string-trim-right str . o)
  (let ((pred (make-char-predicate (if (pair? o) (car o) #\space))))
    (substring-cursor str
                      (string-cursor-start str)
                      (string-skip-right str pred))))

(define (string-trim str . o)
  (let* ((pred (if (pair? o) (car o) #\space))
         (left (string-skip str pred))
         (right (string-skip-right str pred)))
    (if (string-cursor>=? left right)
        ""
        (substring-cursor str left right))))

(define (string-mismatch prefix str)
  (let ((end1 (string-cursor-end prefix))
        (end2 (string-cursor-end str)))
    (let lp ((i (string-cursor-start prefix))
             (j (string-cursor-start str)))
      (if (or (string-cursor>=? i end1)
              (string-cursor>=? j end2)
              (not (eq? (string-cursor-ref prefix i) (string-cursor-ref str j))))
          j
          (lp (string-cursor-next prefix i) (string-cursor-next str j))))))

(define (string-mismatch-right suffix str)
  (let ((end1 (string-cursor-start suffix))
        (end2 (string-cursor-start str)))
    (let lp ((i (string-cursor-prev suffix (string-cursor-end suffix)))
             (j (string-cursor-prev str (string-cursor-end str))))
      (if (or (string-cursor<? i end1)
              (string-cursor<? j end2)
              (not (eq? (string-cursor-ref suffix i) (string-cursor-ref str j))))
          j
          (lp (string-cursor-prev suffix i) (string-cursor-prev str j))))))

(define (string-prefix? prefix str)
  (string-cursor=? (string-cursor-end prefix) (string-mismatch prefix str)))

(define (string-suffix? suffix str)
  (let ((diff (- (string-size str) (string-size suffix))))
    (and (>= diff 0)
         (string-cursor=? (string-cursor-prev suffix
                                              (string-cursor-start suffix))
                          (string-cursor-back
                           str
                           (string-mismatch-right suffix str)
                           diff)))))

(define (string-fold kons knil str . los)
  (if (null? los)
      (let ((end (string-cursor-end str)))
        (let lp ((i (string-cursor-start str)) (acc knil))
          (if (string-cursor>=? i end)
              acc
              (lp (string-cursor-next str i)
                  (kons (string-cursor-ref str i) acc)))))
      (let ((los (cons str los)))
        (let lp ((is (map string-cursor-start los))
                 (acc knil))
          (if (any (lambda (str i)
                     (string-cursor>=? i (string-cursor-end str)))
                   los is)
              acc
              (lp (map string-cursor-next los is)
                  (apply kons (append (map string-cursor-ref los is)
                                      (list acc)))))))))

(define (string-fold-right kons knil str)
  (let ((end (string-cursor-end str)))
    (let lp ((i (string-cursor-start str)))
      (if (string-cursor>=? i end)
          knil
          (kons (string-cursor-ref str i) (lp (string-cursor-next str i)))))))

(define (string-count str check)
  (let ((pred (make-char-predicate check)))
    (string-fold (lambda (ch count) (if (pred ch) (+ count 1) count)) 0 str)))

(define (make-string-searcher needle)
  (lambda (haystack) (string-contains haystack needle)))

(define (string-downcase-ascii s)
  (call-with-output-string
   (lambda (out)
     (string-for-each (lambda (ch) (write-char (char-downcase ch) out)) s))))

(define (string-upcase-ascii s)
  (call-with-output-string
   (lambda (out)
     (string-for-each (lambda (ch) (write-char (char-upcase ch) out)) s))))

