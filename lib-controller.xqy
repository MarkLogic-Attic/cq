(:
 : cq: lib-controller.xqy
 :
 : Copyright (c)2002-2006 Mark Logic Corporation. All Rights Reserved.
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
module "com.marklogic.developer.cq.controller"

declare namespace c = "com.marklogic.developer.cq.controller"

declare namespace sess="com.marklogic.developer.cq.session"

import module namespace v = "com.marklogic.developer.cq.view"
  at "lib-view.xqy"

default function namespace = "http://www.w3.org/2003/05/xpath-functions"

define variable $c:ACCEPT-XML as xs:boolean {
  contains(xdmp:get-request-header('accept'), 'application/xhtml+xml') }

define variable $c:COOKIES as element(c:cookie)* {
  for $c in tokenize(xdmp:get-request-header("cookie"), ";\s*")[. ne '']
  return element c:cookie {
    let $toks := tokenize($c, "=")
    return (
      attribute key { xdmp:url-decode($toks[1]) },
      attribute value { xdmp:url-decode($toks[2]) }
    )
  }
}

define variable $c:DEBUG as xs:boolean { false() }

define variable $c:USER as xs:string { xdmp:get-current-user() }

define variable $c:USER-ID as xs:unsignedLong {
  c:get-user-id($c:USER) }

define variable $c:SESSION-DIRECTORY as xs:string { "/cq/sessions/" }

(: we expect JavaScript to set two cookies for us: uri and database-id :)
define variable $c:SESSION-URI as xs:anyURI? {
  c:debug(("cookies:", $c:COOKIES)),
  let $v := (
    data($c:COOKIES[ @key eq "/cq:session-uri" ]/@value),
    $c:SESSION-DIRECTORY
  )[starts-with(., $SESSION-DIRECTORY)][1]
  where $v
  return xs:anyURI($v)
}

define variable $c:SESSION-COOKIE-DB as xs:unsignedLong? {
  data($c:COOKIES[@key eq "/cq:session-db"]/@value)
}

define variable $c:DEFAULT-DATABASE as xs:string { "Modules" }

define variable $c:SESSION-DB as xs:unsignedLong {
  (
    $c:SESSION-COOKIE-DB,
    (: the default-database might not exist :)
    try { xdmp:database($c:DEFAULT-DATABASE) } catch ($ex) {},
    xdmp:databases()
  )[1]
}

define variable $c:SESSION-DB-OPTIONS {
  <options xmlns="xdmp:eval">
    <database>{$c:SESSION-DB}</database>
  </options>
}

define variable $c:SESSION as element(sess:session)? {
  (: get the current session,
   : falling back to the last session or a new one.
   :)
  if (empty($c:SESSION-URI)) then ()
  else
    let $d := c:debug(("$c:SESSION: uri=", $c:SESSION-URI))
    let $session := c:get-session()
    let $session :=
      if (exists($session)) then $session
      (: We were explicitly asked for a new session,
       : so do not use the last session.
       :)
      else if ($c:SESSION-URI eq $c:SESSION-DIRECTORY) then ()
      else c:get-last-session()
    let $session :=
      if (exists($session)) then $session
      (: time for a new session :)
      else c:new-session()
    where $session
    return
      (: TODO set response headers to add cookie? :)
      let $set := xdmp:set($c:SESSION-URI, $session/@uri)
      return $session
}

define variable $c:SESSION-NAME as xs:string {
  ($c:SESSION/sess:name, "(unnamed session)")[1]
}

define variable $c:TITLE-TEXT as xs:string {
  (: show the user what platform and host we're querying :)
  text {
    "cq -",
    concat($c:USER, "@", xdmp:get-request-header("Host")),
    "-", xdmp:product-name(), xdmp:version(),
    "-", xdmp:platform()
  }
}

define function c:get-debug() as xs:boolean { $c:DEBUG }

define function c:debug-on()
 as empty()
{
  xdmp:set($c:DEBUG, true()),
  c:debug("debug is on")
}

define function c:debug-off() as empty() { xdmp:set($c:DEBUG, false()) }

define function c:debug($s as item()*)
 as empty()
{
  if (not($c:DEBUG)) then () else xdmp:log(
    string-join(("DEBUG:", translate(xdmp:quote($s), $v:NL, " ")), " ")
  )
}

define function c:check-debug()
 as empty()
{
  if (xs:boolean(xdmp:get-request-field("debug", string($c:DEBUG))))
  then c:debug-on()
  else ()
}

define function c:set-content-type()
 as empty()
{
  xdmp:set-response-content-type( concat(
    if ($c:ACCEPT-XML) then "application/xhtml+xml" else "text/html",
    "; charset=utf-8") )
}

define function c:get-available-sessions-node()
  as element(c:available-sessions)
{
  element c:available-sessions {
    let $query := 'declare namespace sess="com.marklogic.developer.cq.session"
      define variable $URI as xs:string external
      xdmp:estimate(xdmp:directory("/cq/sessions/")/sess:session)'
    let $vars := (xs:QName('URI'), $c:SESSION-DIRECTORY)
    for $id in xdmp:databases()
    return element c:database {
        attribute id { $id },
        attribute name { xdmp:database-name($id) },
        attribute estimate {
          xdmp:eval(
            $query, $vars,
            <options xmlns="xdmp:eval"><database>{$id}</database></options>
          )
        }
    }
  }
}

define function c:get-available-sessions()
  as element(sess:session)*
{
  (: TODO set limits :)
  c:get-available-sessions($c:SESSION-DB)
}

define function c:get-available-sessions($id as xs:unsignedLong)
  as element(sess:session)*
{
  (: TODO set limits :)
  xdmp:eval(
    'define variable $URI as xs:string external
     declare namespace sess="com.marklogic.developer.cq.session"
     xdmp:directory("/cq/sessions/")/sess:session',
    (xs:QName('URI'), $c:SESSION-DIRECTORY),
    <options xmlns="xdmp:eval"><database>{$id}</database></options>
  )
}

define function c:get-user-id($username as xs:string)
{
  xdmp:eval(
    'define variable $USER as xs:string external
     import module "http://marklogic.com/xdmp/security"
      at "/MarkLogic/security.xqy"
     sec:uid-for-name($USER)', (xs:QName('USER'), $username),
     <options xmlns="xdmp:eval">
       <database>{ xdmp:security-database() }</database>
     </options>
  )
}

define function c:get-session()
 as element(sess:session)?
{
  c:get-session($c:SESSION-URI)
}

define function c:get-session($uri as xs:anyURI)
 as element(sess:session)?
{
  c:get-session($uri, $c:SESSION-DB-OPTIONS)
}

define function c:get-session($uri as xs:anyURI, $options as element())
 as element(sess:session)?
{
  xdmp:eval(
    'define variable $URI as xs:string external
     declare namespace sess="com.marklogic.developer.cq.session"
     doc($URI)/sess:session',
    (xs:QName('URI'), $uri),
    $options
  )
}

define function c:get-last-session()
 as element(sess:session)?
{
  xdmp:eval(
    'define variable $URI as xs:string external
     declare namespace sess="com.marklogic.developer.cq.session"
     (
       for $sess in xdmp:directory($URI)/sess:session
       order by xs:dateTime($sess/sess:created)
       return $sess
     )[1]',
    (xs:QName('URI'), $c:SESSION-DIRECTORY),
    $c:SESSION-DB-OPTIONS
  )
}

define function c:generate-uri()
 as xs:anyURI
{
  let $uri := xs:anyURI(concat($c:SESSION-DIRECTORY, string(xdmp:random())))
  return if (xdmp:exists(doc($uri))) then c:generate-uri() else $uri
}

(:
 : Create a new session.
 :)
define function c:new-session()
 as element(sess:session)
{
  let $uri := c:generate-uri()
  let $d := c:debug(("new-session:", $uri))
  let $new :=
    <session xmlns="com.marklogic.developer.cq.session">
    {
      attribute uri { $uri },
      element sec:user { $c:USER },
      element sec:user-id { $c:USER-ID },
      element created { current-dateTime() },
      element query-buffers {
        (: TODO should this come from worksheet.xml, or what? :)
        for $i in (1 to 10) return element query {
          concat(
            '(: buffer ', string($i), ' :)', $v:NL,
            'declare namespace html = "http://www.w3.org/1999/xhtml"', $v:NL,
            '<p>hello world</p>'
          )
        }
      },
      <query-history/>
    }
    </session>
  return xdmp:eval(
    'define variable $URI as xs:anyURI external
    define variable $NEW as element() external
    xdmp:document-insert($URI, $NEW), $NEW',
    (xs:QName('URI'), $uri, xs:QName('NEW'), $new),
    $c:SESSION-DB-OPTIONS
  )
}

define function c:delete-session($uri as xs:anyURI)
 as empty()
{
  (: make sure it really is a session :)
  let $session := c:get-session($uri)
  where exists($session)
  return xdmp:eval(
    'define variable $URI as xs:anyURI external
    xdmp:document-delete($URI)',
    (xs:QName('URI'), $uri),
    $c:SESSION-DB-OPTIONS
  )
}

define function c:rename-session($db as xs:unsignedLong,
  $uri as xs:anyURI, $name as xs:string)
 as empty()
{
  if (xdmp:database() ne $db)
  then error("CQ-WRONGDB", text { xdmp:database(), "ne", $db })
  else (),

  let $session := doc($uri)/sess:session
  let $old := $session/sess:name
  let $new := element sess:name { $name }
  where $session
  return
    if (exists($old))
    then xdmp:node-replace($old, $new)
    else xdmp:node-insert-child($session, $new)
}

define function c:update-session($db as xs:unsignedLong,
  $buffers as element(sess:query-buffers),
  $history as element(sess:query-history))
 as empty()
{
  if (xdmp:database() ne $db)
  then error("CQ-WRONGDB", text { xdmp:database(), "ne", $db })
  else (),

  let $session := doc($c:SESSION-URI)/sess:session
  let $old-buffers := $session/sess:query-buffers
  let $old-history := $session/sess:query-history
  where $session
  return (
    if ($old-buffers)
    then xdmp:node-replace($old-buffers, $buffers)
    else xdmp:node-insert-child($session, $buffers)
    ,
    if ($old-history)
    then xdmp:node-replace($old-history, $history)
    else xdmp:node-insert-child($session, $history)
  )
}

(: lib-controller.xqy :)