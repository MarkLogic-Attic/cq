xquery version "1.0-ml";
(:
 : Client Query Application
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

import module namespace c = "com.marklogic.developer.cq.controller"
 at "lib-controller.xqy";

import module namespace d = "com.marklogic.developer.cq.debug"
 at "lib-debug.xqy";

import module namespace su = "com.marklogic.developer.cq.security"
 at "lib-security-utils.xqy";

import module namespace v = "com.marklogic.developer.cq.view"
 at "lib-view.xqy";

import module namespace x = "com.marklogic.developer.cq.xquery"
 at "lib-xquery.xqy";

declare namespace sess = "com.marklogic.developer.cq.session";

declare option xdmp:mapping "false";

declare variable $SESSIONS as element(sess:session)* := c:sessions();

d:check-debug(),
c:set-content-type(),

<html xmlns="http://www.w3.org/1999/xhtml">
{
  v:get-html-head('sessions', false(), true()),
  <body onload="sessionsOnLoad()">
    <form action="" method="post" id="session-form">
      <input type="hidden" name="{$d:DEBUG-FIELD}" value="{$d:DEBUG}"/>

      <h1 class="head1 accent-color">Welcome to cq</h1>

      <p class="instruction">This is MarkLogic cq,
      a web-based query tool for MarkLogic Server.
      You can find out more about MarkLogic Server and cq
      at <a href="http://developer.marklogic.com/" tabindex="-1"
      >developer.marklogic.com</a>.
      You may also find it helpful to read the cq
      <a href="README.txt" tabindex="-1">README</a> file.
      </p>
      <p>
  The admin user can install pre-defined roles for cq by clicking on this
  <a href="install-roles.xqy">install-roles.xqy</a> link.
      </p>
      <p><a href=".">return to cq</a></p>
      {
    (: placeholder for local sessions :)
    element div {
      attribute id { "sessions-local" },
      attribute class { "hidden" },
      element h1 { "Local Sessions" },
      element p {
        'These sessions use storage provided by your browser.',
        'You can also ',
        element a {
          attribute href { 'session-import-local.xqy' },
          'import' },
        ' sessions from local XML files.'
      }
    },
    element h1 { 'Server Sessions' },
        (: force session initialization :)
        let $s := $c:SESSION return (),
        if (exists($c:SESSION-EXCEPTION))
        then <div>
          <h2>WARNING: server session storage has been disabled,
              because of an error.</h2>
          <p>
          Perhaps you have disabled server storage of sessions
          for this instance of cq.
          If so, you can ignore this error and use local sessions,
          or <a href=".">return to cq</a>.
          </p>
          {
            if ($c:SESSION-DB eq 0)
            then
            <div>
            <p>
            You are running cq from the filesystem.
            Make sure that the directory <code>{$c:SESSION-DIRECTORY}</code>
            exists, and that MarkLogic Server can write to it.
            </p>
            <p>
              Make sure that the current user
              has the following exec privileges:
              <ul>
      <li><code>http://marklogic.com/xdmp/privileges/xdmp-document-get
      </code></li>
      <li><code>http://marklogic.com/xdmp/privileges/xdmp-filesystem-directory
      </code></li>
      <li><code>http://marklogic.com/xdmp/privileges/xdmp-save
      </code></li>
              </ul>
            </p>
            </div>
            else
            <p>
            You are running cq from a modules database,
            <code>{ xdmp:database-name($c:SESSION-DB) }</code>.
            You are logged in as <code>{ $su:USER }</code>.
            Make sure that the directory <code>{$c:SESSION-DIRECTORY}</code>
            exists, and that your login can write to it.
            </p>
          }
          <p>
    The admin user may be able to fix this problem by clicking on this
    <a href="install-roles.xqy">install-roles.xqy</a> link,
    then granting the <code>cq-sessions</code> roles to your user login.
    Please consult the
    <a href="README.txt" tabindex="-1">README</a>
    for more information about cq.
          </p>
          <p>The complete error message follows:</p>
          <hr/>
          <pre>{
            xdmp:quote($c:SESSION-EXCEPTION)
          }</pre>
          <hr/>
        </div>
        else
        <div>
          <p>These sessions are stored on the server.</p>
          <p>On this page you can start a new session,
          or resume a saved session.
          Your sessions will be stored in the modules location
          on the current server:
          { xdmp:get-request-header("Host") }.
          Your sessions will be stored in the {
            if (xdmp:modules-database() eq 0) then "filesystem,"
            else ("database", xdmp:database-name(xdmp:modules-database())),
            " "
          } under the path <code>{ $c:SESSION-DIRECTORY }</code>.
          </p>
          <p>
          Note that if your modules location is a database,
          you must have write permission
          for the uri <code>{ $c:SESSION-DIRECTORY }</code>
          in order to create sessions.
          If you do not have read permission for a session,
          you will not be able to view it.
          If a session is locked by another user,
          you will not be able to resume it.
          </p>
          <script>
          var list = new SessionList();
          </script>
{
  let $sessions := c:sessions()
  let $d := d:debug(("sessions:", count($sessions)))
  return
    if (exists($sessions))
    then element div {
          <br/>,
          element table {
            element tr {
              for $i in (
                "session name", "user", "created", "last modified",
                "")
              return element th { $i }
            },
            for $i in $sessions
            let $id := c:session-id($i)
            let $uri := c:session-uri($i)
            (: we only care about the lock that expires last :)
            let $conflicting := c:conflicting-locks($uri, 1)
            let $name as xs:string := ($i/sess:name, "(unnamed)")[1]
            return element tr {
              element td { $name },
              element td { string($i/sec:user) },
              element td { data($i/sess:created) },
              element td { data($i/sess:last-modified) },
              element td {
                if (empty($conflicting)) then () else
                text {
                  "by", $conflicting/lock:owner,
                  "until", adjust-dateTime-to-timezone(
                    x:epoch-seconds-to-dateTime(
                      $conflicting/lock:timestamp + $conflicting/lock:timeout
                    )
                  )
                },
                (: only show resume button if there are no conflicting locks :)
                element input {
                  attribute type { "button" },
                  attribute title {
                    data($i/sess:query-buffers/sess:query[1]) },
                  attribute onclick {
                    concat("list.resumeSession('", $id, "')") },
                  attribute value {
                    "Resume", (' ', $id)[ $d:DEBUG ] }
                }[ not($conflicting) ],
                $x:NBSP,
                (: clone button :)
                element input {
                  attribute type { "button" },
                  attribute title { "clone this session" },
                  attribute onclick {
                    concat("list.cloneSession('", $id, "', this)") },
                  attribute value { "Clone", (' ', $id)[ $d:DEBUG ] }
                },
                $x:NBSP,
                (: export button :)
                element input {
                  attribute type { "button" },
                  attribute title { "export this session" },
                  attribute onclick {
                    concat("list.exportServerSession('", $id, "', this)") },
                  attribute value { "Export", (' ', $id)[ $d:DEBUG ] }
                },
                $x:NBSP,
                (: only show delete button if there are no conflicting locks :)
                element input {
                  attribute type { "button" },
                  attribute title { "permanently delete this session" },
                  attribute onclick {
                    concat("list.deleteSession('", $id, "', this)") },
                  attribute value { "Delete", (' ', $id)[ $d:DEBUG ] }
                }[ not($conflicting) ]
              }
            }
          }
    }
    else <p class="instruction">
    There are no resumable sessions. Please create a new session.
    </p>
}
          <input type="button" value="New Server Session"
          id="newSession2" name="newSession2" onclick="list.newSession()"/>
        </div>
      }
    </form>
  </body>
}
</html>

(: session.xqy :)
