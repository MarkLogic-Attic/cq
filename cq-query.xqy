(:
 : Client Query Application
 :
 : Copyright (c)2002, 2003, 2004 Mark Logic Corporation
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

declare namespace db="http://marklogic.com/xdmp/database"
declare namespace html="http://www.w3.org/1999/xhtml"

(: TODO: worksheet save/load should always go to xdmp:database() :)
(: TODO store default db? problematic:
   using xdmp:(get|set)-session-field breaks multiple cq windows|tabs,
   because the user's session is locked while his query is running.
   set with JavaScript instead? subrequest?
 :)
(: TODO add "useful queries" popup :)
(: TODO add "query history" popup :)

define variable $g-nl { codepoints-to-string((10)) }

define variable $g-worksheet-name {
(:
  xdmp:get-session-field(
    "cq_worksheet_name",
:)
    xdmp:get-request-field("cq_worksheet_name", "worksheet.xml")
(:
  )
:)
}

define function get-db-selector() as element() {
  (: html select-list for current database
   : NOTE: requires CIS 2.2
   :)
  element html:select {
    attribute name { "/cq:database" },
    attribute id { "/cq:database" },
    let $current :=
      xs:unsignedLong(xdmp:get-request-field(
        "/cq:current-database", string(xdmp:database())
      ))
    for $db in xdmp:databases()
    let $label := xdmp:database-name($db)
    order by $label
    return element html:option {
      attribute value {$db},
      if ($db = $current) then attribute selected { true() } else (),
      $label
    }
  }
}

<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>Query Form</title>
    <link rel="stylesheet" type="text/css" href="cq.css">
    </link>
    <script language="JavaScript" type="text/javascript" src="cq.js">
    </script>
  </head>
  <body bgcolor="white" onload="cqOnLoad(this)">
    <form action="cq-eval.xqy" method="post"
      id="cq_form" name="cq_form" target="cq_resultFrame">
      <table width="100%" summary="" cellpadding="3" cellspacing="3">
        <tr width="100%">
          <td  class="head1">XQuery Source</td>
          <td  class="head1">Buffers</td>
        </tr>
        <tr>
          <td id="cq_import_export" nowrap="nowrap" >
            <a href="javascript:cqListBuffers()">list all</a>
            | save query buffers as
            <input type="text" id="cqUri"
              value="{$g-worksheet-name}"/>
            &nbsp;&nbsp;
            <input type="button" class="input1"
             onclick="cqExport(this.form);" value="Save [ctrl-shift-s]"/>
            &nbsp;&nbsp;
            <input type="button" class="input1"
             onclick="cqImport(this.form);" value="Open [ctrl-shift-o]"/>
            <br/>
          </td>
          <td >
            ALT-1 to ALT-9 =&gt; buffers 1-9; ALT-0 =&gt; 10
          </td>
       </tr>
{
 (:
  TODO make the rows and cols dynamic
  I'd rather not have every cq_buffer in here,
  but it helps to preserve the buffer contents on reload.
  :)
}
       <tr>
         <td>
            <span id="cq_buffers">
{
  let $default_buffer := string-join(
    ("(: buffer ID :)",
     'default element namespace="http://www.w3.org/1999/xhtml"',
     xdmp:quote(<p>hello world</p>)
    ), $g-nl
  )
  for $id in (0 to 9)
  let $bufid := concat("cq_buffer", string($id))
  return element html:textarea {
    attribute id { $bufid },
    attribute rows { 16 },
    attribute cols { 80 },
    attribute xml:space { "preserve" },
    (: session-field won't work for this,
       because it requires a db round-trip.
       use JS session instead?
    xdmp:get-session-field(
      $bufid,
      replace($default_buffer, "ID", string(1 + $id))
    )
     :)
    replace($default_buffer, "ID", string(1 + $id))
  }
}
              <input id="queryInput" name="queryInput" type="hidden"/>
            </span>
            <span style="text-align: right">
            eval in: { get-db-selector() }
            </span>
            <span style="text-align: right">
              as&nbsp;
              <input type="button" class="input1"
               onclick="submitXML(this.form);" value="XML [ctrl-enter]"/>
              &nbsp;&nbsp;
              <input type="button" class="input1"
               onclick="submitHTML(this.form);" value="HTML [alt-enter]"/>
              &nbsp;&nbsp;
              <input type="button" class="input1"
               onclick="submitText(this.form);"
               value="TEXT [ctrl-shift-enter]"/>
              <input type="hidden" name="cq_mimeType" id="cq_mimeType"
               value="text/xml"/>
            </span>
          </td>
          <td>
            <table summary="buffer list" id="cq_bufferlist" border="border"></table>
          </td>
        </tr>
      </table>
    </form>
  </body>
</html>