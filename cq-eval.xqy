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
 :   cq:eval-in: the database under which to evaluate the query
 :)

declare namespace mlgr = "http://marklogic.com/xdmp/group"

import module namespace v = "com.marklogic.xqzone.cq.view"
 at "lib-view.xqy"
import module namespace c = "com.marklogic.xqzone.cq.controller"
 at "lib-controller.xqy"

define variable $g-query as xs:string {
  xdmp:get-request-field("/cq:query", "")
}

(: split into database, modules location, and root :)
define variable $g-eval-in as xs:string+ {
(: get appserver info in real-time, so we can support admin changes :)
  let $toks :=
    tokenize(xdmp:get-request-field("/cq:eval-in", string(xdmp:database())), ":")
  return
  if ($toks[1] eq "as")
  then (
    let $server := (
      xdmp:read-cluster-config-file("groups.xml")
        //(mlgr:http-server[mlgr:webDAV eq false()]|mlgr:xdbc-server)
        [ (string(mlgr:xdbc-server-id), string(mlgr:http-server-id)) = $toks[2]]
    )[1]
    return (
      string($server/mlgr:database),
      string($server/mlgr:modules),
      string(($server/(mlgr:root|mlgr:library))[1])
    )
  ) else $toks
}

define variable $g-db as xs:unsignedLong {
  xs:unsignedLong($g-eval-in[1])
}

(: default to current server module :)
define variable $g-modules as xs:unsignedLong {
  xs:unsignedLong(($g-eval-in[2], xdmp:modules-database())[1])
}

(: default to root :)
define variable $g-root as xs:string {
  (: default to root="/", though that should never happen :)
  (: also fix win32 backslashes, and repeated slashes :)
  let $root := replace(($g-eval-in[3], "/")[1], "/+|\\+", "/")
  let $root :=
    if (matches($root, '([a-z]:)?/', "i")) then $root
    (: relative root, on a filesystem :)
    (: hack for bug 1894: eval-in doesn't support relative roots without "./" :)
    else if ($g-modules eq 0) then concat("./", $root)
    (: relative root, in a database :)
    else concat($root, "/")
  return $root
}

define variable $g-mime-type as xs:string {
  xdmp:get-request-field("/cq:mime-type", "text/plain")
}

c:check-debug(),
c:debug(("cq-eval:", $g-mime-type)),
c:debug(("cq-eval:", $g-db, $g-modules, $g-root, $g-query)),
try {
  (: set the mime-type inside the try-catch block,
   : so errors can override it
   :)
  let $x := xdmp:eval-in($g-query, $g-db, (), $g-modules, $g-root)
  let $g-mime-type := if (empty($x)) then "text/html" else $g-mime-type
  let $set :=
    xdmp:set-response-content-type(concat($g-mime-type, "; charset=utf-8"))
  return
    if ($g-mime-type eq "text/xml") then v:get-xml($x)
    else if ($g-mime-type eq "text/html") then v:get-html($x)
    else v:get-text($x)
} catch ($ex) {
  (: errors are always displayed as html :)
  xdmp:set-response-content-type("text/html; charset=utf-8"),
  v:get-error-html($g-db, $g-modules, $g-root, $ex, $g-query)
}

(: cq-eval.xqy :)
