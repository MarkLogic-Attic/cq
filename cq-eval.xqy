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

import module namespace v="com.marklogic.xqzone.cq.view" at "lib-view.xqy"

define variable $g-query as xs:string {
  xdmp:get-request-field("/cq:query", "")
}

(: split into database, modules location, and root :)
define variable $g-eval-in as xs:string+ {
  tokenize(xdmp:get-request-field("/cq:eval-in", string(xdmp:database())), ":")
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
  ($g-eval-in[3], "/")[1]
}

define variable $g-mime-type as xs:string {
  xdmp:get-request-field("/cq:mime-type", "text/plain")
}

try {
  xdmp:set-response-content-type(concat($g-mime-type, "; charset=utf-8")),
  let $x := xdmp:eval-in($g-query, $g-db, (), $g-modules, $g-root)
  return (
    if ($g-mime-type = "text/xml")
    then v:get-xml($x)
    else if ($g-mime-type = "text/html")
    then v:get-html($x)
    else v:get-text($x)
  )
} catch ($ex) {
  (: errors are always displayed as html :)
  xdmp:set-response-content-type("text/html; charset=utf-8"),
  v:get-error-html($ex)
}

(: cq-eval.xqy :)
