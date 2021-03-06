require! fs
lang = process.argv.2

unless lang in <[ a t ]>
  console.log "Please invoke this as 'json2prefix.ls a' or 'json2prefix.ls t'."
  process.exit!

fs.mkdir-sync lang unless fs.exists-sync lang
grok = -> JSON.parse(fs.read-file-sync it)
dump = (file, data) ->
  console.log "Writing: #file"
  fs.write-file-sync file, JSON.stringify data

if lang is \t
  entries = grok(\dict-twblg.json) ++ grok(\dict-twblg-ext.json)
else
  entries = grok(\dict-revised.pua.json)

prefix = {}
defs = {}
buckets = {}
i = 0
for {title, heteronyms}:entry in entries
  continue if title is /\{\[[0-9a-f]{4}\]\}/ # Unsubstituted
  continue if title is /\uDB40[\uDD00-\uDD0F]/ # Variant
  continue if title is /[⿰⿸]/
  pre = title.slice(0, 1)
  code = pre.charCodeAt(0)
  if 0xD800 <= code <= 0xDBFF
    pre = title.slice(0, 2)
    code = pre.charCodeAt(1) - 0xDC00
    post = title.slice(2)
  else
    post = title.slice(1)
  prefix[pre] ?= ''
  prefix[pre] += "|#post" if post.length
  # throw "Impossible: #title" if defs[title]
  defs[title] = entry

fs.write-file-sync \prefix.json JSON.stringify prefix

codepoints-of = -> it.length - it.split( /[\uD800-\uDBFF][\uDC00-\uDFFF]/g ).length + 1

trie = prefix
abbrevToTitle = {}
lenToTitles = {}
lenToRegex = {}
lens = []
for k, v of trie
  prefix-length = codepoints-of k
  for suffix in v / '|'
    abbrevIndex = suffix.indexOf '('
    if abbrevIndex >= 0
      orig = suffix
      suffix.=slice(0, abbrevIndex)
      abbrevToTitle["#k#suffix"] = "#k#orig"
    (lenToTitles[prefix-length + suffix.length] ?= []).push "#k#suffix"

for len, titles of lenToTitles
  lens.push len
  titles.sort!
  lenToRegex[len] = (titles * \|).replace(/[-[\]{}()*+?.,\\#\s]/g, "\\$&")
  fs.write-file-sync "lenToRegex.#len.json" JSON.stringify {"#len": (titles * \|).replace(/[-[\]{}()*+?.,\\#\s]/g, "\\$&")}

lens.sort (a, b) -> b - a

for len in [2 3 4]
  titles = lenToTitles[len]
  cur = ''
  re = ''
  for t in titles
    one = t.slice(0, 1)
    two = t.slice(1)
    code = one.charCodeAt(0)
    if 0xD800 <= code <= 0xDBFF
      one = t.slice(0, 2)
      two = t.slice(2)
    if one is cur
      re += "|" if len isnt 2
      re += two
    else
      re += "]|#one[#two" if len is 2
      re += ")|#one(#two" if len isnt 2
    cur = one
  re = re.replace(/\[(.|[\uD800-\uDBFF].)\]/g '$1') if len is 2
  re = re.replace(/\(([^|]+)\)/g '$1') if len isnt 2
  re = re.slice(2).replace(/[-{}*+?.,\\#\s]/g, "\\$&")
  re += "]" if len is 2
  re += ")" if len isnt 2
  dump "#lang/lenToRegex.#len.json" {"#len": re}
  lenToRegex[len] = re

dump "#lang/precomputed.json" { abbrevToTitle }
dump "#lang/lenToRegex.json" { lenToRegex }
