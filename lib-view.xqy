xquery version "1.0-ml";
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

module namespace v = "com.marklogic.developer.cq.view";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare namespace xh = "http://www.w3.org/1999/xhtml";

import module namespace c = "com.marklogic.developer.cq.controller"
 at "lib-controller.xqy";

import module namespace d = "com.marklogic.developer.cq.debug"
 at "lib-debug.xqy";

import module namespace io = "com.marklogic.developer.cq.io"
  at "lib-io.xqy";

import module namespace x = "com.marklogic.developer.cq.xquery"
 at "lib-xquery.xqy";

declare variable $v:MICRO-SIGN as xs:string := codepoints-to-string(181);

declare variable $v:ELLIPSIS as xs:string := codepoints-to-string(8230);

declare variable $v:PROFILER-COLUMNS as element(columns) :=
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
;

declare function v:get-xml($x as item()+)
 as element()
{
  let $count := count($x)
  return
    if ($count eq 1 and $x instance of element()) then $x
    else if ($count eq 1 and $x instance of document-node() and $x/element())
    then v:get-xml($x/node())
    else element v:results {
      attribute v:warning {
        if ($count eq 1) then "non-element item"
        else "more than one node"
      },
      for $i in $x return typeswitch($i)
        (: handle corner-case where (1, $i/@id) throws XQTY0024 :)
        case attribute() return text { $i }
        case document-node() return $i/node()
        default return $i
    }
};

declare function v:get-html($x as item()*)
 as element(xh:html)
{
  let $is-profile as xs:boolean := $x[1] instance of element(prof:report)
  return
    if (count($x) eq 1 and $x instance of element(xh:html)) then $x
    else <html xmlns="http://www.w3.org/1999/xhtml">
    {
      if ($is-profile) then v:get-html-head('Profile for Query', true())
      else <head><title>Query Results</title></head>
    }
    <body bgcolor="white">{ v:get-html-body($x, $is-profile) }</body>
  </html>
};

declare function v:get-html-body($body as item()*, $is-profile as xs:boolean)
 as node()*
{
  if (empty($body)) then <i>your query returned an empty sequence</i>
  else
    for $i in $body
    return typeswitch($i)
      (: an attribute result throws XQTY0024 - show the text :)
      case attribute() return text { $i }
      (: unwrap document nodes :)
      case document-node() return v:get-html-body($i/node(), $is-profile)
      case element(prof:report) return v:format-profiler-report($i)
      (: wrap binaries when mixed with profiler results :)
      case binary() return
        if ($is-profile) then text { xdmp:describe($i) } else $i
      case xs:anyAtomicType return text { $i }
      default return
        if ($is-profile) then text { xdmp:quote($i) } else $i
};

declare function v:get-text($x as item()+)
 as item()+
{
  $x
};

declare function v:get-error-frame-html(
  $f as element(error:frame), $query as xs:string)
 as element()*
{
  d:debug(('v:get-error-frame-html:', $f)),
  element xh:div {
    if (exists($f/error:uri))
    then concat("in ", string($f/error:uri))
    else (),
    if (not($f/error:line)) then ()
    else
      let $line-no := xs:integer($f/error:line)
      return (
        concat("line ", string($line-no), ": "),
        (: display the error lines, if it is in a main module :)
        if ($f/error:uri) then ()
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
    ,
    text { $f/error:operation },
    <xh:br/>,
    text {
      if (exists($f/error:format-string/text()))
      then $f/error:format-string
      else $f/error:code
    },
    <xh:br/>,
    text { $f/error:data/error:datum },
    (: this may be empty :)
    for $v in $f/error:variables/error:variable
    return (
      element xh:code {
        concat("$", string($v/error:name)), ":=", data($v/error:value)
      },
      <xh:br/>
    ),
    <xh:br/>
  }
};

declare function v:get-error-html(
  $db as xs:unsignedLong, $modules as xs:unsignedLong,
  $root as xs:string, $ex as element(error:error),
  $query as xs:string)
 as element(xh:html)
{
  d:debug(('v:get-error-html:', $ex)),
<html xmlns="http://www.w3.org/1999/xhtml">
  { element head { v:get-html-head() } }
  <body bgcolor="white">{
    let $version as xs:string? := $ex/error:xquery-version
    return element div {
      (: display eval information :)
      element p {
        attribute class { 'instruction' },
        "query evaluated in",
        xdmp:database-name($db), "at",
        concat(
          if ($modules eq 0) then "file:"
          else xdmp:database-name($modules),
          ":", $root
        ),
        if ($ex/error:xquery-version) then (
          'as ', $ex/error:xquery-version
        ) else (),
        (: include cq version :)
        (: TODO add server version? :)
        concat(' (cq v', $c:VERSION, ')')
      },
      element p {
        attribute class { 'head1' },
        if ($version) then concat('[', $version, '] ') else (),
        (: NB - format-string is sometimes empty. if so, we omit the br :)
        text {
          if ($ex/error:format-string/text())
          then $ex/error:format-string
          else (
            concat(
              $ex/error:code,
              if ($ex/error:data/error:datum) then ':' else ''
            ),
            (: NB - error:name is sometimes empty, which causes an error :)
            if ($ex/error:name/text()) then concat('(', $ex/error:name, ')')
            else (),
            $ex/error:data/error:datum
          )
        }
      },
      element p {
        <b><i>Stack trace:</i></b>
      },
      element p {
        for $f in $ex/error:stack/error:frame
        return v:get-error-frame-html($f, $query)
      }
    }
  }</body>
</html>
};

declare function v:get-html-head()
 as element(xh:head)
{
  v:get-html-head("")
};

declare function v:get-html-head($label as xs:string)
 as element(xh:head)
{
  v:get-html-head($label, false())
};

declare function v:get-html-head($label as xs:string, $tablekit as xs:boolean)
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
    <script language="JavaScript" type="text/javascript" src="js/prototype.js">
    </script>
    <script language="JavaScript" type="text/javascript" src="js/resizable.js">
    </script>
    <script language="JavaScript" type="text/javascript" src="js/effects.js">
    </script>
    <script language="JavaScript" type="text/javascript" src="js/controls.js">
    </script>
    {
      if (not($tablekit)) then () else
    <script language="JavaScript" type="text/javascript" src="js/tablekit.js">
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
};

declare function v:get-eval-label(
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
};

declare function v:get-eval-selector() as element(xh:select)
{
  (: first, list all the app-server labels
   : next, list all databases that aren't part of an app-server.
   : TODO provide a mechanism to update the list, to pull admin changes.
   :)

  (: html select-list for current database
   : NOTE: requires MarkLogic Server 3.1 or later.
   :)
  element xh:select {
    attribute name { "eval" },
    attribute id { "eval" },
    attribute title {
      "Select the database in which this query will evaluate." },
    for $s in $c:APP-SERVER-INFO
    let $database-id as xs:unsignedLong := $s/c:database-id
    let $server-name as xs:string := $s/c:server-name
    let $label :=
      v:get-eval-label($database-id, (), (), $server-name)
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
};

declare function v:round-to-sigfig($i as xs:double)
 as xs:double
{
  if ($i eq 0) then 0
  else round-half-to-even(
    $i, xs:integer(2 - ceiling(math:log10(abs($i))))
  )
};

declare function v:format-profiler-report($report as element(prof:report))
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
     : but 3.2-1 sometimes produces different output.
     :)
    for $i in $report/prof:histogram/prof:expression
      [ prof:line ][ prof:expr-source ]
    order by $i/prof:shallow-time descending, $i/prof:deep-time descending
    return v:format-profiler-row($elapsed, $i, $size, $max-line-length)
  }</table>
};

declare function v:format-profiler-row(
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
          x:lead-space(string($i/prof:line), $max-line-length) } } },
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
      x:duration-to-microseconds($shallow)
    },
    element td {
      attribute class { "profiler-report numeric" },
      if ($elapsed ne prof:execution-time('PT0S'))
      then v:round-to-sigfig(100 * $deep div $elapsed)
      else '-'
    },
    element td {
      attribute class { "profiler-report numeric" },
      x:duration-to-microseconds($deep)
    }
  }</tr>
};

declare function v:display-results-pagination(
  $start as xs:integer, $current-page-items as xs:integer,
  $total-items as xs:integer, $page-size as xs:integer)
 as element(xh:div)?
 {
  if ($total-items lt $page-size)
  then ()
  else
    (: which page are we on?
     : if there are more than 20 pages, display a sliding window
     :)
    let $this-page := xs:integer(ceiling($start div $page-size))
    let $number-of-pages :=
      xs:integer(ceiling($total-items div $page-size))
    let $first-visible-page := max((1, $this-page - 10))
    let $last-visible-page :=  min(($this-page + 9, $number-of-pages))
    return <div xmlns="http://www.w3.org/1999/xhtml">{
      attribute id { "results-pagination" },
      attribute class { "pagination-area" },
      element span {
        attribute class { "pagination-label" },
        "Result Page:"
      },
      (: display the previous-results scroller? :)
      if ($this-page le 1) then ()
      else v:get-pagination-link(
        'pagination-scroller', "Previous", $start - $page-size
      ),
      (: display a link or label for each visible page :)
      for $p in ($first-visible-page to $last-visible-page)
      return
        if ($p eq $this-page)
        then element span {
          attribute class { "pagination-current-page-label" },
          $p
        }
        else v:get-pagination-link(
          'pagination-link', string($p), 1 + ($p - 1) * $page-size)
      ,
      (: display the next-results scroller? :)
      if ($this-page ge $number-of-pages) then ()
      else v:get-pagination-link(
        'pagination-scroller', "Next", $start + $page-size)
    }</div>
};

declare function v:get-pagination-link(
  $class as xs:string, $text as xs:string, $start as xs:integer)
 as element(xh:a)
{
  <a xmlns="http://www.w3.org/1999/xhtml">{
    attribute class { $class },
    attribute href { c:get-pagination-href($start) },
    $text
  }</a>
};

(: lib-view.xqy :)
