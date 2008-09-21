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

import module namespace su = "com.marklogic.developer.cq.security"
 at "lib-security-utils.xqy";

import module namespace v = "com.marklogic.developer.cq.view"
 at "lib-view.xqy";

import module namespace x = "com.marklogic.developer.cq.xquery"
 at "lib-xquery.xqy";

declare namespace sess = "com.marklogic.developer.cq.session";

declare variable $SESSIONS as element(sess:session)* := c:get-sessions();

d:check-debug(),
c:set-content-type(),

<html xmlns="http://www.w3.org/1999/xhtml">
{
  v:get-html-head(),
  <body>
    <form action="" method="post" id="session-form">
      <input type="hidden" name="{$d:DEBUG-FIELD}" value="{$d:DEBUG}"/>

      <h1 class="head1 accent-color">Welcome to cq</h1>

      <p class="instruction">This is Mark Logic cq,
      a web-based query tool for MarkLogic Server.
      You can find out more about MarkLogic Server and cq
      at <a href="http://developer.marklogic.com/" tabindex="-1"
      >developer.marklogic.com</a>.
      </p>
      {
        (: force session initialization :)
        let $s := $c:SESSION return (),
        if (exists($c:SESSION-EXCEPTION))
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
        </div>
        else
        <div>
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
  let $sessions := c:get-sessions()
  let $d := d:debug(("sessions:", count($sessions)))
  return
    if (exists($sessions))
    then element div {
          <p>Active sessions:</p>,
          <br/>,
          element table {
            element tr {
              for $i in (
                "session name", "user", "created", "last modified",
                "")
              return element th { $i }
            },
            for $i in $sessions
            let $id := c:get-session-id($i)
            let $uri := c:get-session-uri($i)
            (: we only care about the lock that expires last :)
            let $conflicting := c:get-conflicting-locks($uri, 1)
            let $name as xs:string := ($i/sess:name, "(unnamed)")[1]
            return element tr {
              element td {
                element input {
                  attribute type { "text" },
                  attribute autocomplete { "off" },
                  attribute value { $name },
                  attribute onchange {
                    concat("list.renameSession('", $id, "', this.value)")
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
                    concat("list.cloneSession('", $id, "', this)")
                  },
                  attribute value { "Clone", (' ', $id)[ $d:DEBUG ] }
                },
                $x:NBSP,
                (: only show delete button if there are no conflicting locks :)
                element input {
                  attribute type { "button" },
                  attribute title { "permanently delete this session" },
                  attribute onclick {
                    concat("list.deleteSession('", $id, "', this)")
                  },
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
          <input type="button" value="New Session"
          id="newSession2" name="newSession2" onclick="list.newSession()"/>
        </div>
      }
    </form>
  </body>
}
</html>

(: session.xqy :)
