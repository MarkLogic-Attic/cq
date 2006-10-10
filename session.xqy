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

import module namespace v="com.marklogic.developer.cq.view"
 at "lib-view.xqy"

declare namespace sess="com.marklogic.developer.cq.session"

c:check-debug(),
c:set-content-type(),

<html xmlns="http://www.w3.org/1999/xhtml">
{
  v:get-html-head(),
  <body>
    <form action="" method="post" id="/cq:session-form">
      <h1 class="head1">Welcome to cq.</h1>
      <p class="instruction">This is Mark Logic cq,
      a web-based query tool for MarkLogic Server 3.1 and later.
      You can find out more about MarkLogic Server and cq
      at <a href="http://developer.marklogic.com/" tabindex="-1"
      >developer.marklogic.com</a>.
      </p>
      {
        if (not($c:SESSION) or exists($c:SESSION-EXCEPTION))
        then <div>
          <h1>WARNING: sessions have been disabled, because of an error.</h1>
          <p>
          Perhaps you have disabled sessions for this instance of cq.
          If so, you can ignore this and <a href=".">return to cq</a>.
          </p>
          {
            if ($c:SESSION-DB eq 0)
            then
            <p>
            You are running cq from the filesystem.
            Make sure that the directory <code>{$c:SESSION-DIRECTORY}</code>
            exists, and that MarkLogic Server can write to it.
            </p>
            else
            <p>
            You are running cq from a modules database,
            <code>{ xdmp:database-name($c:SESSION-DB) }</code>.
            You are logged in as <code>{ $c:USER }</code>.
            Make sure that the directory <code>{$c:SESSION-DIRECTORY}</code>
            exists, and that your login can write to it.
            </p>
          }
          <p>The complete error message follows:</p>
          <hr/>
          <pre>{
            xdmp:quote($c:SESSION-EXCEPTION)
          }</pre>
          <hr/>
        </div> else <div>
          <p>On this page you can start a new session,
          or resume any saved session.
          Your sessions will be stored in a contentbase on this server,
          {xdmp:get-request-header("Host")}. By default, your sessions
          will be stored in the <code>Modules</code> contentbase.
          However, you can choose to store your sessions in any contentbase.
          Note that you must have write permission
          for the uri <code>/cq/sessions/</code> in order to create sessions.
          If you do not have read permission for a session,
          you will not be able to view it.
          </p>
          <p>Active sessions are listed from: {
            if ($c:SESSION-DB eq 0)
            then "server filesystem"
            else xdmp:database-name($c:SESSION-DB)
          }</p>
          <br/>
          <div id="sessions"/>
          <input type="button" class="input1" value="New Session"
          id="newSession2" name="newSession2" onclick="list.newSession()"/>
          <script>
          // pseudo-onload
          var list = new SessionList('session-db', 'sessions');
          list.updateSessions();
          </script>
        </div>
      }
    </form>
  </body>
}
</html>

(: session.xqy :)