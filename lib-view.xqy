xquery version "1.0-ml";
(:
 : cq: lib-view.xqy
 :
 : Copyright (c) 2002-2010 Mark Logic Corporation. All Rights Reserved.
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

declare namespace sess = "com.marklogic.developer.cq.session";

import module namespace c = "com.marklogic.developer.cq.controller"
 at "lib-controller.xqy";

import module namespace d = "com.marklogic.developer.cq.debug"
 at "lib-debug.xqy";

import module namespace io = "com.marklogic.developer.cq.io"
  at "lib-io.xqy";

import module namespace x = "com.marklogic.developer.cq.xquery"
 at "lib-xquery.xqy";

declare option xdmp:mapping "false";

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

declare variable $v:XML-TREE-PI :=
<?xml-stylesheet type="text/xsl" href="xml-tree.xsl"?>
;

declare function v:get-xml(
  $x as item()+,
  $use-xsl as xs:boolean )
as node()*
{
  (: 4.2 will emit its own xml declaration for document nodes :)
  if ($x instance of document-node()) then v:get-xml($x/node(), $use-xsl)
  else (
    text {
      concat(
        '<?xml version="1.0" encoding="',
        xdmp:get-response-encoding(), '"?>' ) },
    (: conditionally include stylesheet, on browser request :)
    (: this must follow any xml decl, so rewrite documents where needed :)
    if (not($use-xsl)) then ()
    else $v:XML-TREE-PI
    ,
    let $is-unit := count($x) eq 1
    let $is-node := $is-unit and $x instance of node()
    let $is-root := $is-node and not($x instance of attribute())
    return (
      if ($is-root) then $x
      else element v:results {
        attribute v:warning {
          if ($is-node) then "attribute node"
          else if ($is-unit) then "atomic item"
          else "more than one root item"
        },
        (: handle corner-case where (1, $i/@id) throws XQTY0024 :)
        for $i in $x return typeswitch($i)
        case attribute() return element v:warning {
          attribute v:warning { 'attributes cannot be root nodes' },
          $i }
        case document-node() return $i/node()
        default return $i
      }
    )
  )
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
    else (
      let $line-no := xs:integer($f/error:line)
      let $column-no := $f/error:column/xs:integer(.)
      return (
        concat(
          "at ", string($line-no),
          if (empty($column-no)) then ''
          else concat(":", string($column-no), ": ") ),
        (: display the error lines, if it is in a main module :)
        if ($f/error:uri) then ()
        else <xh:div id="error-lines" class="code">
        {
          for $l at $x in tokenize($query, "\r\n|\r|\n", "m")
          where $x gt ($line-no - 3) and $x lt (3 + $line-no)
          return (
            concat(string($x), ": "),
            element xh:span {
              if ($x ne $line-no) then $l
              else (
                attribute class { "error" },
                if (empty($column-no)) then $l
                else (
                  (: Highlight the character at the error column :)
                  substring($l,1,$column-no),
                  element xh:span {
                    attribute class { "errorchar" },
                    substring($l, $column-no + 1, 1)
                  },
                  substring($l, $column-no + 2)
                )
              )
            },
            <xh:br/>
          )
        }
        </xh:div>,
        <xh:br/>
      )
    ),
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
    (: fn:string is robust in the face of empty or unknown lexical values :)
    let $version := string($ex/error:xquery-version)
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
        (: NB - version may be empty :)
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
      <p><b><i>Stack trace:</i></b></p>,
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

declare function v:get-html-head(
  $label as xs:string, $tablekit as xs:boolean)
 as element(xh:head)
{
  v:get-html-head($label, $tablekit, false())
};

declare function v:get-html-head(
  $label as xs:string, $tablekit as xs:boolean, $persist as xs:boolean)
 as element(xh:head)
{
  (: we do not always need the js and css here, but it makes reloads easier :)
  <head xmlns="http://www.w3.org/1999/xhtml">
    <title>{ $label, $c:TITLE-TEXT }</title>
    <link rel="stylesheet" type="text/css" href="cq.css" />
  {
    if (not($tablekit)) then () else
    <link rel="stylesheet" type="text/css" href="tablekit.css" />
  }
  <link rel="Shortcut Icon" href="favicon.ico" type="image/x-icon" />
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
    <script language="JavaScript" type="text/javascript"
     src="js/tablekit.js">
    </script>
    ,
    if (not($persist)) then () else
    <script language="JavaScript" type="text/javascript"
     src="js/persist-min.js">
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
  (: html select-list for current database
   :
   : first, list all the app-server labels
   : next, list all databases that aren't part of an app-server.
   : TODO provide a mechanism to update the list, to pull admin changes.
   :)

  element xh:select {
    attribute name { "eval" },
    attribute id { "eval" },
    attribute title {
      "Select the database in which this query will evaluate." },
    for $s in $c:APP-SERVER-INFO
    let $database-id as xs:unsignedLong := $s/c:database-id
    let $server-name as xs:string := $s/c:server-name
    (: if the database-id does not exist, ignore the entry :)
    let $label as xs:string? := try {
      v:get-eval-label($database-id, (), (), $server-name) } catch ($ex) {
      if ($ex/error:code eq 'XDMP-NOSUCHDB') then d:exception-log(
        $ex, ('v:get-eval-selector', $database-id) )
      else xdmp:rethrow()
    }
    let $value := string-join(
      ('as', string($s/c:server-id), string($s/c:host-id)), ":")
    where exists($label)
    (: sort current app-server to the top, for bootstrap selection :)
    order by ($s/c:server-id eq $c:SERVER-ID) descending, $label
    return element xh:option {
      if ($s/c:server-id ne $c:SERVER-ID) then ()
      else attribute selected { 1 },
      attribute value { $value }, $label }
    ,
    for $db in c:orphan-database-ids()
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
    (: NB - prof:value omits line and expr-source children :)
    let $max-line-length := string-length(string(max(
          (0, $report/prof:histogram/prof:expression/prof:line) )))
    (: NB - all elements should have line and expr-source,
     : but older versions sometime produce different output.
     :)
    for $i in $report/prof:histogram/prof:expression
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
  (: NB - line and expr-source are missing for prof:value
   : and for xdmp:apply when the xdmp:function constructor
   : specified a library module path.
   :)
  let $is-dynamic := empty($i/prof:line) or empty($i/prof:expr-source)
  let $uri := text {
    if ($is-dynamic) then '(n/a)'
    else if (not(string($i/prof:uri))) then '.main'
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
        element span { $uri, ':' },
        element span {
          attribute class { "numeric" },
          attribute xml:space { "preserve" },
          x:lead-space(string($i/prof:line), $max-line-length)
        },
        if(empty($i/prof:column)) then ()
        else (
          element span { ':' },
          element span {
            attribute class { "numeric" },
            attribute xml:space { "preserve" },
            x:lead-space(string($i/prof:column), $max-line-length)
          }
        )
      }
    },
    element td {
      attribute class { "profiler-report expression" },
      if ($is-dynamic) then element span {
        attribute class { "expression-dynamic" },
        '(expression source is not available when using prof:value,',
        'or xdmp:apply with parameterized module location)' }
      else element code {
        let $expr := substring(string($i/prof:expr-source), 1, 1 + $size)
        return concat(
          $expr,
          if (string-length($expr) gt $size) then $v:ELLIPSIS
          else '' )
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
  if ($total-items lt $page-size) then ()
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
    attribute href { c:pagination-href($start) },
    $text
  }</a>
};

declare function v:session-restore(
  $session as element(sess:session)?)
 as element(xh:div)
{
  v:session-restore($session, (), ())
};

declare function v:session-restore(
  $session as element(sess:session)?,
  $session-id as xs:string?,
  $session-etag as xs:string? )
 as element(xh:div)
{
  <div xmlns="http://www.w3.org/1999/xhtml"
   class="hidden" xml:space="preserve"
   id="session-restore" name="session-restore">
  {
    if (empty($session) or empty($session-id)) then ()
    else if (empty($session-etag)) then c:error('CQ-UNEXPECTED')
    else (
      attribute session-id { $session-id },
      attribute etag { $session-etag }
    ),

    let $active := data($session/sess:active-tab)
    where $active
    return attribute active-tab { $active },

    (: Initial session state as hidden divs.
     : Be careful to preserve all whitespace.
     : For IE6, this means we must use pre elements.
     :)
    element div {
      attribute id { "restore-session-buffers" },
      $session/sess:query-buffers/@*,
      for $i in $session/sess:query-buffers/sess:query
      return element pre { $i/@*, $i/node() }
    },
    element div {
      attribute id { "restore-session-history" },
      $session/sess:query-history/@*,
      for $i in $session/sess:query-history/sess:query
      return element pre { $i/@*, $i/node() }
    }
  }
  </div>
};

(: lib-view.xqy :)
