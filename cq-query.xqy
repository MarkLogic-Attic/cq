declare namespace db="http://marklogic.com/xdmp/database"
declare namespace html="http://www.w3.org/1999/xhtml"

define variable $g-worksheet-name {
  xdmp:get-session-field(
    "cq_worksheet_name",
    xdmp:get-request-field("cq_worksheet_name", "worksheet.xml")
  )
}

define function get-db-selector() as element() {
  (: html select-list for current database :)
  element html:select {
    attribute name { "/cq:databases" },
    for $d in xdmp:read-cluster-config-file("databases.xml")
      /db:databases/db:database
    return element html:option {
      attribute value { $d/db:database-id },
(:
      if ($d/db:database-id = xdmp:XXX())
      then attribute selected { "true" }
      else (),
:)
      $d/db:database-name
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
              value="{$g-worksheet-name}" onBlur="cqImportLink()"/>
            &nbsp;&nbsp;
            <input type="button" class="input1"
             onclick="cqExport(this.form);" value="Save [ctrl-shift-s]"/>
            &nbsp;&nbsp;
            <input type="button" class="input1"
             onclick="cqImport(this.form);" value="Open [ctrl-shift-o]"/>
            <!-- input type="checkbox" value="1" id="cq_autosave"/>autosave -->
            <br/>
          </td>
          <td >
            ALT-1 to ALT-9 =&gt; buffers 1-9; ALT-0 =&gt; 10
          </td>
       </tr>
{
 (:
  XXX make the rows and cols dynamic
  XXX add a database selector
  :)
}
       <tr>
         <td>
            <span id="cq_buffers">
              <textarea id="cq_buffer0" rows="16" cols="80"
               xml:space="preserve">
(: buffer 1 :)
default element namespace="http://www.w3.org/1999/xhtml"
&lt;p&gt;hello world&lt;/p&gt;
</textarea>
              <input id="queryInput" name="queryInput" type="hidden"/>
            </span>
            <span style="text-align: right">
              display results as&nbsp;
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