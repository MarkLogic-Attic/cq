xquery version "0.9-ml"
(:
 : cq: update-session.xqy
 :
 : Copyright (c)2002-2008 Mark Logic Corporation. All Rights Reserved.
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
 :
 :)

define variable $ID as xs:string {
  xdmp:get-request-field("ID") }

define variable $BUFFERS as xs:string {
  xdmp:get-request-field("BUFFERS") }

define variable $HISTORY as xs:string {
  xdmp:get-request-field("HISTORY") }

define variable $TABS as xs:string {
  xdmp:get-request-field("TABS") }

define variable $DEBUG as xs:boolean {
  let $v := xdmp:get-request-field("DEBUG", "0")
  return
    if ($v castable as xs:boolean)
    then xs:boolean($v)
    else boolean($v)
}

import module namespace c = "com.marklogic.developer.cq.controller"
 at "lib-controller.xqy"

import module namespace d = "com.marklogic.developer.cq.debug"
 at "lib-debug.xqy"

declare namespace sess = "com.marklogic.developer.cq.session"

define variable $UNQUOTE-OPTS as xs:string* {
    ('repair-none', 'format-xml') }

define variable $SESSION-NAMESPACE as xs:string {
  namespace-uri(<sess:x/>) }

define variable $new-buffers as element(sess:query-buffers) {
  d:debug(("update-session.xqy", $BUFFERS)),
  xdmp:unquote($BUFFERS, $SESSION-NAMESPACE, $UNQUOTE-OPTS)
  /sess:query-buffers
}

define variable $new-history as element(sess:query-history) {
  d:debug(("update-session.xqy", $HISTORY)),
  xdmp:unquote($HISTORY, $SESSION-NAMESPACE, $UNQUOTE-OPTS)
  /sess:query-history
}

define variable $new-tabs as element(sess:active-tab) {
  d:debug(("update-session.xqy", $TABS)),
  xdmp:unquote($TABS, $SESSION-NAMESPACE, $UNQUOTE-OPTS)
  /sess:active-tab
}

if ($DEBUG) then d:debug-on() else (),
c:update-session($ID, ($new-buffers, $new-history, $new-tabs)),
(: firefox 3 logs an error if the result is empty :)
<update-ok/>

(: update-session.xqy :)
