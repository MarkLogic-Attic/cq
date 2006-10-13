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

default element namespace = "http://www.w3.org/1999/xhtml"

declare namespace sess="com.marklogic.developer.cq.session"

(: List the available sessions, with widgets for resume and delete.
 : Also provide widget to rename.
 : TODO Provide pagination.
 :)
c:check-debug(),
let $sessions := c:get-available-sessions()
let $d := c:debug(("sessions:", $sessions))
return
  if (exists($sessions))
  then element table {
    element tr {
      for $i in (
        "session name", "user", "created", "last modified",
        "actions")
      return element th { $i }
    },
    for $i in $sessions
    let $uri := $i/@uri
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
        element input {
          attribute type { "button" },
          attribute title { data($i/sess:query-buffers/sess:query[1]) },
          attribute onclick { concat("list.resumeSession('", $uri, "')") },
          attribute value { "Resume" }
        },
        if ($c:IS-SESSION-DELETE)
        then (
          $v:NBSP, "|", $v:NBSP,
          element span {
            attribute class { "bufferlabel query-delete" },
            attribute title { "permanently delete this session" },
            attribute onclick { concat("list.deleteSession('", $uri, "')") },
            "(delete)"
          }
        ) else ()
      }
      (:,element td { xdmp:describe($i), xdmp:quote($i) }:)
    }
  }
  else
    <div class="instruction">
    There are no resumable sessions
    in the contentbase "{$c:SESSION-DB}".
    Please try a different contentbase,
    or create a new session.
    </div>

(: get-sessions-view.xqy :)