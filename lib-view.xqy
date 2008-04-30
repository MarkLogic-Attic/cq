xquery version "0.9-ml"
(:
 : cq: lib-view.xqy
 :
 : Copyright (c)2002-2008 Mark Logic Corporation. All Rights Reserved.
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
 :)

module "com.marklogic.developer.cq.view"

declare namespace v = "com.marklogic.developer.cq.view"

default function namespace = "http://www.w3.org/2003/05/xpath-functions"

declare namespace xh = "http://www.w3.org/1999/xhtml"

import module namespace c = "com.marklogic.developer.cq.controller"
 at "lib-controller.xqy"

import module namespace d = "com.marklogic.developer.cq.debug"
 at "lib-debug.xqy"

import module namespace io = "com.marklogic.developer.cq.io"
  at "lib-io.xqy"

define variable $v:NBSP as xs:string { codepoints-to-string(160) }

define variable $v:NL as xs:string { codepoints-to-string(10) }

define variable $v:MICRO-SIGN as xs:string { codepoints-to-string(181) }

define variable $v:ELLIPSIS as xs:string { codepoints-to-string(8230) }

define variable $v:PROFILER-COLUMNS as element(columns) {
  element columns {
    <column>location</column>,
    <column>expression</column>,
    <column>count</column>,
    element column {
      attribute title {
        "Time spent in the expression,",
        "not including time spent in sub-expressions."
      }, 'shallow-%' },
    element column {
      attribute title {
        "Time spent in the expression,",
        "not including time spent in sub-expressions."
      },
      concat('shallow-', $v:MICRO-SIGN, 's') },
    element column {
      attribute title {
        "Total time spent in the expression,",
        "including time spent in sub-expressions."
      },
      'deep-%' },
    element column {
      attribute title {
        "Total time spent in the expression,",
        "including time spent in sub-expressions."
      },
      concat('deep-', $v:MICRO-SIGN, 's') }
  }
}

define function v:get-xml($x)
 as element()
{
  let $count := count($x)
  return
  if ($count eq 1
    and ($x instance of element()
      or ($x instance of document-node() and exists($x/element())) )
  ) then ($x/descendant-or-self::*)[1]
  else element results {
    attribute warning {
      if (empty($x)) then "empty list"
      else if ($count eq 1) then "non-element node"
      else "more than one node"
    },
    for $i in $x
    return
      if ($i instance of document-node())
      then $i/node()
      else $i
  }
}

define function v:get-html($x as item()*)
 as element(xh:html)
{
  let $profile as element(prof:report)? :=
    $x[1][. instance of element(prof:report)]
  let $body :=
    for $i in $x
    return if ($i instance of document-node()) then $i/node() else $i
  return
    if (count($body) eq 1
      and ($body instance of element())
      and node-name($body) eq xs:QName('xh:html'))
    then $body
    else <html xmlns="http://www.w3.org/1999/xhtml">
    {
      if ($profile)
      then v:get-html-head('Profile for Query', true())
      else <head><title>Query Results</title></head>
    }
    <body bgcolor="white">
    {
      if (empty($body)) then <i>your query returned an empty sequence</i>
      else
        for $i at $x in $body
        return
          if ($i instance of element(prof:report))
          then v:format-profiler-report($i)
          else if ($profile) then
            if ($i instance of binary())
            then xdmp:describe($i)
            else xdmp:quote($i)
          else $i
    }
    </body>
  </html>
}

define function v:get-text($x as item()+)
 as item()+
{
  $x
}

define function v:get-error-frame-html(
  $f as element(err:frame), $query as xs:string)
 as element()*
{
  d:debug(('v:get-error-frame-html:', $f)),
  if (exists($f/err:uri))
  then concat("in ", string($f/err:uri))
  else (),
  if (exists($f/err:line))
  then
    let $line-no := xs:integer($f/err:line)
    return (
    concat("line ", string($line-no), ": "),
    (: display the error lines, if it's in a main module :)
    if (exists($f/err:uri)) then ()
    else <xh:div id="error-lines" class="code">
    {
      for $l at $x in tokenize($query, "\r\n|\r|\n", "m")
      where $x gt ($line-no - 3) and $x lt (3 + $line-no)
      return (
        concat(string($x), ": "),
        element xh:span {
          if ($x eq $line-no) then attribute class { "error" } else (),
          $l
        },
        <xh:br/>
      )
    }
    </xh:div>,
    <xh:br/>
  )
  else (),

  $f/err:operation/text(),
  <xh:br/>,

  if (exists($f/err:format-string/text()))
  then $f/err:format-string/text()
  else $f/err:code/text(),
  <xh:br/>,

  text { $f/err:data/err:datum },

  (: this may be empty :)
  for $v in $f/err:variables/err:variable
  return (
    element xh:code {
      concat("$", string($v/err:name)), ":=", data($v/err:value) },
    <xh:br/>),

  <xh:br/>
}

define function v:get-error-html(
  $db as xs:unsignedLong, $modules as xs:unsignedLong,
  $root as xs:string, $ex as element(err:error),
  $query as xs:string)
 as element(xh:html)
{
  d:debug(('v:get-error-html:', $ex)),
<html xmlns="http://www.w3.org/1999/xhtml">
  { element head { v:get-html-head() } }
  <body bgcolor="white">
    <div>{
      element b {
        (: NOTE: format-string is sometimes empty. if so, we omit the br :)
        if (exists($ex/err:format-string/text()))
        then ($ex/err:format-string/text(), <br/>)
        else if (exists($ex/err:code/text()))
        then (text { $ex/err:code, $ex/err:data/err:datum }, <br/>)
        else ()
      },
      <br/>,
      (: display eval-in information :)
      element i {
        "query evaluated in",
        xdmp:database-name($db), "at",
        concat(
          if ($modules eq 0) then "file" else xdmp:database-name($modules),
          ":", $root )
      },
      <br/>,
      <br/>,
      <b><i>Stack trace:</i></b>,
      <br/>,
      <br/>,
      for $f in $ex/err:stack/err:frame
      return v:get-error-frame-html($f, $query),
      <br/>,
      (: for debugging :)
      comment { xdmp:quote($ex) }
    }</div>
  </body>
</html>
}

define function v:get-eval-label(
  $db as xs:unsignedLong, $modules as xs:unsignedLong?,
  $root as xs:string?, $name as xs:string?)
 as xs:string
{
  concat(
    xdmp:database-name($db),
    " (",
    if (exists($name)) then $name
    else if ($modules eq 0) then "file:"
    else concat(xdmp:database-name($modules), ":"),
    $root,
    ")"
  )
}

define function v:get-html-head()
 as element(xh:head)
{
  v:get-html-head("")
}

define function v:get-html-head($label as xs:string)
 as element(xh:head)
{
  v:get-html-head($label, false())
}

define function v:get-html-head($label as xs:string, $tablekit as xs:boolean)
 as element(xh:head)
{
  (: we do not always need the js and css here, but it makes reloads easier :)
  <head xmlns="http://www.w3.org/1999/xhtml">
    <title>{ $label, $c:TITLE-TEXT }</title>
    <link rel="stylesheet" type="text/css" href="cq.css">
    </link>
    {
      if (not($tablekit)) then () else
    <link rel="stylesheet" type="text/css" href="tablekit.css">
    </link>
    }
    <link rel="Shortcut Icon" href="favicon.ico" type="image/x-icon">
    </link>
    <script language="JavaScript" type="text/javascript" src="prototype.js">
    </script>
    {
      if (not($tablekit)) then () else
    <script language="JavaScript" type="text/javascript" src="tablekit.js">
    </script>
    }
    <script language="JavaScript" type="text/javascript" src="debug.js">
    </script>
    <script language="JavaScript" type="text/javascript" src="cookie.js">
    </script>
    <script language="JavaScript" type="text/javascript" src="session.js">
    </script>
    <script language="JavaScript" type="text/javascript" src="query.js">
    </script>
    {
      (: pass debug flag to JavaScript :)
      <script>debug.setEnabled(true);</script>[ d:get-debug() ]
    }
  </head>
}

define function v:get-eval-selector() as element(xh:select)
{
  (: first, list all the app-server labels
   : next, list all databases that aren't part of an app-server.
   : TODO provide a mechanism to update the list, to pull admin changes.
   :)

  (: html select-list for current database
   : NOTE: requires MarkLogic Server 3.1 or later.
   :)
  element xh:select {
    attribute name { "/cq:eval-in" },
    attribute id { "/cq:eval-in" },
    attribute title {
      "Select the database in which this query will evaluate." },
    for $s in $c:APP-SERVER-INFO
    let $label :=
      v:get-eval-label($s/c:database, (), (), $s/c:server-name)
    let $value := string-join(
      ('as', string($s/c:server-id), string($s/c:host-id)), ":")
    (: sort current app-server to the top, for bootstrap selection :)
    order by ($s/c:server-id eq $c:SERVER-ID) descending, $label
    return element xh:option {
      if ($s/c:server-id ne $c:SERVER-ID) then ()
      else attribute selected { 1 },
      attribute value { $value }, $label }
    ,
    for $db in c:get-orphan-database-ids()
    let $label :=
      v:get-eval-label($db, $c:SERVER-ROOT-DB, $c:SERVER-ROOT-PATH, ())
    let $value := string-join(
      (string($db), string($c:SERVER-ROOT-DB), $c:SERVER-ROOT-PATH), ":")
    order by ($db eq $c:DATABASE-ID) descending, $label
    return element xh:option { attribute value { $value }, $label }
  }
}

define function v:round-to-sigfig($i as xs:double)
 as xs:double {
  if ($i eq 0) then 0
  else round-half-to-even(
    $i, xs:integer(2 - ceiling(math:log10($i))))
}

define function v:format-profiler-report($report as element(prof:report))
  as element(xh:table)
{
  let $elapsed := data($report/prof:metadata/prof:overall-elapsed)
  return <table xmlns="http://www.w3.org/1999/xhtml">{
    attribute summary { "profiler report" },
    attribute class { "profiler-report sortable" },
    element caption {
      attribute class { "caption" },
      'Profiled',
      (sum($report/prof:histogram/prof:expression/prof:count), 0)[1],
      'expressions in', $elapsed },
    element tr {
      for $c in $v:PROFILER-COLUMNS/*
      return element th {
        attribute class {
          "profiler-report sortcol",
          if ($c eq "shallow-%") then "sortdesc" else ()
        },
        $c/@title, $c/text()
      }
    },
    let $size := 255
    let $max-line-length := string-length(string(max(
      $report/prof:histogram/prof:expression/prof:line)))
    (: NB - all elements should have line and expr-source,
     : but 3.2-1 sometimes produces output that we can't use.
     :)
    for $i in $report/prof:histogram/prof:expression
      [ prof:line ][ prof:expr-source ]
    order by $i/prof:shallow-time descending, $i/prof:deep-time descending
    return v:format-profiler-row($elapsed, $i, $size, $max-line-length)
  }</table>
}

define function v:format-profiler-row(
  $elapsed as prof:execution-time, $i as element(prof:expression),
  $size as xs:integer, $max-line-length as xs:integer)
 as element(xh:tr) {
  let $shallow := data($i/prof:shallow-time)
  let $deep := data($i/prof:deep-time)
  let $uri := text {
    if (not(string($i/prof:uri)))
    then '.main'
    else if (starts-with($i/prof:uri, '/'))
    then substring-after($i/prof:uri, '/')
    else $i/prof:uri
  }
  return <tr xmlns="http://www.w3.org/1999/xhtml">{
    attribute class { "profiler-report" },
    element td {
      attribute class { "profiler-report row-title" },
      attribute nowrap { 1 },
      element code {
        element span { $uri, ': ' },
        element span {
          attribute class { "numeric" },
          attribute xml:space { "preserve" },
          v:lead-space(string($i/prof:line), $max-line-length) } } },
    element td {
        attribute class { "profiler-report expression" },
        element code {
          let $expr := substring(string($i/prof:expr-source), 1, 1 + $size)
          return
            if (string-length($expr) gt $size)
            then concat($expr, $v:ELLIPSIS)
            else $expr
        }
    },
    element td {
      attribute class { "profiler-report numeric" }, $i/prof:count },
    element td {
      attribute class { "profiler-report numeric" },
      if ($elapsed ne prof:execution-time('PT0S'))
      then v:round-to-sigfig(100 * $shallow div $elapsed)
      else '-'
    },
    element td {
      attribute class { "profiler-report numeric" },
      v:duration-to-microseconds($shallow)
    },
    element td {
      attribute class { "profiler-report numeric" },
      if ($elapsed ne prof:execution-time('PT0S'))
      then v:round-to-sigfig(100 * $deep div $elapsed)
      else '-'
    },
    element td {
      attribute class { "profiler-report numeric" },
      v:duration-to-microseconds($deep)
    }
  }</tr>
}

define function v:lead-nbsp($v as xs:string, $len as xs:integer)
 as xs:string {
  v:lead-string($v, $v:NBSP, $len)
}

define function v:lead-space($v as xs:string, $len as xs:integer)
 as xs:string {
  v:lead-string($v, ' ', $len)
}

define function v:lead-zero($v as xs:string, $len as xs:integer)
 as xs:string {
  v:lead-string($v, '0', $len)
}

define function v:lead-string(
  $v as xs:string, $pad as xs:string, $len as xs:integer)
 as xs:string {
  concat(string-pad($pad, $len - string-length(string($v))), string($v))
}

define function v:duration-to-microseconds($d as xdt:dayTimeDuration)
 as xs:unsignedLong {
   1000 * 1000 * io:cumulative-seconds-from-duration($d)
}

(: lib-view.xqy :)
