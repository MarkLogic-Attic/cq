xquery version "1.0-ml";
(:
 : cq
 :
 : Copyright (c) 2002-2011 MarkLogic Corporation. All Rights Reserved.
 :
 : Licensed under the Apache License, Version 2.0 (the "License");
 : you may not use this file except in compliance with the License.
 : You may obtain a copy of the License at
 :
 : http://www.apache.org/licenses/LICENSE-2.0
 :
 : Unless required by applicable law or agreed to in writing, software
 : distributed under the License is distributed on an "AS IS" BASIS,
 : WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 : See the License for the specific language governing permissions and
 : limitations under the License.
 :
 : The use of the Apache License does not indicate that this project is
 : affiliated with the Apache Software Foundation.
 :
 : explore.xqy - fancy list of up to N documents, including root node type.
 :
 : TODO use cts:uris(), if available? interferes with element-display...
 :
 :)

import module namespace admin = "http://marklogic.com/xdmp/admin"
  at "/MarkLogic/admin.xqy";

import module namespace c = "com.marklogic.developer.cq.controller"
 at "lib-controller.xqy";

import module namespace d = "com.marklogic.developer.cq.debug"
 at "lib-debug.xqy";

import module namespace v = "com.marklogic.developer.cq.view"
  at "lib-view.xqy";

import module namespace x = "com.marklogic.developer.cq.xquery"
 at "lib-xquery.xqy";

declare option xdmp:mapping "false";

declare variable $FILTER as xs:string external;

declare variable $FILTER-TEXT as xs:string external;

declare variable $SIZE as xs:integer external;

declare variable $START as xs:integer external;

declare variable $USE-XSL as xs:boolean external;

declare variable $FILTER-QUERY as cts:query? :=
  let $d := d:debug(('explore-invokable: FILTER =', $FILTER))
  let $filter as cts:query? :=
    if ($FILTER eq '') then () else cts:query(xdmp:unquote($FILTER)/*)
  let $d := d:debug(('explore-invokable: FILTER-TEXT =', $FILTER-TEXT))
  let $filter-text as cts:query? :=
    if ($FILTER-TEXT eq '') then () else cts:word-query($FILTER-TEXT)
  return
    if (exists($filter) and exists($filter-text))
    then cts:and-query(($filter, $filter-text))
    else if (exists($filter-text)) then $filter-text
    else $filter
;

d:check-debug(),
d:debug(('explore-invokable:', $START, $SIZE)),

c:set-content-type(),

xdmp:query-trace($d:DEBUG),

d:debug(('explore-invokable:', $FILTER, $FILTER-TEXT)),
(: make sure we will not lock all the documents :)
c:assert-read-only(),
let $stop := $START + $SIZE - 1
let $query := $FILTER-QUERY
let $d := d:debug(('explore-invokable: query =', $query))
(: no point in trying cts:uris(), as we will retrieve N fragments anyhow :)
let $result := (
  if (exists($query)) then cts:search(doc(), $query, 'unfiltered')
  else doc()
)[$START to $stop]
let $count :=
  if (empty($query)) then xdmp:estimate(doc())
  else if ($result) then cts:remainder($result[1])
  else 0
let $database-name := xdmp:database-name($c:FORM-EVAL-DATABASE-ID)
let $actual-stop := min(($stop, $START + count($result) - 1))
return <html xmlns="http://www.w3.org/1999/xhtml">{
  element head { v:get-html-head() },
  element body {
    element p {
      attribute class { 'head2' },
      'Database ', element b { $database-name }, ' contains ',
      $count, 'document(s) total',
      if ($count) then (
        ' (viewing', $START, '-', concat(string($actual-stop), ')')
      )
      else ()
    },
    (: TODO display any filters in effect? :)
    for $i in $result
    let $uri := xdmp:node-uri($i)
    (: make sure we can handle oddball docs -
     : what if the root is a processing instruction?
     : empty doc is also possible, in XQuery 1.0
     :)
    let $n as node()* := $i/node()
    let $n as node()? :=
      if ($n instance of binary()) then $n
      else if ($n instance of text()) then $n
      else if ($n/self::*) then $n/self::*[1]
      (: comment, processing instruction, etc.
       : but if only text is present, a previous rule already matched
       :)
      else $n[not(. instance of text())][1]
    order by $uri
    return (
      element a {
        attribute href {
          c:build-form-eval-query(
            'view.xqy',
            ('uri', 'xsl'),
            ($uri, $USE-XSL)) },
        $uri
      },
      <span>&#160;&ndash;&#160;</span>,
      <i>{ if ($n) then xdmp:node-kind($n) else '(empty document)' }</i>,
      (: why not node-name? because this is a human-readable context :)
      <code class="qname">&#160;{ name($n) }&#160;</code>,
      element span {
        if (not($i/property::node())) then element i { '(no properties)' }
        else element a {
          attribute href {
            c:build-form-eval-query(
              'view.xqy',
              ('uri', 'properties', 'xsl'),
              ($uri, 1, $USE-XSL)
            )
          },
          '(properties)'
        }
      },
      <span>&#160;&#160;</span>,
      element span {
        let $collections := xdmp:document-get-collections($uri)
        return
          if (not($collections)) then element i { '(no collections)' }
          else (
            element i { 'collections' }, ':',
            let $count := count($collections)
            let $filters :=
              if (empty($query)) then ()
              else if ($query instance of cts:collection-query) then $query
              else cts:and-query-queries($query)
                [. instance of cts:collection-query]
            let $filters :=
              for $i in $filters return xdmp:quote( document { $i })
            for $c at $x in $collections
            let $term := xdmp:quote( document { cts:collection-query($c) })
            (: check for duplicate terms :)
            let $is-duplicate := ($filters = $term)
            let $filters :=
              ($filters, if ($is-duplicate) then () else $term)
            let $keys := for $i in $filters return 'filter'
            return (
              if ($is-duplicate) then element span { $c }
              else element a {
                attribute href {
                  c:pagination-href($START, $keys, $filters)
                },
                $c
              },
              if ($x ne $count) then '; ' else ()
            )
          )
      },
      (: TODO permissions? :)
      <br/>
    ),
    v:display-results-pagination($START, count($result), $count, $SIZE)
  }
}</html>

(: explore-invokable.xqy :)
