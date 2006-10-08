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

(: TODO don't save, and don't bug me again - site policy :)

import module namespace c="com.marklogic.developer.cq.controller"
 at "lib-controller.xqy"

import module namespace v="com.marklogic.developer.cq.view"
 at "lib-view.xqy"

declare namespace sess="com.marklogic.developer.cq.session"

define variable $DATABASES as element(c:database)+ {
  c:get-available-sessions-node()/c:database }

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
    at <a href="http://developer.marklogic.com/" tabindex="-2">developer.marklogic.com</a>.
    </p>
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
    <div>Active session contentbase:
    <select onchange="list.updateSessions()"
     id="session-db" name="session-db" tabindex="5">
    {
      (: TODO update counts when sessions are deleted :)
      for $db in $DATABASES
      return element option {
        attribute value { $db/@id },
        attribute selected { true() }[ $db/@id eq $c:SESSION-DB ],
        data($db/@name),
        concat(" (", data($db/@estimate), " resumable sessions)")
      }
    }
    </select>
    <br/>
    <input type="button" class="input1" value="New Session" tabindex="3"
     id="newSession1" name="newSession1" onclick="list.newSession()"/>
    </div>
    <br/>
    <div id="sessions"/>
    <input type="button" class="input1" value="New Session" tabindex="7"
     id="newSession2" name="newSession2" onclick="list.newSession()"/>
    </form>
    <script>
      // pseudo-onload
      var list = new SessionList('session-db', 'sessions');
      list.updateSessions();
    </script>
  </body>
}
</html>

(: session.xqy :)