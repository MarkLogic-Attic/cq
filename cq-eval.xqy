(:
 : cq-eval.xqy
 :
 : Copyright (c)2002-2005 Mark Logic Corporation. All Rights Reserved.
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
 : arguments:
 :   cq:query: the query to evaluate
 :   cq:mime-type: the mime type with which to return results
 :   cq:database: the database under which to evaluate the query
 :)

define variable $g-query as xs:string {
  xdmp:get-request-field("/cq:query", "")
}

define variable $g-db as xs:unsignedLong {
  xs:unsignedLong(xdmp:get-request-field(
    "/cq:database", string(xdmp:database())
  ))
}

define variable $g-mime-type as xs:string {
  xdmp:get-request-field("/cq:mime-type", "text/plain")
}

define variable $g-debug as xs:boolean { false() }

define variable $g-nbsp as xs:string { codepoints-to-string(160) }
define variable $g-nl { fn:codepoints-to-string((10)) }

define function debug($s as item()*) as empty() {
  if ($g-debug)
  then xdmp:log(
    string-join(("DEBUG:", translate(xdmp:quote($s), $g-nl, " ")), " ")
  )
  else ()
}

define function display-xml($x) {
  if (count($x) = 1
    and ($x instance of element() or $x instance of document-node())
  ) then $x
  else element results {
    attribute warning {
      if (empty($x)) then "empty list"
      else if (count($x) = 1) then "non-element node"
      else "more than one node"
    },
    for $i in $x
    return
      if ($i instance of document-node())
      then $i/*
      else $i
  }
}

define function display-html($x) as element() {
  (: TODO ditch the html document wrapper :)
<html xmlns="http://www.w3.org/1999/xhtml">
  <body bgcolor="white">
    <table>
      <tr valign="top"><td>
{
  for $i in $x
  return
    if ($i instance of document-node())
    then $i/*
    else $i
}
      </td></tr>
    </table>
  </body>
</html>
}

define function display-text($x) { $x }

define function error-html($ex as element()) as element() {
<html xmlns="http://www.w3.org/1999/xhtml">
  <body bgcolor="white">
    <table>
      <tr valign="top"><td>
  <b xmlns="http://www.w3.org/1999/xhtml"><code>ERROR:</code><br/>
  <code>{
    if (exists($ex/err:format-string/text()))
    then $ex/err:format-string/text()
    else $ex/err:code/text(), <br/>,
    $ex/err:data/err:datum/text(), <br/>,
    " at line ", ($ex/err:stack/err:frame/err:line)[1]/text(),
    <br/>,
    if (count($ex/err:stack/err:frame) gt 1)
    then (
      "Stack trace:", <br/>,
      for $f in $ex/err:stack/err:frame
      return (
        if (empty($f/err:operation))
        then "(entry-point or unknown function)"
        else $f/err:operation/text(), <br/>,
        $ex/err:data/err:datum/text(), <br/>,
        " at ", $f/err:uri/text(),
        " line ", $f/err:line/text(), <br/>
      )
    )
    else (),
    <br/>, comment { xdmp:quote($ex) }
  }</code></b>
      </td></tr>
    </table>
  </body>
</html>
}

try {
  xdmp:set-response-content-type(concat($g-mime-type, "; charset=utf-8")),
(:
  debug((xdmp:get-request-method())),
  debug((
    "NAMES:",
    for $n at $x in xdmp:get-request-field-names()
    return (string($x), $n, xdmp:get-request-field($n))
  )),
  debug(("BODY:", xdmp:get-request-body())),
  debug(("BEGIN:", $g-query, $g-db, $g-mime-type)),
:)
  (:let $s := xdmp:set-session-field("/cq:current-database", string($g-db)):)
  let $x := xdmp:eval-in($g-query, $g-db)
  return (
    if ($g-mime-type = "text/xml")
    then display-xml($x)
    else if ($g-mime-type = "text/html")
    then display-html($x)
    else display-text($x)
  )
} catch ($ex) {
  (: errors are always displayed as html :)
  xdmp:set-response-content-type("text/html; charset=utf-8"),
  error-html($ex)
}

(: cq-eval.xqy :)
