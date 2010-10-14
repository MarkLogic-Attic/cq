xquery version "1.0-ml";
(:
 : cq
 :
 : Copyright (c) 2002-2010 MarkLogic Corporation. All Rights Reserved.
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

declare namespace sess = "com.marklogic.developer.cq.session";

import module namespace c = "com.marklogic.developer.cq.controller"
 at "lib-controller.xqy";

import module namespace d = "com.marklogic.developer.cq.debug"
 at "lib-debug.xqy";

import module namespace v = "com.marklogic.developer.cq.view"
 at "lib-view.xqy";

declare option xdmp:mapping "false";

d:check-debug()
,
if ('POST' eq xdmp:get-request-method()) then ()
else c:error('CQ-UNEXPECTED')
,
c:set-content-type(),
<html xmlns="http://www.w3.org/1999/xhtml">
  { v:get-html-head('Import Local Session', false(), true()) }
  <body onload="sessionImportLocal()">
    <h1>Import Local Session from File</h1>
{
  try {
    (: stubs for a query page :)
    for $id in (
      "query", "eval", "buffer-list", "textarea-status",
      "history",
      "buffer-tabs", "buffer-tabs-0", "buffer-tabs-1",
      "buffer-accesskey-text")
    return element div {
      attribute id { $id }
    }
    ,
    v:session-restore(
      xdmp:unquote(
        xdmp:get-request-field("import") )/sess:session
      treat as element(sess:session) )
  } catch ($ex) {
    element div {
      element h2 {
        'Error: the import failed.' },
      <p>
      Perhaps the file you selected does not contain
      a valid cq session export?</p>,
      element p {
        element a {
          attribute href { 'session-import-local.xqy' },
          'Try again' } },
      element p {
        element a {
          attribute href { 'session.xqy' },
          'Return to the cq session manager' } },
      <p>
      The full error message follows.
      If you believe that your selected file does contain
      a valid cq session export, please visit
      the <a href="http://github.com/marklogic/cq/issues">issues</a>
      page for cq on github.
      There you can create a new issue for this problem.
      Be sure to attach a copy of this error message,
      and a copy of the session file that caused the error.
      </p>,
      element pre { xdmp:quote($ex) }
    }
  }
}
  </body>
</html>

(: session-import-local-do.xqy :)
