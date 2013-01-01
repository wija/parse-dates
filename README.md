#parse-dates

##Overview

The parse-dates module makes it easy to parse ambiguous date formats. Does "2/3/2012" refer to February 3, 2012 or to March 2, 2012? Taken by itself, this cannot be answered reliably, unless you already know which order is being used. But, if it is part of a list of dates - perhaps 2/3/2012, 2/5/2013, 3/26/2012 - you can easily infer from the third date that the month is being placed before the day. After all, there is no 26th month. This module takes advantage of that insight. 

It is very easy to come up with pathological lists of dates, where this trick won't work, but typically dates
in such lists won't be reliably interpretable even by human. In practice, this approach generally works.

##How to use parse-dates

This is written in Racket. I haven't added it to Planet yet, but it should be easy to download and then use with

	(require "parse-dates.rkt")

The module provides a single function: `create-date-parser`.

	(define date-parser (create-date-parser '("14/3/2012" "1/4/2012" "6/4/2012" "12/4/2012")))
	(date-parser "2/8/2012")
	==> '(resolved-unambiguously (day . 2) (month . 8) (year . 2012))

	(define date-parser (create-date-parser '("3/14/2012" "4/1/2012" "4/6/2012" "4/12/2012")))
	(date-parser "2/8/2012")
	==> '(resolved-unambiguously (month . 2) (day . 8) (year . 2012))

A date parser will tag the parsed dates with a symbol:

* `'unambiguous` - The order of the date components is clear even without taking into account the other dates in the list
* `'resolved-unambiguously` - So long as the best inference from the dates in the list was that the order of date components was consistent, the order in this particular date may be considered clear.
* `'resolved-ambiguously` - The list of dates on which the parser was trained contained inconsistent date component orders,
so the ambiguity in this particular date could not be reliably resolved. These would be dates that should, ideally, be looked over by a human.
* `'unclear/invalid` - The date is not actually a date, or the list of dates on which the parser was trained provided no basis for even tentatively guessing the order of its components.

Note that the parser does not check whether the date is actually valid. For example, `"Feb. 31, 2012"` will be
parsed as `(unambiguous (day . 31) (month . 2) (year . 2012))` even though there is no 31st day in February.

In terms of formats, the parser is quite permissive. All of these will be handled well:

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
2012"` will be properly parsed. But, while the parser will often get lucky, it is designed to parse date strings not to 
extract date strings from text.

##Issues and extensions

* The parsing does not currently handle run together dates such as "20120525".

* The inference should be a bit more probabilistic and based on syntax. While the list "May 13", "February 21", "January 8"
  technically fails to clarify whether the numbers refer to years or to days, it is clear to a human that they are far
  more likely to refer to days.

* The parsing only handles English-language month names and ordinal markers (st, th, etc.). It is trivial to change it to
  handle any other given language, but a more general solution would be to use the Unicode CLDR data to generate these
  lists automatically.

* Currently, it is assumed that the dates are expressed in terms of the Gregorian calendar. But the logic used to figure
  out the order of date components could readily be applied to also identify the calendar being used.
 
* Using the same basic idea of resolving ambiguities through the characteristics of the list it would be fairly easy to
  determine whether the dates are in plausibly ascending/descending chronological order and, if so, infer missing values.
  For example, in the list 13 Feb 2010, 14 Feb, 20 Feb 2010, one may reasonably guess that the second entry's year is 2010. 



