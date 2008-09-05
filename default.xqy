xquery version "1.0-ml";
(:
 : Client Query Application
 :
 : Copyright (c) 2002-2008 Mark Logic Corporation. All Rights Reserved.
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

import module namespace c = "com.marklogic.developer.cq.controller"
 at "lib-controller.xqy";

import module namespace d = "com.marklogic.developer.cq.debug"
 at "lib-debug.xqy";

import module namespace su = "com.marklogic.developer.cq.security"
 at "lib-security-utils.xqy";

import module namespace v = "com.marklogic.developer.cq.view"
 at "lib-view.xqy";

d:check-debug(),
c:set-content-type(),

(: before we go any further, make sure we have the right exec privs :)
let $priv-errors :=
  for $priv in (
    "http://marklogic.com/xdmp/privileges/admin-module-read",
    "http://marklogic.com/xdmp/privileges/xdmp-document-get",
    "http://marklogic.com/xdmp/privileges/xdmp-eval",
    "http://marklogic.com/xdmp/privileges/xdmp-eval-in",
    "http://marklogic.com/xdmp/privileges/xdmp-filesystem-directory",
    "http://marklogic.com/xdmp/privileges/xdmp-invoke",
    "http://marklogic.com/xdmp/privileges/xdmp-invoke-in",
    "http://marklogic.com/xdmp/privileges/xdmp-add-response-header",
    "http://marklogic.com/xdmp/privileges/xdmp-save"
  )
  return try {
    xdmp:security-assert($priv, "execute")
  } catch ($ex) { $priv }
return
  if ($priv-errors) then
<html xmlns="http://www.w3.org/1999/xhtml">
{
  v:get-html-head(),
  element body {
    <h1>Security Configuration Problem</h1>,
    <p>One or more security problems prevent this user ({$su:USER})
    from loading cq. Please use the
    <a href="http://{
      substring-before(xdmp:get-request-header('host'), ':')
    }:8001" target="_new">admin server</a>
    to resolve the problems listed below.
    </p>,
    if (empty($priv-errors)) then () else (
      <p>The current user is missing certain exec privileges required by cq.
      We recommend that you create a new <code>cq</code> role,
      grant these privileges to the <code>cq</code> role,
      and assign the <code>cq</code> role to the {$su:USER} user.
      </p>,
      element ul { for $e in $priv-errors return element li { $e } }
    )
  }
}
</html>
else xdmp:invoke("frameset.xqy")

(: default.xqy :)