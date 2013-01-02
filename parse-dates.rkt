#lang racket

;parse-dates.rkt

(define (create-date-parser date-str-list)
  (let ([strip-nums (lambda (tag-num-list) (map car tag-num-list))])
    (let ([resolution-hash
           (best-ambiguous-resolutions
            (count-values
             (map (compose reduce strip-nums parse-date-semantic parse-date-syntactic) date-str-list)))])
      (lambda (s)
        (let* ([pd (parse-date-semantic (parse-date-syntactic s))]
               [pdf (reduce (strip-nums pd))])
          (if (unambiguous-date-format? pdf)
              (cons 'unambiguous (map (lambda (e) (cons (caar e) (cdr e))) pd))
              (let* ([resolving-formats (hash-ref resolution-hash pdf '())]
                     [format-to-use (if (not (empty? resolving-formats)) (caar resolving-formats) #f)])
                (if format-to-use
                    (cons (if (= (length resolving-formats) 1) 'resolved-unambiguously 'resolved-ambiguously)
                          (map (lambda (o n) (cons (car n) (cdr o))) pd format-to-use))
                    'unclear/invalid))))))))
    
;===== BASIC PARSING (NOT TAKING INTO ACCOUNT THE LIST OF DATES AS A WHOLE) =====

(define (parse-date-semantic tag-num-lst)
  (map 
   (match-lambda [(cons tag num)
     (cond [(eq? tag 'day)   `((day) . ,num)]
           [(eq? tag 'month) `((month) . ,num)]
           [(eq? tag 'year)  `((year) . ,num)]
           [(> num 31)       `((year) . ,num)]
           [(> num 12)       `((day year) . ,num)]
           [(> num 0)        `((day month year) . ,num)]
           [else             `((invalid) . ,num)])])
   tag-num-lst))

(define parse-date-syntactic
  (let ([month-name-hash
         (let* ([month-fullnames '("january" "february" "march" "april" "may" "june" "july" "august" "september" "october" "november" "december")]
                [month-abbreviations (map (lambda (s) (substring s 0 3)) month-fullnames)])
           (let ([h (make-hash)])
             (for ([nlst (in-list (list month-fullnames month-abbreviations))])
               (for ([i (in-range 1 13)] [n (in-list nlst)])
                 (hash-set! h n i)))
             (hash-set! h "sept" 9)
             h))]
        [ordinals-list '("st" "nd" "rd" "th")])
    (let ([r:def-day (pregexp (string-append "^" "([[:digit:]]{1,2})" "(?i:" (string-join ordinals-list "|") ")" "$"))]
          [r:def-month (pregexp (string-append "^(?i:" (string-join (hash-keys month-name-hash) "|") ")$"))]
          [r:num1-4 (pregexp (string-append "^" "[[:digit:]]{1,4}" "$"))])
      (lambda (s) 
        (let ([tokens (filter (lambda (t) (not (string=? t ""))) (regexp-split  #px"\\p{P}|\\p{Z}" s))])
          (let ([r (filter-map
                    (lambda (t)
                      (let ([def-day (regexp-match r:def-day t)])
                        (if (and def-day (second def-day))
                            (cons 'day (string->number (second def-day)))
                            (if (regexp-match r:def-month t)
                                (cons 'month (hash-ref month-name-hash (string-downcase t)))
                                (if (regexp-match r:num1-4 t)
                                    (cons 'unknown (string->number t))
                                    #f)))))
                    tokens)])
            (if (> (length r) 3) (take r 3) r)))))))

;===== LOGIC OF INFERRING THE DATE FORMAT(S) USED IN A LIST OF DATES =====

;> (best-ambiguous-resolutions (count-values '(((day) (month) (year)) 
;                                              ((day month) (day month) (year)) 
;                                              ((day) (month) (year)) 
;                                              ((month) (day) (year)) 
;                                              ((month year) (month year) (day)) 
;                                              ((year) (month) (day)))))
;'#hash((((month year) (month year) (day)) . ((((year) (month) (day)) . 1)))
;       (((day month) (day month) (year)) . ((((day) (month) (year)) . 2) (((month) (day) (year)) . 1))))
(define (best-ambiguous-resolutions format-counts)
  (let ([fc-lst (hash->list format-counts)])
    (let-values ([(unambiguous ambiguous) (partition (match-lambda [(cons f c) (unambiguous-date-format? f)]) fc-lst)])
      (make-hash
       (map (match-lambda [(cons famb camb)
              (cons famb
                    (sort 
                     (filter-map (match-lambda [(cons funamb cunamb) 
                                   (if (formats-consistent? famb funamb) (cons funamb cunamb) #f)])
                                 unambiguous)
                     >
                     #:key cdr))])
            ambiguous)))))

;> (unambiguous-date-format? '((day) (month) (year)))
;#t
;> (unambiguous-date-format? '((day month) (day month) (year)))
;#f
(define (unambiguous-date-format? f)
  (and (not (empty? f))
       (not (eq? f '(invalid)))
       (andmap (lambda (e) (= (length e) 1)) f)))

;> (formats-consistent? '((day) (month) (year)) '((day month) (day month) (year)))
;#t
;> (formats-consistent? '((day) (month) (year)) '((year) (month) (day)))
;#f
(define (formats-consistent? f1 f2)
  (and (= (length f1) (length f2))
       (andmap (lambda (e1 e2) (not (empty? (intersection e1 e2)))) f1 f2)))

;===== UTILITIES =====
;These are fairly general, actually, but came in handy here

;(partition-pred number? '(a 2 b 3))
;'(a)
;2
;'(b 3)
;> (partition-pred number? '(a b c))
;'(a b c)
;#f
;'()
(define (partition-pred pred lst)
  (let h [(rem lst) (acc '())]
    (if (empty? rem)
        (values (reverse acc) #f '())
        (if (pred (car rem))
            (values (reverse acc) (car rem) (cdr rem))
            (h (cdr rem) (cons (car rem) acc))))))

;> (reduce '((day year) (day month year) (year)))
;'((day) (month) (year))
;> (reduce '((day month) (day month) (year)))
;'((day month) (day month) (year))
(define (reduce lst-of-lsts [already-found '()])
  (let-values ([(before found after) 
                (partition-pred 
                 (lambda (sl) 
                   (and (= 1 (length sl)) 
                        (not (member sl already-found)))) 
                 lst-of-lsts)])
    (if found
        (reduce
         (append (map (lambda (e) (remove (car found) e)) before)
                 (list found)
                 (map (lambda (e) (remove (car found) e)) after))
         (cons found already-found))
        lst-of-lsts)))

;> (count-values '(a a b a b c))
;'#hash((a . 3) (b . 2) (c . 1))
;> (count-values '(((day) (month) (year)) ((day month) (day month) (year)) ((day) (month) (year))))
;'#hash((((day month) (day month) (year)) . 1) (((day) (month) (year)) . 2))
(define (count-values lst [ch (hash)])
  (if (empty? lst)
      ch
      (count-values (cdr lst) (hash-update ch (car lst) (lambda (v) (+ 1 v)) 0))))
      
;> (intersection '(b a b) '(c a a d e f))
;'(a)
(define (intersection a b)
  (let h ([a a] [b b] [i '()])
    (if (or (empty? a) (empty? b))
        i
        (if (member (car a) b)
            (h (remove (car a) (cdr a)) (remove (car a) b) (cons (car a) i))
            (h (remove (car a) (cdr a)) b i)))))
  
(provide create-date-parser)

  
