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

<html xmlns="http://www.w3.org/1999/xhtml">
  <head>{
    (: this is the only reason to bother with an xqy:
     : to show the user what platform and host we're querying.
     :)
    element title {
      "cq -", xdmp:get-request-header("Host"),
      "- MarkLogic Server", xdmp:version(),
      "-", xdmp:platform()
    },
    (: we don't need the css here, but it makes reloads easier :)
    <script language="JavaScript" type="text/javascript" src="cq.js">
    </script>,
    <link rel="stylesheet" type="text/css" href="cq.css">
    </link>
  }</head>
  <frameset id="cq_frameset" rows="*,*" onresize="resizeFrameset()">
    <frame src="cq-query.xqy" name="cq_queryFrame" id="cq_queryFrame"/>
    <frame src="cq-result.html" name="cq_resultFrame" id="cq_resultFrame"/>
    <noframes>
      <p>Apparently your browser does not support frames.
      Try using this <a href="cq-query.html">link</a>.
      </p>
    </noframes>
  </frameset>
</html>

(: cq.xqy :)
