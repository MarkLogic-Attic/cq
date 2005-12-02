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

declare namespace mlgr = "http://marklogic.com/xdmp/group"
declare namespace html = "http://www.w3.org/1999/xhtml"
declare namespace null = ""

import module namespace k = "com.marklogic.xqzone.cq.constants"
  at "lib-constants.xqy"
import module namespace v = "com.marklogic.xqzone.cq.view"
  at "lib-view.xqy"
import module namespace c = "com.marklogic.xqzone.cq.controller"
  at "lib-controller.xqy"

(: TODO store default db? problematic:
 : using xdmp:(get|set)-session-field breaks multiple cq windows|tabs,
 : because the user's session is locked while his query is running.
 : set with JavaScript instead? subrequest?
 : for now, we'll let the browser handle it.
 :)
(: TODO add "useful queries" popup :)

define variable $g-worksheet-uri {
  xdmp:get-request-field("worksheet-uri", "worksheet.xml")
}

(: some deployments like to set their own default worksheet:
 : if it's in APP-SERVER-ROOT/CQ-LOCATION/worksheet.xml,
 : this code will find it.
 :)
define variable $g-default-worksheet as element(cq_buffers)? {
  (: look for a default worksheet in the current server's
   : module-database (or filesystem)
   :)
  let $mdb := xdmp:modules-database()
  let $root := data(
    xdmp:read-cluster-config-file("groups.xml")
    /mlgr:groups/mlgr:group/mlgr:http-servers
    /mlgr:http-server[ mlgr:http-server-id = xdmp:server() ]
    /mlgr:root
  )
  let $rpath := string-join(
    tokenize(xdmp:get-request-path(), "[/]+")[1 to last() - 1],
    "/"
  )
  (: what about Windows and backslashes? don't talk to me about backslashes... :)
  let $path := replace(concat($root, $rpath, "/", $g-worksheet-uri), '//+', '/')
  let $path :=
    if (xdmp:platform() eq "winnt")
    then replace($path, '\\', '/')
    else $path
  let $worksheet :=
    if ($mdb ne 0)
    then
      (: fetch the worksheet from the modules database :)
      let $q  := 'define variable $path as xs:string external
        doc($path)/cq_buffers'
      return xdmp:eval-in($q, $mdb, (xs:QName("path"), $path))
    else
      (: fetch the worksheet from the filesystem :)
      let $uri := substring-after($path, $root)
      let $exists := xdmp:uri-is-file($uri)
      let $d := c:debug(("default-worksheet: ", $mdb, $root, $path, $uri, $exists))
      where $exists
      return xdmp:document-get($path)/cq_buffers
  let $d := c:debug(xdmp:describe($worksheet))
  let $assert :=
    if (exists($worksheet/cq_buffer/text())) then ()
    else error("CQ-DEFAULT-WORKSHEET: cannot find default worksheet")
  return $worksheet
}

define function get-eval-selector() as element(html:select)
{
  (: first, list all the app-server labels
   : next, list all databases that aren't part of an app-server
   :)

  (: html select-list for current database
   : NOTE: requires MarkLogic Server 2.2 or later
   :)
  element html:select {
    attribute name { "/cq:eval-in" },
    attribute id { "/cq:eval-in" },
    attribute title {
      "Select the database in which this query will evaluate."
    },
    let $current :=
      xs:unsignedLong(xdmp:get-request-field(
        "/cq:current-eval-in", string(xdmp:database())
      ))
    (: list the application servers, except webdav servers
     : NOTE: requires MarkLogic Server 3.0 or later
     : NOTE: uses undocumented APIs
     :)
    let $servers := xdmp:read-cluster-config-file("groups.xml")
      //(mlgr:http-server[mlgr:webDAV eq false()]|mlgr:xdbc-server)
    return (
      for $s in $servers
      let $id := data($s/(mlgr:http-server-id|mlgr:xdbc-server-id))[1]
      let $name := data($s/(mlgr:http-server-name|mlgr:xdbc-server-name))[1]
      let $db := data($s/mlgr:database)[1]
      let $dbname := xdmp:database-name($db)
      let $label := v:get-eval-label($db, (), (), $name)
      let $value := string-join(("as", string($id)), ":")
      (: sort current app-server to the top, for bootstrap selection :)
      order by $label
      return element html:option {
        attribute value { $value },
        if ($current eq $id) then attribute selected { true() } else (),
        $label
      },
      (: list the databases that aren't exposed via an app-server :)
      (: use reasonable defaults for modules, root values: current server :)
      let $server := $servers[ mlgr:http-server-id eq xdmp:server() ]
      let $modules := data($server/mlgr:modules)
      let $root := data($server/mlgr:root)
      let $exposed := data($servers/mlgr:database)
      for $db in xdmp:databases()[not(. = $exposed)]
      let $label := v:get-eval-label($db, $modules, $root, ())
      let $value := string-join((string($db), string($modules), $root), ":")
      order by $label
      return element html:option {
        attribute value { $value },
        $label
      }
    )

  }
}

c:check-debug(),
xdmp:set-response-content-type("text/html; charset=utf-8"),
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>Query Form</title>
    <script language="JavaScript" type="text/javascript" src="cq.js">
    </script>
    <link rel="stylesheet" type="text/css" href="cq.css">
    </link>
  </head>
  <body onload="cqOnLoad()">
    <form action="cq-eval.xqy" method="post"
      id="cq_form" name="cq_form" target="cq_resultFrame">
      <table summary="query form">
        <tr>
          <td nowrap="1">
            <table class="head1">
              <tr>
                <td nowrap="1">XQuery Source</td>
              </tr>
            </table>
            <div id="cq_import_export">
              <a href="javascript:cqListBuffers()">list all</a>
              | <span class="instruction">save buffers as:</span>
              <input type="text" id="cqUri" value="{$g-worksheet-uri}"/>
              <input type="button" class="input1"
              onclick="cqExport(this.form);" value="Save"
              title="Save buffers and queries to the current database. Shortcut: ctrl-shift-s"/>
              <input type="button" class="input1"
              onclick="cqImport(this.form);" value="Open"
              title="Retrieve buffers and queries from the current database. Shortcut: ctrl-shift-o"/>
              | <span class="instruction">resize text-area:</span>
              <img src="larr.gif" class="resizable-w" width="10" height="13"
              title="reduce the number of columns"
              onclick="resizeBuffers(-1, 0); return false;"/>
              <img src="darr.gif" class="resizable-s" width="13" height="10"
              title="reduce the number of rows"
              onclick="resizeBuffers(0, -1); return false;"/>
              <img src="rarr.gif" class="resizable-e" width="10" height="13"
              title="increase the number of columns"
              onclick="resizeBuffers(1, 0); return false;"/>
              <img src="uarr.gif" class="resizable-n" width="13" height="10"
              title="increase the number of rows"
              onclick="resizeBuffers(0, 1); return false;"/>
            </div>
            <div nowrap="1" id="cq_buffers">
{
 (:
  : initialize the buffers:
  : we're inside an html xmlns, so null is needed.
  :)
  for $b at $x in $g-default-worksheet/null:cq_buffer
  let $bufid := concat("cq_buffer", string($x - 1))
  return element textarea {
    attribute id { $bufid },
    attribute rows { ($g-default-worksheet/@rows, 16)[1] },
    attribute cols { ($g-default-worksheet/@cols, 80)[1] },
    attribute xml:space { "preserve" },
    xdmp:url-decode($b)
  }
}
              <input id="/cq:query" name="/cq:query" type="hidden"/>
              <input id="/cq:debug" name="/cq:debug" type="hidden"
               value="{c:get-debug()}"/>
            <table width="100%">
              <tr>
                <td width="100%" nowrap="1">
                <span class="instruction">eval in:</span>
                { get-eval-selector() }
                <span class="instruction">as</span>
                <input type="button" class="input1"
                onclick="submitXML(this.form);" value="XML"
                title="Submit query as text/xml. Shortcut: ctrl-enter"/>
                <input type="button" class="input1"
                onclick="submitHTML(this.form);" value="HTML"
                title="Submit query as text/html. Shortcut: alt-enter"/>
                <input type="button" class="input1"
                onclick="submitText(this.form);"
                value="TEXT"
                title="Submit query as text/plain. Shortcut: ctrl-shift-enter"/>
                <input type="hidden" name="/cq:mime-type" id="/cq:mime-type"
                value="text/xml"/>
                </td>
                <td id="cq_textarea_status" nowrap="1"
                title="Current position of the caret, as LINE,COLUMN."></td>
              </tr>
            </table>
            </div>
          </td>
          <td>
            <table>
            <tr id="cq-buffer-tabs">
              <td class="buffer-tab" id="cq-buffer-tabs-0"
              title="Select from one of 10 buffers. Shortcut: ctrl-0 to 9, or alt-0 to 9."
               onclick="refreshBufferTabs(0)">Buffers
                  <span class="instruction">
                  (use
                  <span id="cq_buffer_accesskey_text">alt</span>
                  to switch)
                  </span>
              </td>
              <td class="buffer-tab" id="cq-buffer-tabs-1"
              title="Query history, listing the 50 most recent queries."
               onclick="refreshBufferTabs(1)">History
              </td>
            </tr>
            </table>
            <table id="cq_bufferlist" border="1"/>
            <div id="/cq:history" name="/cq:history" class="query-history"/>
          </td>
        </tr>
        <tr>
          <td colspan="2" nowrap="1">
          </td>
        </tr>
      </table>
    </form>
  </body>
</html>
