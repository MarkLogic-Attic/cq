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

import module namespace io="com.marklogic.developer.cq.io"
 at "lib-io.xqy"

import module namespace su="com.marklogic.developer.cq.security"
 at "lib-security-utils.xqy"

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

      <h1 class="head1 accent-color">Welcome to cq</h1>

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
            You are logged in as <code>{ $su:USER }</code>.
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
          or resume a saved session.
          Your sessions will be stored in the modules location
          on the current server:
          { xdmp:get-request-header("Host") }.
          Your sessions will be stored in the {
            if (xdmp:modules-database() eq 0) then "filesystem,"
            else ("database", xdmp:modules-database()),
            "under the path "
          }
          <code>{
            concat(
              xdmp:modules-root(),
              "/"[not(ends-with(xdmp:modules-root(), "/"))],
              "cq/sessions/"
            )
          }</code>.
          </p>
          <p>
          Note that if your modules location is a database,
          you must have write permission
          for the uri <code>/cq/sessions/</code> in order to create sessions.
          If you do not have read permission for a session,
          you will not be able to view it.
          If a session is locked by another user,
          you will not be able to resume it.
          </p>
          <p>Active sessions:
          </p>
          <br/>
{
  let $sessions := c:get-sessions()
  let $d := c:debug(("sessions:", count($sessions)))
  return
    if (exists($sessions))
    then element table {
      <script>
      var list = new SessionList();
      </script>,
      element tr {
        for $i in (
          "session name", "user", "created", "last modified",
          "")
        return element th { $i }
      },
      for $i in $sessions
      let $uri := $i/@uri
      (: we only care about the lock that expires last :)
      let $conflicting := c:get-conflicting-locks($uri, 1)
      return element tr {
        element td {
          element input {
            attribute type { "text" },
            attribute autocomplete { "off" },
            attribute value { ($i/sess:name, "(unnamed)")[1] },
            attribute onchange {
              concat("list.renameSession('", $uri, "', this.value)")
            }
          }
        },
        element td { string($i/sec:user) },
        element td { data($i/sess:created) },
        element td { data($i/sess:last-modified) },
        element td {
          if (empty($conflicting)) then () else
          text {
            "by", $conflicting/lock:owner,
            "until", adjust-dateTime-to-timezone(
              io:epoch-seconds-to-dateTime(
                $conflicting/lock:timestamp + $conflicting/lock:timeout
              )
            )
          },
          element input {
            attribute type { "button" },
            attribute title { data($i/sess:query-buffers/sess:query[1]) },
            attribute onclick { concat("list.resumeSession('", $uri, "')") },
            attribute value { "Resume" }
          }[ empty($conflicting) ],
          $v:NBSP,
          element input {
            attribute type { "button" },
            attribute title { "permanently delete this session" },
            attribute onclick {
              concat("list.deleteSession('", $uri, "', this)")
            },
            attribute value { "Delete" }
          }[ empty($conflicting) ]
        }
      }
    }
    else <div class="instruction">
    There are no resumable sessions
    in the contentbase "{$c:SESSION-DB}".
    Please try a different contentbase,
    or create a new session.
    </div>
}
          <input type="button" value="New Session"
          id="newSession2" name="newSession2" onclick="list.newSession()"/>
        </div>
      }
    </form>
  </body>
}
</html>

(: session.xqy :)