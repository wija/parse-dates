#lang racket

;cldr-date-utils.rkt

;This extracts language-specific month names and abbreviations as well as ordinal markers from the Unicode Common Locale 
;Data Repository files.  These can be downloaded from  http://cldr.unicode.org/index/downloads (only core.zip is required) 
;and are subject to the Unicode Terms of Use (http://unicode.org/copyright.html).  The functions below have been been tested 
;on version 22.1, although future revisions will most likely work fine.

;The files month-name-data.rkt and ordinal-markers-data.rkt are serializations of Racket data structures produced by
;write-month-names-file and write-ordinal-markers-file, below.  It is these serializations that are read and used by
;get-month-name-hash and get-ordinal-markers (the only functions exported from this module).  Thus, there is no need
;to download the Unicode CLDR files unless one wants to update the data or modify these functions.

;The main point to note is that these utilities extract data without wrangling with the full complexity of the CLDR
;data. On the whole, this does not matter, but edge cases that may emerge could well be due to this. First, the Unicode
;Locale Data Markup Language (UDML) - http://unicode.org/reports/tr35/tr35-25.html - defines systems of inheritance whereby,
;most relevantly here, language files (en.xml, etc.) provide common data, and region files (en_US.xml, en_GB.xml, etc.)
;provide region- (typically country-) specific variations. The utilities here ignore these inheritance relationships and
;simply extract month names and ordinal markers from the language files. Logically, this would rarely matter - e.g., the US
;and the UK use the same month names. Empirically, as of CLDR version 22.1, there are no additional month names or ordinal markers
;in the skipped files, although this is not quite the same thing as saying with complete confidence that a fully specified locale
;would not return different data than a language-only locale. In other words, it doesn't really matter, but, then again, you may
;discover that it does!

;Second, and more importantly, the CLDR data does not actually include lists of ordinal markers - for English, "th", "st", "nd",
;and "rd". Instead, it includes *rules* for displaying raw numbers as ordinals in a locale-specific manner. These rules are written
;in the relatively complex Rule-Based Number Formatting language (see http://www.unicode.org/reports/tr35/#Rule-Based_Number_Formatting
;and http://www.icu-project.org/apiref/icu4c/classRuleBasedNumberFormat.html).  This library wholly ignores the complexity of RBNF
;and simply filters out the rules and grabs whatever bare markers are included.  This is unlikely to result in the false detection
;of ordinals, but it will certainly result in the failure to detect some ordinals.  That said, meaningfully fixing this would require
;not only writing an RBNF parser but also making the regular expressions used to parse dates language-specific.  For most purposes -
;certainly for my purposes - this is not at all worth the trouble.  But to each their own.

;Finally, and most importantly, there are limitations that derive from the different intended purposes of the CLDR data and
;this library. The CLDR data is meant to help programmers *display* data in a locale-appropriate manner; this library is 
;meant to help programmers *parse* data that varies across locales.  Naturally, the CLDR data includes only the favored/canonical
;month names and abbreviations; whereas, this library should ideally cope with the messier range of ways in which humans actually
;write down dates.  This library takes two limited steps to do so: Ignoring case and ignoring trailing periods on abbreviations.  
;But it does not handle the absence of accents ("févr" denotes the second month in French, but "fevr" does not), and it does not
;handle common variations ("Sep" denotes the ninth month in English, but "Sept" does not).  The first problem could be ameliorated
;with some quick hacks but requires use of the Unicode transliteration data to solve it more generally; this would be 
;straightforward in a JVM-based language, but no one has written a Racket library for the purpose.  The second problem suggests
;that, at a minimum, library users should be able to provide a custom names file that would be merged with the contents of the 
;month-name-data.rkt at run time, but I haven't done this yet.

(require (planet clements/sxml2:1:=3))
 
;======= RETRIEVING THE MONTH NAME AND ORDINAL INFORMATION FOR USE IN OTHER PROGRAMS =======

;(get-month-name-hash '("en" "fr" "ru"))
;==> '#hash(("march" . 3)
;           ("déc" . 12)
;           ("нояб" . 11)
;           ("oct" . 10)
;           ("juil" . 7)
;           . . .)
;
;If #:warnings? is set to #t, a warning is printed to stderr when the same name/abbrev corresponds to a different month number 
;in different of the requested languages.
(define (get-month-name-hash unicode-language-codes #:warnings? [warnings? #t])
  (let* ([deserialized-list (call-with-input-file "month-name-data.rkt" (curry read) #:mode 'binary)]
         [requested-sublist (filter (lambda (lc-name-num) (member (car lc-name-num) unicode-language-codes)) deserialized-list)]
         [alist (map cdr requested-sublist)])
    (if warnings? 
        (make-hash/warn-on-overwrite alist)
        (make-hash alist))))

;(get-ordinal-markers '("en")) ==> '("th" "st" "nd" "rd")
(define (get-ordinal-markers unicode-language-codes)
   (let* ([deserialized-list (call-with-input-file "ordinal-markers-data.rkt" (curry read) #:mode 'binary)]
         [requested-sublist (filter (lambda (lc-name-num) (member (car lc-name-num) unicode-language-codes)) deserialized-list)])
     (remove-duplicates (map cdr requested-sublist))))

;======= EXTRACTING MONTH NAMES FROM UNICODE CLDR FILES AND SERIALIZING TO FILE =======

(define (write-month-names-file #:cldr-path [cldr-path "core/common/main/"] #:output-path [output-path "month-name-data.rkt"])
  (let ([lc-name-num-list
         (apply append            
                (filter (compose not false?)
                        (for/list ([fp (in-directory cldr-path)])
                          (let-values ([(base name must-be-dir?) (split-path fp)])
                            (let ([name (path-element->string name)])
                              (if (not (regexp-match #px"_" name)) ;only look at the language files, not the country files
                                  (let ([language-code (car (regexp-match #px"[[:alpha:]]*" name))])
                                    (map (match-lambda [(cons name num)
                                                        (cons language-code 
                                                              (cons (string-downcase (remove-trailing-character name #\.)) 
                                                                    num))])
                                         (get-gregorian-month-names-alist language-code)))
                                  #f))))))])
    (call-with-output-file "month-name-data.rkt"
      (curry write lc-name-num-list)
      #:mode 'binary
      #:exists 'replace)))

(define (get-gregorian-month-names-alist unicode-language-code)
  (let* ([main-sxml (call-with-input-file (string-append "core/common/main/" (string-downcase unicode-language-code) ".xml")
                      (curryr ssax:xml->sxml '()))]
         [months-sxml ((sxpath "/ldml/dates/calendars/calendar[@type='gregorian']/months/monthContext[@type='format']/monthWidth[@type='abbreviated' or @type='wide']") main-sxml)])
    (map cons 
         ((sxpath "/month/text()") months-sxml)
         (map string->number ((sxpath "/month/@type/text()") months-sxml)))))

;======= EXTRACTING ORDINAL MARKERS FROM UNICODE CLDR FILES AND SERIALIZING TO FILE =======
    
(define (write-ordinal-markers-file)
  (let ([lc-ordmarker-list
         (apply append
                (filter (compose not empty?)
                        (for/list ([fp (in-directory "core/common/rbnf/")])
                          (let-values ([(base name must-be-dir?) (split-path fp)])
                            (let ([name (path-element->string name)])
                              (if (not (regexp-match #px"_" name)) ;only look at the language files, not the country files
                                  (let ([language-code (car (regexp-match #px"[[:alpha:]]*" name))])
                                    (map (curry cons language-code)  
                                         (get-ordinal-markers-list language-code)))
                                  '()))))))])
    (call-with-output-file "ordinal-markers-data.rkt"
      (curry write lc-ordmarker-list)
      #:mode 'binary
      #:exists 'replace)))

(define (get-ordinal-markers-list unicode-language-code)
  (let* ([main-sxml (call-with-input-file (string-append "core/common/rbnf/" (string-downcase unicode-language-code) ".xml")
                      (curryr ssax:xml->sxml '()))]
         [ordinals-sxml ((sxpath "/ldml/rbnf/rulesetGrouping[@type='OrdinalRules']/ruleset") main-sxml)])
    (filter-map
     (lambda (s)
       (cond [(string=? s "") #f]
             [(regexp-match #px"[−=→]" s) #f]
             [else (remove-trailing-character s #\;)]))
     ((sxpath "/rbnfrule/text()") ordinals-sxml))))

;======= GENERAL UTILITIES =======

;(make-hash/warn-on-overwrite '((a . 5) (b . 3) (a . 5) (a . 6)))
;==> Warning: Hash key a is being given value 6, overwriting previous value 5.
;==> '#hash((b . 3) (a . 6))
(define (make-hash/warn-on-overwrite alist)
  (let ([h (make-hash)])
    (for ([k-v (in-list alist)])
      (match-let ([(cons k v) k-v])
        (when (and (hash-has-key? h k) (not (= v (hash-ref h k))))
          (fprintf (current-error-port) "Warning: Hash key ~s is being given value ~s, overwriting previous value ~s.\n"
                   k v (hash-ref h k)))
        (hash-set! h k v)))
    h))
      
;(remove-trailing-character "feb." #\.) ==> "feb"
;(remove-trailing-character "feb" #\.)  ==> "feb"
(define (remove-trailing-character s c)
  (if (string=? s "")
      s
      (if (char=? c (string-ref s (- (string-length s) 1)))
          (substring s 0 (- (string-length s) 1))
          s)))

(provide get-month-name-hash get-ordinal-markers)
