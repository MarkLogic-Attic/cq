xquery version "1.0-ml";
(:
 : Client Query Application
 :
 : Copyright (c) 2002-2010 Mark Logic Corporation. All Rights Reserved.
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

declare namespace html = "http://www.w3.org/1999/xhtml";

import module namespace c = "com.marklogic.developer.cq.controller"
 at "lib-controller.xqy";

import module namespace d = "com.marklogic.developer.cq.debug"
 at "lib-debug.xqy";

import module namespace v = "com.marklogic.developer.cq.view"
 at "lib-view.xqy";

declare option xdmp:mapping "false";

d:check-debug()
,
c:set-content-type(),
<html xmlns="http://www.w3.org/1999/xhtml">
  { v:get-html-head('Import Local Session') }
  <body>
    <h1>Import Local Session from File</h1>
    <form action="session-import-local-do.xqy"
          method="post" enctype="multipart/form-data">
      <input type="file" name="import" accept="text/xml"/>
      <input type="submit" value="import"/>
    </form>
  </body>
</html>

(: session-import-local.xqy :)
