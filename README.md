#parse-dates

##Overview

The parse-dates module makes it easy to parse ambiguous date formats. Does "2/3/2012" refer to February 3, 2012 or to March 2, 2012? Taken by itself, this cannot be answered reliably. But, if it is part of a list of dates - perhaps 2/3/2012, 2/5/2013, 3/26/2012 - you can easily infer from the third date that the month is being placed before the day. After all, there is no 26th month. This module takes advantage of that insight. 

The parse-dates module also makes it easy to parse such date formats in 193 languages. One can parse "декабря 2003" or "4 avr 1989" in the same way that one would parse "December 2003" or "4 April 1989". It does so by extracting month names and abbreviations, as well as ordinal markers (st, rd, th, etc.), from the Unicode Common Locale Data Repository (CLDR) files.

It is very easy to come up with pathological lists of dates, where the tricks used to resolve ambiguous date orders won't work, but typically dates in such lists won't be reliably interpretable even by a human. In practice, this approach generally works. On the other hand, the support for multiple languages is more brittle and currently fails outright for some languages. Furthermore, parse-dates simply assumes that all date strings refer to the Gregorian calendar.  

##Usage

This is written in Racket. I haven't added it to Planet yet, but it should be easy to download and then use with:

	(require "parse-dates.rkt")

The module provides a single function - `create-date-parser` - that takes a list of exemplary dates and a list of language codes and returns a function that will parse the kinds of date strings sent to `create-date-parser`:

	(define date-parser (create-date-parser '("14/3/2012" "1/4/2012" "6/4/2012" "12/4/2012") '("en")))
	(date-parser "2/8/2012")
	==> (parsed-date 'resolved-unambiguously 'gregorian 2 8 2012)

	(define date-parser (create-date-parser '("3/14/2012" "4/1/2012" "4/6/2012" "4/12/2012") '("en")))
	(date-parser "2/8/2012")
	==> (parsed-date 'resolved-unambiguously 'gregorian 8 2 2012)

The function returned by `create-date-parser` will, in turn, return a `parsed-date` struct. The final three numbers in the parsed-date structure that is returned represent the day, month, and year.  Note that, although the same date string was parsed in both instances, it was parsed in different ways.

When the language of the file is unknown, a list of plausible language codes may be passed to `create-date-parser`.  If, for instance, one was dealing with a collection of files known to be from Canada, one might specify both English and French.

	(define date-parser (create-date-parser '("8 février 2012" "20 févr 2012" "6 avril 2012" "13 juin 2012") '("en" "fr")))
	(date-parser "14 janvier 2013")
	==> (parsed-date 'unambiguous 'gregorian 14 1 2013)

It would have worked just as well if the dates had turned out to be in English. It is unusual for the month names and abbreviations of languages to conflict, with the same month name referring to what are actually different months, but if this happens, a warning will be printed to stderr.

The language codes are those used in the Unicode CLDR data. These are generally the two-letter ISO 639-1 codes, the list of which may be found here <http://www.sil.org/iso639-3/codes.asp?order=639_1&letter=%25>. Full details on CLDR language codes are at <http://cldr.unicode.org/index/cldr-spec/picking-the-right-language-code>.

The returned parsed-date structure also includes two tags.  One is for the calendar type, which, at this point, is always `'gregorian`. The other tag clarifies the reliability of the parse:

* `'unambiguous` - The order of the date components is clear even without taking into account the other dates in the list
* `'resolved-unambiguously` - So long as the best inference from the dates in the list was that the order of date components was consistent, the order in this particular date may be considered clear.
* `'resolved-ambiguously` - The list of dates on which the parser was trained contained inconsistent date component orders,
so the ambiguity in this particular date could not be reliably resolved. These would be dates that should, ideally, be looked over by a human.
* `'unclear/invalid` - The date is not actually a date, or the list of dates on which the parser was trained provided no basis for even tentatively guessing the order of its components.

Note that the parser does not check whether the date is actually valid. For example, `"Feb. 31, 2012"` will be
parsed as `(parsed-date 'unambiguous 'gregorian 31 2 2012)` even though there is no 31st day in February.

The names of the `parsed-date` struct's components are `reliability`, `calendar`, `day`, `month`, `year`, and their values may be extracted in the normal way:

	(define date-parser (create-date-parser '("8 février 2012" "20 févr 2012" "6 avril 2012" "13 juin 2012") '("en" "fr")))
	
	(define pd (date-parser "14 janvier 2013"))
	
	pd
	==> (parsed-date 'unambiguous 'gregorian 14 1 2013)
	
	(parsed-date-reliability pd)
	==> 'unambiguous
	
	(parsed-date-calendar pd)
	==> 'gregorian
	
	(parsed-date-day pd)
	==> 14
	
	(parsed-date-month pd)
	==> 1
	
	(parsed-date-year pd)
	==> 2013

In terms of formats, the parser is quite permissive. All of these will be handled well (and in any language):

	3/2/1989
	March 2, 1989
	2nd March 1989
	3-2-1989
	1989-March-02
	Mar. 2
	1989

The main circumstances in which the parser is likely to break down is when the string being parsed contains more than just
a date. It is particularly likely to produce bad results if that other information contains numbers. For example, 
`"12:30pm 2/5/89"` will not be properly parsed. On the other hand, both `"2/5/89 12:30pm"` and `"It happened on the 16th of May,
2012"` will be properly parsed. But, while the parser will often get lucky, it is designed to parse date strings - not to 
extract date strings from text.

##Issues and extensions

* The parsing does not currently handle run together dates such as "20120525". This is moderately problematic for English and very 
  problematic for languages that seldom if ever put spaces in dates. Thus, Japanese dates such as "2005年7月10日生" are *not* parsed at 
  this time. Presumably, there are other languages in which common ways of formatting dates slip through the cracks of the
  module's regular expressions.

* Currently, it is assumed that the dates are expressed in terms of the Gregorian calendar. But the logic used to figure
  out the order of date components could readily be applied to also identify the calendar being used. Script and language could be used 
  to resolve lingering ambiguity.

* Although there is little point until support for additional calendars is added, at that point support for alternative scripts for 
  numbers should also be added. The characters used for digits in various languages can be found in core/common/supplemental/
  numberingSystems.xml of the CLDR data.

* The Unicode CLDR data from which month names and abbreviations are drawn is intended for displaying in the locale-specific canonical
  form, not for parsing the messier ways in which humans actually type dates. Thus, common variations are missing. (While "Sep" denotes   
  the ninth month in English, "Sept" does not.) Library users should be able to provide a custom names file that would be merged with  
  the contents of the month-name-data.rkt at run time.

* Similarly, while the parsing is case-insensitive ("Dec" and "dec" are both understood to refer to the 12th month), it does not handle 
  the common problem of people leaving off accents ("févr" is understood to refer to the second month in French, but "fevr" is not). A 
  general solution would have to take advantage of the Unicode transliteration tables (which have not yet been packaged up as a library  
  in Racket), but the most common cases could be handled with some ad hoc string substitution.

* The parsing will infer that the 89 in "13 July 89" refers to a year, but it will not speculate on the century to which 
  that year belongs. While some lists of dates may have some fully-expanded and some abbreviated years, it may be more useful simply
  to allow the user to pass `create-date-parser` a (less than a century) year span, such as 1913-2012, in which ambiguous years will
  be assumed to fall and expanded accordingly.

* The inference should be a bit more probabilistic and based on syntax. While the list "May 13", "February 21", "January 8"
  technically fails to clarify whether the numbers refer to years or to days, it is clear to a human that they are far
  more likely to refer to days. Doing this in a language independent manner may, however, be more challenging, perhaps requiring the
  parsing to be more language-conscious than it is at the moment.

* Using the same basic idea of resolving ambiguities through the characteristics of the list it would be fairly easy to
  determine whether the dates are in plausibly ascending/descending chronological order and, if so, infer missing values.
  For example, in the list 13 Feb 2010, 14 Feb, 20 Feb 2010, one may reasonably guess that the second entry's year is 2010. 

##License

This module is under the MIT License (see LICENSE.txt). The Unicode CLDR data from which month-name-data.rkt and ordinal-markers-data.rkt are derived is subject to the Unicode Terms of Use (http://unicode.org/copyright.html).
