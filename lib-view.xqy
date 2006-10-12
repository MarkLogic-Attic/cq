(:
 : cq: lib-view.xqy
 :
 : Copyright (c)2002-2006 Mark Logic Corporation. All Rights Reserved.
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

declare namespace xh="http://www.w3.org/1999/xhtml"

import module namespace c = "com.marklogic.developer.cq.controller"
  at "lib-controller.xqy"

define variable $v:NBSP as xs:string { codepoints-to-string(160) }
define variable $v:NL { fn:codepoints-to-string((10)) }

define function v:get-xml($x)
 as element()
{
  if (count($x) = 1
    and ($x instance of element() or $x instance of document-node())
  ) then ($x/descendant-or-self::*)[1]
  else element results {
    attribute warning {
      if (empty($x)) then "empty list"
      else if (count($x) = 1) then "non-element node"
      else "more than one node"
    },
    for $i in $x
    return
      if ($i instance of document-node())
      then $i/node()
      else $i
  }
}

define function v:get-html($x)
 as element(xh:html)
{
  let $body :=
    for $i in $x
    return if ($i instance of document-node()) then $i/node() else $i
  return
    if (count($body) eq 1
      and ($body instance of element())
      and local-name($body) eq 'html')
    then $body
    else
<html xmlns="http://www.w3.org/1999/xhtml">
  <head><title/></head>
  <body bgcolor="white">
{
  if (exists($body)) then $body
  else <i>your query returned an empty sequence</i>
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
  if (exists($f/err:uri))
  then concat("in ", string($f/err:uri))
  else (),
  if (exists($f/err:line))
  then (
    concat("line ", string($f/err:line), ": "),
    (: display the error lines, if it's in a main module :)
    if (exists($f/err:uri)) then ()
    else <div id="error-lines"><code>
    {
      let $line-no := xs:integer($f/err:line)
      for $l at $x in tokenize($query, "\r\n|\r|\n", "m")
      where $x gt ($line-no - 3) and $x lt (3 + $line-no)
      return (
        concat(string($x), ": "),
        element span {
          if ($x eq $line-no) then attribute style { "color: red" } else (),
          $l
        },
        <br/>
      )
    }
    </code></div>,
    <br/>
  )
  else (),

  $f/err:operation/text(),
  <br/>,

  if (exists($f/err:format-string/text()))
  then $f/err:format-string/text()
  else $f/err:code/text(),
  <br/>,

  text { $f/err:data/err:datum },

  (: this may be empty :)
  for $v in $f/err:variables/err:variable
  return (
    element code { concat("$", string($v/err:name)), ":=", data($v/err:value) },
    <br/>
  ),
  <br/>
}

define function v:get-error-html(
  $db as xs:unsignedLong, $modules as xs:unsignedLong,
  $root as xs:string, $ex as element(err:error),
  $query as xs:string)
 as element(xh:html)
{
<html xmlns="http://www.w3.org/1999/xhtml">
  <body bgcolor="white">
    <div>
  <b>
  <code>{
    (: display eval-in information :)
    "ERROR: eval-in",
    xdmp:database-name($db), "at",
    concat(
      if ($modules eq 0) then "file" else xdmp:database-name($modules),
      ":", $root
    ),
    <br/>,
    <br/>,
    (: NOTE: format-string is sometimes empty. if so, we omit the br :)
    if (exists($ex/err:format-string/text()))
    then ($ex/err:format-string/text(), <br/>)
    else if (exists($ex/err:code/text()))
    then (text { $ex/err:code, $ex/err:data/err:datum }, <br/>)
    else (),
    <br/>,
    <i>Stack trace:</i>, <br/>, <br/>,
    for $f in $ex/err:stack/err:frame
    return v:get-error-frame-html($f, $query),
    <br/>,
    (: for debugging :)
    comment { xdmp:quote($ex) }
  }</code>
  </b>
    </div>
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
  (: we do not need the js and css here, but it makes reloads easier :)
  <head xmlns="http://www.w3.org/1999/xhtml">
    <title>{ $label, $c:TITLE-TEXT }</title>
    <link rel="stylesheet" type="text/css" href="cq.css">
    </link>
    <link rel="Shortcut Icon" href="favicon.ico" type="image/x-icon">
    </link>
    <script language="JavaScript" type="text/javascript" src="prototype.js">
    </script>
    <script language="JavaScript" type="text/javascript" src="debug.js">
    </script>
    <script language="JavaScript" type="text/javascript" src="cookie.js">
    </script>
    <script language="JavaScript" type="text/javascript" src="session.js">
    </script>
    <script language="JavaScript" type="text/javascript" src="query.js">
    </script>
    {
      if (c:get-debug())
      then <script>debug.setEnabled(true);</script>
      else ()
    }
  </head>
}

(: lib-view.xqy :)