(:
 : cq: lib-view.xqy
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
 :)

module "com.marklogic.xqzone.cq.view"

declare namespace v = "com.marklogic.xqzone.cq.view"

default function namespace = "http://www.w3.org/2003/05/xpath-functions"

(: TODO move to lib-controller? :)
define variable $g-debug as xs:boolean { false() }

define variable $g-nbsp as xs:string { codepoints-to-string(160) }
define variable $g-nl { fn:codepoints-to-string((10)) }

(: TODO move to lib-controller? :)
define function v:debug($s as item()*) as empty() {
  if ($g-debug)
  then xdmp:log(
    string-join(("DEBUG:", translate(xdmp:quote($s), $g-nl, " ")), " ")
  )
  else ()
}

define function v:get-xml($x) {
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
      then $i/node()
      else $i
  }
}

define function v:get-html($x) as element() {
  (: TODO ditch the html document wrapper :)
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
  <body bgcolor="white">{ $body }</body>
</html>
}

define function v:get-text($x) { $x }

define function v:get-error-frame-html
($f as element()) as node()* {
  if (exists($f/err:uri))
  then concat("in ", string($f/err:uri))
  else (),
  if (exists($f/err:line))
  then concat("line ", string($f/err:line), ": ")
  else (),

  if (empty($f/err:operation))
  then "(entry-point or unknown function)"
  else $f/err:operation/text(),
  <br/>,

  if (exists($f/err:format-string/text()))
  then $f/err:format-string/text()
  else $f/err:code/text(),
  <br/>,

  text { $f/err:data/err:datum },

  if (empty($f/err:variables)) then ()
  else (
    for $v in $f/err:variables/err:variable
    return (
      concat("$", string($v/err:name), " := ", string($v/err:value)),
      <br/>
    ),
    <br/>
  )
}

define function v:get-error-html($ex as element()) as element() {
<html xmlns="http://www.w3.org/1999/xhtml">
  <body bgcolor="white">
    <table>
      <tr valign="top"><td>
  <b xmlns="http://www.w3.org/1999/xhtml"><code>ERROR:</code><br/>
  <code>{
      <br/>,
      if (exists($ex/err:format-string/text()))
      then ($ex/err:format-string/text(), <br/>)
      else (),
      <br/>,
(:
      if (exists($ex/err:stack/err:frame/err:operation))
      then (
:)
        <i>Stack trace:</i>, <br/>, <br/>,
        for $f in $ex/err:stack/err:frame
        return v:get-error-frame-html($f)
(:
      ) else (),
:)
      ,<br/>, comment { xdmp:quote($ex) }
  }</code></b>
      </td></tr>
    </table>
  </body>
</html>
}

(: lib-view.xqy :)