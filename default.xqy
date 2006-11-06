(:
 : Client Query Application
 :
 : Copyright (c) 2002-2006 Mark Logic Corporation. All Rights Reserved.
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

import module namespace c="com.marklogic.developer.cq.controller"
 at "lib-controller.xqy"

import module namespace su="com.marklogic.developer.cq.security"
 at "lib-security-utils.xqy"

import module namespace v="com.marklogic.developer.cq.view"
 at "lib-view.xqy"

c:check-debug(),
c:set-content-type(),

(: before we go any further, make sure we have the right exec privs :)
let $errors :=
  for $priv in (
    "http://marklogic.com/xdmp/privileges/xdmp-document-get",
    "http://marklogic.com/xdmp/privileges/xdmp-eval",
    "http://marklogic.com/xdmp/privileges/xdmp-eval-in",
    "http://marklogic.com/xdmp/privileges/xdmp-filesystem-directory",
    "http://marklogic.com/xdmp/privileges/xdmp-invoke",
    "http://marklogic.com/xdmp/privileges/xdmp-read-cluster-config-file",
    "http://marklogic.com/xdmp/privileges/xdmp-save"
  )
  return
  try { xdmp:security-assert($priv, "execute") } catch ($ex) { $priv }
return
  if (exists($errors) or not($su:USER-HAS-SECURITY-ROLE)) then
<html xmlns="http://www.w3.org/1999/xhtml">
{
  v:get-html-head(),
  element body {
    <h1>Security Configuration Problem</h1>,
    if (empty($errors)) then () else (
      <p>cq cannot load until these privileges have been granted
      to the current user, {$su:USER}:</p>,
      element ul { for $e in $errors return element li { $e } }
    ),
    if ($su:USER-HAS-SECURITY-ROLE) then () else
    <p>cq cannot load until the current user, {$su:USER},
    has been granted the "security" role.
    </p>
  }
}
</html>
else xdmp:invoke("frameset.xqy")

(: cq.xqy :)
