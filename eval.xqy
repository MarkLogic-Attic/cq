xquery version "0.9-ml"
(:
 : eval.xqy
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
 : arguments:
 :   cq:query: the query to evaluate
 :   cq:mime-type: the mime type with which to return results
 :   cq:eval-in: the database under which to evaluate the query
 :)

declare namespace mlss = "http://marklogic.com/xdmp/status/server"

import module namespace c = "com.marklogic.developer.cq.controller"
 at "lib-controller.xqy"

import module namespace d = "com.marklogic.developer.cq.debug"
 at "lib-debug.xqy"

import module namespace v = "com.marklogic.developer.cq.view"
 at "lib-view.xqy"

define variable $QUERY as xs:string {
  xdmp:get-request-field("/cq:query", "") }

(: split into database, modules location, and root:
 : if the first tok is not "as", then it is a raw database, with all info.
 : otherwise it is an app server:
 : we need to look up the database, modules-database, and module-root.
 :)
(: Get appserver info in real-time, so we can support admin changes.
 : NOTE: Requires MarkLogic Server 3.1 or later.
 :)
define variable $EVAL-STRING as xs:string+ {
  (: colon-delimited value, dependent on the first field...
   :   if not "as", then database-id:modules-id:root-path,
   :   otherwise use the second token (app-server-id)
   :   to look up the database-id, modules-id, and root-path.
   :)
  let $toks := tokenize(xdmp:get-request-field(
    '/cq:eval-in', string(xdmp:database())), ':')
  return if ($toks[1] ne 'as') then $toks else (
    let $server :=
      xdmp:server-status(xs:unsignedLong($toks[3]), xs:unsignedLong($toks[2]))
    for $i in ($server/mlss:database, $server/mlss:modules, $server/mlss:root)
    return string($i)
  )
}

define variable $DATABASE-ID as xs:unsignedLong {
  xs:unsignedLong($EVAL-STRING[1]) }

(: default to current server module :)
define variable $MODULES-ID as xs:unsignedLong {
  xs:unsignedLong(($EVAL-STRING[2], xdmp:modules-database())[1]) }

(: default to root :)
define variable $MODULES-ROOT as xs:string {
  (: default to root="/", though that should never happen :)
  (: also fix win32 backslashes, and repeated slashes :)
  let $root := replace(($EVAL-STRING[3], "/")[1], "/+|\\+", "/")
  let $root :=
    if (matches($root, '([a-z]:)?/', "i")) then $root
    (: relative root, on a filesystem :)
    (: hack for bug 1894: eval-in doesn't support relative roots without "./" :)
    else if ($MODULES-ID eq 0) then concat("./", $root)
    (: relative root, in a database :)
    else concat($root, "/")
  return $root
}

define variable $MIMETYPE as xs:string {
  xdmp:get-request-field("/cq:mime-type", "text/plain")
}

define variable $PROFILING as xs:boolean {
  $MIMETYPE eq 'application/x-com.marklogic.developer.cq.profiling'
}

(: TODO add collation, when options supports it :)
define variable $OPTIONS as element() {
  <options xmlns="xdmp:eval">
  {
    element database { $DATABASE-ID },
    element modules { $MODULES-ID },
    element root { $MODULES-ROOT },
    element isolation { "different-transaction" },
    if (fn:starts-with (xdmp:version(), "4"))
      then element default-xquery-version { "app-server" }
      else ()
  }
  </options>
}

d:check-debug(),
d:debug(("eval:", $MIMETYPE)),
d:debug(("eval:", $DATABASE-ID, $MODULES-ID, $MODULES-ROOT, $QUERY)),
try {
  (: set the mime-type inside the try-catch block,
   : so errors can override it.
   :)
  let $x as item()* :=
    if (not($PROFILING)) then xdmp:eval($QUERY, (), $OPTIONS)
    else if ($c:PROFILING-ALLOWED) then prof:eval($QUERY, (), $OPTIONS)
    else <p class="head1 error">
      Profiling is disabled for the application server
      <b>{$c:SERVER-NAME}</b>.
      You may enable profiling in the admin server.
    </p>
  let $d := d:debug(("eval:", $x))
  (: Sometimes we override the user's request,
   : and display the results as text/plain instead
   :
   : Problem: sometimes IE6 insists on using a helper app for text/plain.
   : The 'Content-Disposition: inline' header trick does not fix this.
   : So can we use html and pre instead? Not for binary....
   : Note that there's a registry fix: isTextPlainHonored.
   : http://support.microsoft.com/default.aspx?scid=kb;EN-US;q239750
   :
   : It is dangerous to view a sequence of attributes as xml: XDMP-DUPATTR.
   : Binaries should not be viewed as html or text.
   :)
  let $mimetype :=
    if (empty($x)) then "text/html"
    (: try to autosense profiler output :)
    else if ($PROFILING) then "text/html"
    (: for binaries, let the browser autosense the mime-type :)
    else if ($x instance of node()+
      and exists((
        $x[ . instance of binary()+ or . instance of document-node()+ ]
        /(self::binary()|child::binary())
      )) ) then ()
    else if (($x instance of attribute()+ and count($x) gt 1)
      or (count($x) eq 1 and $x instance of document-node()+
        and empty($x/node()))
    )
    then "text/plain"
    else $MIMETYPE
  let $set :=
    if (exists($mimetype))
    then xdmp:set-response-content-type(
      string-join(($mimetype, 'charset=utf-8'), '; '))
    else ()
  let $set :=
    if (empty($mimetype) or $mimetype ne "text/plain") then () else
    (: does this fix the IE6 text/plain helper-app issue? cf Q239750 :)
    xdmp:add-response-header('Content-Disposition', 'inline; filename=cq.txt')
  return
    if ($mimetype eq "text/xml") then v:get-xml($x)
    else if ($mimetype eq "text/html") then v:get-html($x)
    else v:get-text($x)
} catch ($ex) {
  (: errors are always displayed as html :)
  xdmp:set-response-content-type("text/html; charset=utf-8"),
  v:get-error-html($DATABASE-ID, $MODULES-ID, $MODULES-ROOT, $ex, $QUERY)
}

(: eval.xqy :)
