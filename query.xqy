xquery version "1.0-ml";
(:
 : cq
 :
 : Copyright (c) 2002-2011 MarkLogic Corporation. All Rights Reserved.
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

declare namespace sess = "com.marklogic.developer.cq.session";

import module namespace v = "com.marklogic.developer.cq.view"
  at "lib-view.xqy";

import module namespace c = "com.marklogic.developer.cq.controller"
  at "lib-controller.xqy";

import module namespace d = "com.marklogic.developer.cq.debug"
 at "lib-debug.xqy";

declare option xdmp:mapping "false";

d:check-debug(),
c:set-content-type(),
<html xmlns="http://www.w3.org/1999/xhtml">
  { v:get-html-head('cq - query pane', false(), true()) }
  <body onload="cqOnLoad()">
    <!-- query path on our form may keep IE6 from launching a helper -->
    <form action="eval.xqy?iefix.txt" method="post" id="form"
     target="resultFrame">
      <table summary="query form">
        <tr>
          <td nowrap="1">
            <table class="head1 accent-color">
              <tr>
                <td nowrap="1" id="title">Current XQuery</td>
                <td nowrap="1" id="version" class="version">
                cq v{ $c:VERSION }</td>
              </tr>
            </table>

            <div>
              <a href="javascript:cqListDocuments()"
               >explore</a>&#160;|&#160;<span
               class="instruction"><a
               href="javascript:prettyPrint()"
               title="format the current selection (removes any comments)"
              >pretty-print</a></span>|&#160;<span
               class="instruction">{
  element a {
    attribute id { "sessions-link" },
    attribute href {
      string-join((
          'session.xqy', "?debug=1"[ $d:DEBUG ]), '') },
    attribute target { "_parent" },
    (: make sure lazy module variable is initialized :)
    let $lazy := $c:SESSION
    return (
      if ($c:SESSION-EXCEPTION) then "sessions disabled"
      else "session:"
    )
  }
  }&#160;{
  element span {
    attribute id { "session-rename" },
    attribute class {
      if ($c:SESSION-EXCEPTION) then 'hidden' else '' },
    $c:SESSION-NAME
  }
  }</span>
            </div>

            <div nowrap="1" id="queryBuffers">
            <textarea id="query" name="query"
             itsalltext-extension=".xqy"
             xml:space="preserve" spellcheck="false">{
              (: NB @spellcheck above turns off gecko inline spellcheck.
               : NB @itsalltext-extension for the eponymous firefox extension.
               : Dynamic buffer size, restored from session state.
               :)
              attribute rows { (data($c:SESSION/@rows), 16)[1] },
              attribute cols { (data($c:SESSION/@cols), 80)[1] }
            }</textarea>
            <table width="100%">
              <tr>
                <td width="100%" nowrap="1">
                <span class="instruction">content-source:</span>
                { v:get-eval-selector() }
                <span class="instruction">as</span>
                <input type="button" onclick="submitText(this.form);"
                value="TEXT"
                title="Submit query as text/plain. Shortcut: ctrl-shift-enter"/>
                <input type="button" onclick="submitXML(this.form);"
                value="XML"
                title="Submit query as text/xml. Shortcut: ctrl-enter"/>
                <input type="button" onclick="submitHTML(this.form);"
                value="HTML"
                title="Submit query as text/html. Shortcut: alt-enter"/>
                <input type="button" value="Profile"
                onclick="submitProfile(this.form);">{
                  if ($c:PROFILING-ALLOWED)
                  then ()
                  else attribute class { "disabled" },
                  attribute title {
                    if ($c:PROFILING-ALLOWED) then text {
                      "Submit query for profiling.",
                      "Shortcut: ctrl-alt-shift-enter" }
                    else text {
                      "Profiling is disabled for the application server",
                      $c:SERVER-NAME }
                  }
                }</input>
            <input type="hidden" class="hidden" value="text/xml"
             id="mime-type" name="mime-type"/>
            <input type="hidden" class="hidden" value="false"
             id="xsl" name="xsl"/>
            <input type="hidden" class="hidden"  value="{$c:POLICY-TITLE}"
             id="policy-title"/>
            <input type="hidden" class="hidden" value="{$c:POLICY-ACCENT-COLOR}"
             id="policy-accent-color"/>
            <input type="hidden" class="hidden" value="{$d:DEBUG}"
             id="{$d:DEBUG-FIELD}"  name="{$d:DEBUG-FIELD}"/>
{
  v:session-restore(
    if ($c:SESSION-EXCEPTION) then () else $c:SESSION,
    if ('LOCAL' eq $c:SESSION-ID) then () else $c:SESSION-ID,
    if ('LOCAL' eq $c:SESSION-ID) then () else $c:SESSION-ETAG
  )
}
                </td>
                <td id="textarea-status" nowrap="1" class="status"
                title="Current position of the caret, as LINE,COLUMN."></td>
              </tr>
            </table>
            </div>
          </td>
          <td>
            <table>
            <tr id="buffer-tabs">
              <td class="buffer-tab" id="buffer-tabs-0"
              title="Select any query buffer. Shortcut: ctrl-0 to 9, or alt-0 to 9."
               onclick="gBufferTabs.refresh(0)">Queries&#160;<span
               class="instruction" nowrap="1">(<span
               id="buffer-accesskey-text">alt</span>)</span>
              <span id="buffers-add"
               title="Add another buffer to the list."
               onclick="gBuffers.add('(: new query :)\n1')"> + </span>
              </td>
              <td class="buffer-tab" id="buffer-tabs-1"
              title="Query history, listing the most recent queries."
               onclick="gBufferTabs.refresh(1)">History
              </td>
            </tr>
            </table>
            <div id="buffer-history-wrapper" class="buffer-history-wrapper">
              <table id="buffer-list" border="1"/>
              <div id="history">
            <span><i>
            This is an empty query history list:
            populate it by submitting queries.</i></span>
            </div>
            </div>
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
