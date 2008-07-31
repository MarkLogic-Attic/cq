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

import module namespace v = "com.marklogic.developer.cq.view"
 at "lib-view.xqy";

d:check-debug()
,
<html xmlns="http://www.w3.org/1999/xhtml">
{
  v:get-html-head(),
  <frameset id="frameset" rows="*,*" onresize="resizeFrameset()">
  {
    element frame {
      attribute src {
        concat("query.xqy?",
        (: pass the query string along, for worksheet and debug support :)
        string-join(
          for $f in xdmp:get-request-field-names()
          return string-join(($f, xdmp:get-request-field($f)), '=')
            , '&amp;') )
      },
      attribute id { "queryFrame" }
    }
  }
  <frame src="result.html" id="resultFrame" name="resultFrame"/>
  <noframes>
    <p>
    Your browser does not seem to support frames.
    We are sorry, but cq will not work without support for frames.
    </p>
  </noframes>
  </frameset>
}
</html>
