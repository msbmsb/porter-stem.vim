" File:         porter-stem.vim
" Description:  Implements Porter Stemming in vim script
" Author:       Mitchell Bowden <mitchellbowden AT gmail DOT com>
" Version:      0.1
" License:      MIT License: http://creativecommons.org/licenses/MIT/
" Last Changed: 12 May 2010
" URL:          http://github.com/msbmsb/porter-stem.vim/

" -----------------------------------------------------------------------------
" PorterStem is a vim script that implements the Porter stemming
" algorithm, by Martin Porter, details of which can be found at:
"   http://tartarus.org/~martin/PorterStemmer/
" The main function outputs the single string of the stem, and the script only
" echoes the output to the screen. This script, while it can be used as-is
" if you want to know what the stem for a word is, is mostly a container for 
" the algorithm implementation in vim script.
" 
" PorterStem command syntax:
"   :PorterStem (<word>)*
"
" Each word input to the :PorterStem command will be stemmed and processed by
" the ProcessStem function, that by default simply echoes to the screen.
" Without any word given for input, it will attempt to stem the current word 
" under the cursor via expand('<cword>').
"
" For example:
"   :PorterStem searching
" will output:
"   search
" and a string of words will work as well, matching in order:
"   :PorterStem thieves are running from the bunny
" will output:
"   thiev are run from bunni
"
" Running :PorterTest <test-file> <expected-results-file> will run each 
" word in <test-file> and match the stem result to the same line in the 
" <expected-results-file>, showing if any are incorrect stem matches.
" Provided in the github repository are two files voc.txt and output.txt 
" from Martin Porter's site providing a set of test words. 
"
" -----------------------------------------------------------------------------

let s:save_cpo = &cpo
set cpo&vim

if exists('loaded_porterstem')
  finish
endif
let loaded_porterstem = 1

let &cpo = s:save_cpo

" Commands definition
" PorterStem command syntax:
"   :PorterStem (<word>)*
if !(exists(":PorterStem") == 2)
  com! -nargs=* PorterStem call s:PorterStem(<q-args>)
  com! -nargs=* PorterTest call s:PorterTest(<q-args>)
endif

" Test the stemmer with two input files
" Usage: :PorterTest <test-file> <expected-results-file>
fun! s:PorterTest(files_in)
  let testfiles = split(a:files_in, '\s\+')

  if len(testfiles) != 2
    echo "Usage: :PorterTest <test-file> <expected-results-file>"
    echo "This will print an error message if anything is incorrect"
    return
  endif

  echo "PorterTest: Running PorterTest..."

  let vocfile = testfiles[0]
  let vocoutfile = testfiles[1]
  let voc = readfile(vocfile)
  let vocout = readfile(vocoutfile)

  let i = 0
  let numIncorrect = 0
  for test in voc
    let stem = s:GetWordStem(test)
    if stem != vocout[i]
      echo "PorterTest: Incorrect: " . test . " -> " . stem . " not " . vocout[i]
      let numIncorrect = numIncorrect + 1
    endif
    let i = i + 1
  endfor

  if numIncorrect == 0
    echo "PorterTest: There were no incorrect stems"
  else
    echo "PorterTest: There were " . numIncorrect . " incorrect stems"
  endif
endfun

" Main function
fun! s:PorterStem(words_in)
  let words = split(a:words_in, '\s\+')
  let stems = []

  if len(words) == 0
    call insert(words, expand('<cword>'))
  endif

  for w in words
    call add(stems, s:GetWordStem(w))
  endfor

  call s:ProcessStems(stems)
endfun

fun! s:ProcessStems(stems)
  if len(a:stems) == 0
    return
  endif

  let stemstr = ""

  for s in a:stems
    let stemstr = stemstr . s . " "
  endfor

  echo "Stem result: " . stemstr
endfun

" Return word stem string
fun! s:GetWordStem(word)
  if len(a:word) <= 2
    return a:word
  endif

  let newword = a:word

  " initial y fix
  let changedY = 0
  if newword[0] == 'y'
    let newword = 'Y'.newword[1:]
    let changedY = 1
  endif

  " Porter Stemming
  let newword = s:Step1a(newword)
  let newword = s:Step1b(newword)
  let newword = s:Step1c(newword)
  let newword = s:Step2(newword)
  let newword = s:Step3(newword)
  let newword = s:Step4(newword)
  let newword = s:Step5a(newword)
  let newword = s:Step5b(newword)

  if changedY
    let newword = 'y'.newword[1:]
  endif

  return newword
endfun

"******************************************************
" Porter Stemming
" Variables and methods follow here
"******************************************************
let s:cons = '[^aeiou]'
let s:vow = '[aeiouy]'
let s:conseq = s:cons . '[^aeiouy]*'
let s:vowseq = s:vow . '[aeiou]*'

let s:mgr0 = '^\('.s:conseq.'\)\='.s:vowseq.s:conseq
let s:mgr1 = s:mgr0.s:vowseq.s:conseq
let s:meq1 = s:mgr0.'\('.s:vowseq.'\)\=$'
let s:vins = '^\('.s:conseq.'\)\='.s:vow
let s:gen = '^\(.\{-1,}\)\(ational\|tional\|enci\|anci\|izer\|bli\|alli\|entli\|eli\|ousli\|ization\|ation\|ator\|alism\|iveness\|fulness\|ousness\|aliti\|iviti\|biliti\|logi\)$'

let s:step2dict = { "ational" : "ate", "tional" : "tion", "enci" : "ence", "anci" : "ance", "izer" : "ize", "bli" : "ble", "alli" : "al", "entli" : "ent", "eli" : "e", "ousli" : "ous", "ization" : "ize", "ation" : "ate", "ator" : "ate", "alism" : "al", "iveness" : "ive", "fulness" : "ful", "ousness" : "ous", "aliti" : "al", "iviti" : "ive", "biliti" : "ble", "logi" : "log" }

let s:step3dict = { "icate" : "ic", "ative" : "", "alize" : "al", "iciti" : "ic", "ical" : "ic", "ful" : "", "ness" : "" }

fun! s:Step1a(word)
  let w = a:word
  if a:word[-1:] ==? 's'
    let re1a1 = '^\(.\+\)\(ss\|i\)es$'
    let re1a2 = '^\(.\+\)\([^s]\)s$'
    if w =~ re1a1
      let w = substitute(w, re1a1, '\1\2', "")
    elseif w =~ re1a2
      let w = substitute(w, re1a2, '\1\2', "")
    endif
  endif

  return w
endfun

fun! s:Step1b(word)
  let w = a:word
  let re1b1 = '^\(.\+\)eed$'
  let re1b2 = '^\(.\+\)\(ed\|ing\)$'
  if w =~ re1b1
    let stem = substitute(w, re1b1, '\1', "")
    if stem =~ s:mgr0
      let w = w[:-2]
    endif
  elseif w =~ re1b2
    let stem = substitute(w, re1b2, '\1', "")
    if stem =~ s:vins
      let w = stem
      let r1 = '\(at\|bl\|iz\)$'
      let r2 = '\([^aeiouylsz]\)\1$'
      let r3 = '^'.s:conseq.s:vow.'[^aeiouwxy]$'
      if w =~ r1
        let w = w . "e"
      elseif w =~ r2
        let w = w[:-2]
      elseif w =~ r3
        let w = w . "e"
      endif
    endif
  endif

  return w
endfun

fun! s:Step1c(word)
  let w = a:word
  if w[-1:] == 'y'
    let stem = w[:-2]
    if stem =~ s:vins
      let w = stem . "i"
    endif
  endif

  return w
endfun

fun! s:Step2(word)
  let w = a:word
  if w =~ s:gen
    let stem = substitute(w, s:gen, '\1', "")
    let suff = substitute(w, s:gen, '\2', "")
    if stem =~ s:mgr0
      let w = stem . s:step2dict[suff]
    endif
  endif

  return w
endfun

fun! s:Step3(word)
  let w = a:word
  let re3 = '^\(.\+\)\(icate\|ative\|alize\|iciti\|ical\|ful\|ness\)$'
  if w =~ re3
    let stem = substitute(w, re3, '\1', "")
    let suff = substitute(w, re3, '\2', "")
    if stem =~ s:mgr0
      let w = stem . s:step3dict[suff]
    endif
  endif

  return w
endfun

fun! s:Step4(word)
  let w = a:word
  let re41 = '^\(.\{-1,}\)\(al\|ance\|ence\|er\|ic\|able\|ible\|ant\|ement\|ment\|ent\|ou\|ism\|ate\|iti\|ous\|ive\|ize\)$'
  let re42 = '^\(.\+\)\(s\|t\)\(ion\)$'
  if w =~ re41
    let stem = substitute(w, re41, '\1', "")
    if stem =~ s:mgr1
      let w = stem
    endif
  elseif w =~ re42
    let stem = substitute(w, re42, '\1\2', "")
    if stem =~ s:mgr1
      let w = stem
    endif
  endif

  return w
endfun

fun! s:Step5a(word)
  let w = a:word
  if w[-1:] == "e"
    let stem = w[:-2]
    let re5a = '^'.s:conseq.s:vow.'[^aeiouwxy]$'
    if (stem =~ s:mgr1) || ((stem =~ s:meq1) && (stem !~ re5a))
      let w = stem
    endif
  endif

  return w
endfun

fun! s:Step5b(word)
  let w = a:word
  if (w =~ 'll$') && (w =~ s:mgr1)
    let w = w[:-2]
  endif

  return w
endfun
