(:
 : Client Query Application
 :
 : Copyright (c) 2002-2005 Mark Logic Corporation. All Rights Reserved.
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
 :)

import module namespace c="com.marklogic.xqzone.cq.controller"
 at "lib-controller.xqy"

c:check-debug(),
xdmp:set-response-content-type("text/html; charset=utf-8"),
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>{
    (: this is the only reason to bother with an xqy:
     : to show the user what platform and host we're querying.
     :)
    element title {
      "cq -",
      concat(xdmp:get-current-user(), "@", xdmp:get-request-header("Host")),
      "-", xdmp:product-name(), xdmp:version(),
      "-", xdmp:platform()
    },
    (: we don't need the css here, but it makes reloads easier :)
    <script language="JavaScript" type="text/javascript" src="cq.js">
    </script>,
    <link rel="stylesheet" type="text/css" href="cq.css">
    </link>
  }</head>
{
  (: before we go any further, make sure we have the right exec privs :)
  let $errors :=
    for $priv in (
      "http://marklogic.com/xdmp/privileges/xdmp-read-cluster-config-file",
      "http://marklogic.com/xdmp/privileges/xdmp-eval-in"
    )
    return try {
      xdmp:security-assert($priv, "execute")
    } catch ($ex) {
      $priv
    }
  where exists($errors)
  return
  <body>
    <h1>Security Configuration Problem</h1>
    <p>cq will not load until these privileges have been granted
    to the current user, {xdmp:get-current-user()}:</p>
    <ul>{ for $e in $errors return element li { $e } }</ul>
  </body>
}
  <frameset id="cq_frameset" rows="*,*" onresize="resizeFrameset()">
{
  (: pass uri context to query frame :)
  let $query-string := string-join(
    for $f in xdmp:get-request-field-names()
    return string-join(($f, xdmp:get-request-field($f)), "=")
    , "&"
  )
  return
    <frame src="cq-query.xqy?{$query-string}"
     name="cq_queryFrame" id="cq_queryFrame"/>
}
    <frame src="cq-result.html" name="cq_resultFrame" id="cq_resultFrame"/>
    <noframes>
      <p>Apparently your browser does not support frames.
      Try using this <a href="cq-query.html">link</a>.
      </p>
    </noframes>
  </frameset>
</html>

(: cq.xqy :)
