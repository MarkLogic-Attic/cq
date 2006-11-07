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

default function namespace = "http://www.w3.org/2003/05/xpath-functions"

declare namespace c = "com.marklogic.developer.cq.controller"

declare namespace sess = "com.marklogic.developer.cq.session"

declare namespace pol = "com.marklogic.developer.cq.policy"

import module namespace v = "com.marklogic.developer.cq.view"
  at "lib-view.xqy"

import module namespace io = "com.marklogic.developer.cq.io"
  at "lib-io.xqy"

import module namespace su = "com.marklogic.developer.cq.security"
  at "lib-security-utils.xqy"

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

define variable $c:POLICY as element(pol:policy)? {
  let $path := xdmp:get-request-path()
  (: ensure that the path ends with "/" :)
  let $path :=
    if (ends-with($path, "/"))
    then $path
    else concat(
      string-join(tokenize($path, "/")[ 1 to last() - 1], "/"), "/"
    )
  let $path := concat($path, "policy.xml")
  where io:exists($path)
  return io:read($path)/pol:policy
}

define variable $c:POLICY-TITLE as xs:string? {
  c:debug(("policy:", $c:POLICY)),
  $c:POLICY/pol:title
}

define variable $c:POLICY-ACCENT-COLOR as xs:string? {
  $c:POLICY/pol:accent-color
}

define variable $c:SESSION-DB as xs:unsignedLong {
  $io:MODULES-DB }

define variable $c:SESSION-RELPATH as xs:string { "sessions/" }

define variable $c:SESSION-DIRECTORY as xs:string {
  let $path := xdmp:get-request-path()
  (: ensure that the path ends with "/" :)
  let $path :=
    if (ends-with($path, "/"))
    then $path
    else concat(
      string-join(tokenize($path, "/")[ 1 to last() - 1], "/"), "/"
    )
  return concat($path, $c:SESSION-RELPATH)
}

define variable $c:SESSION-EXCEPTION as element(err:error)? { () }

(: we expect JavaScript to set a cookie for the session uri :)
define variable $c:SESSION-URI as xs:anyURI? {
  c:debug(("cookies:", $c:COOKIES)),
  c:debug(("session-dir:", $c:SESSION-RELPATH)),
  let $v := data($c:COOKIES[ @key eq "/cq:session-uri" ]/@value)
  where $v and (ends-with($v, ".xml") or $v eq $c:SESSION-RELPATH)
  return xs:anyURI($v)
}

define variable $c:SESSION-OWNER as xs:string {
  concat($su:USER, "@", xdmp:get-request-client-address()) }

define variable $c:SESSION-TIMEOUT as xs:unsignedLong {
  xs:unsignedLong(300) }

define variable $c:SESSION as element(sess:session)? {
  (: get the current session,
   : falling back to the last session or a new one.
   :)
   let $d := c:debug(("$c:SESSION: uri =", $c:SESSION-URI))
   let $session :=
     if (exists($c:SESSION-URI))
     then io:read($c:SESSION-URI)/sess:session
     else ()
   let $d := c:debug((
     "$c:SESSION: session =", data($session/sess:last-modified)))
   let $session :=
     if (exists($session)) then $session
     (: We were explicitly asked for a new session,
      : so do not use the last session.
      :)
     else if (ends-with($c:SESSION-URI, "/")) then ()
     else c:get-last-session()
   let $session :=
     if (exists($session)) then $session
     (: time for a new session :)
     else c:new-session()
   let $d := c:debug(("$c:SESSION: session =", $session/sess:created))
   let $uri := data($session/@uri)
   where $session
   return
     let $set := xdmp:set($c:SESSION-URI, $session/@uri)
     let $lock := io:lock-acquire(
       $c:SESSION-URI, "exclusive", "0",
       $c:SESSION-OWNER, $c:SESSION-TIMEOUT
     )
     return $session
}

define variable $c:SESSION-NAME as xs:string? {
  $c:SESSION/sess:name }

define variable $c:TITLE-TEXT as xs:string {
  (: show the user what platform and host we're querying :)
  text {
    "cq -",
    concat($su:USER, "@", xdmp:get-request-header("Host")),
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

define function c:get-conflicting-locks($uri as xs:string)
 as element(lock:active-lock)*
{
  c:get-conflicting-locks($uri, ())
}

define function c:get-conflicting-locks(
  $uri as xs:string, $limit as xs:integer?)
 as element(lock:active-lock)*
{
  (: TODO check to make sure that the lock is still active :)
  let $locks := io:document-locks($uri)
    /lock:lock[lock:lock-type eq "write"]
    /lock:active-locks/lock:active-lock
    [ lock:owner ne $c:SESSION-OWNER ]
  return
    if (empty($limit)) then $locks else subsequence(
      (: we only care about the lock(s) that expires last :)
      for $c in $locks
      order by ($c/lock:timestamp + $c/lock:timeout) descending
      return $c, 1, $limit
    )
}

define function c:get-available-sessions()
 as element(sess:session)*
{
  c:get-sessions(true())
}

define function c:get-sessions()
 as element(sess:session)*
{
  c:get-sessions(false())
}

define function c:get-sessions($check-conflicting as xs:boolean)
 as element(sess:session)*
{
  try {
    for $i in io:list($c:SESSION-DIRECTORY)/sess:session
    where not($check-conflicting) or empty(c:get-conflicting-locks($i/@uri))
    order by xs:dateTime($i/sess:last-modified) descending,
      xs:dateTime($i/sess:created) descending,
      $i/name
    return $i
  } catch ($ex) {
    (: looks like we have a problem :)
    (: TODO can we find a cleaner way of doing this? :)
    xdmp:set($c:SESSION-EXCEPTION, $ex),
    xdmp:set($c:SESSION-URI, ())
  }
}

define function c:get-last-session()
 as element(sess:session)?
{
  (c:get-available-sessions())[1]
}

define function c:generate-uri()
 as xs:anyURI
{
  let $uri := xs:anyURI(concat(
      $c:SESSION-DIRECTORY, xdmp:integer-to-hex(xdmp:random()), ".xml"
  ))
  return
    if (io:exists($uri)) then c:generate-uri() else $uri
}

(:
 : Create a new session.
 :)
define function c:new-session()
 as element(sess:session)
{
  let $uri :=
    if ($c:SESSION-EXCEPTION) then () else c:generate-uri()
  let $d := c:debug((
    "new-session:", $uri, string($c:SESSION-EXCEPTION/err:format-string) ))
  let $new := document {
    <session xmlns="com.marklogic.developer.cq.session">
    {
      if ($uri) then attribute uri { $uri } else (),
      element name { "New Session" },
      element sec:user { $su:USER },
      element sec:user-id { $su:USER-ID },
      element created { current-dateTime() },
      element last-modified { current-dateTime() },
      element query-buffers {
        for $i in (1 to 10) return element query {
          concat(
            '(: buffer ', string($i), ' :)', $v:NL,
            'declare namespace html="http://www.w3.org/1999/xhtml"', $v:NL,
            '<p>hello world</p>'
          )
        }
      },
      <query-history/>
    }
    </session>
  }
  let $action :=
    if ($c:SESSION-EXCEPTION) then () else io:write($uri, $new)
  return $new/sess:session
}

define function c:delete-session($uri as xs:anyURI)
 as empty()
{
  (: make sure it really is a session :)
  let $session := io:read($uri)/sess:session
  where exists($session)
  return (
    io:delete($uri),
    io:lock-release($uri)
  )
}

define function c:rename-session($uri as xs:anyURI, $name as xs:string)
 as empty()
{
  c:debug(("c:rename-session:", $uri, "to", $name)),
  let $new := element sess:name { $name }
  let $names := node-name($new)
  where $uri
  return (
    io:write(
      $uri,
      document {
        element {node-name($c:SESSION)} {
          $c:SESSION/@*,
          $c:SESSION/node()[ not(node-name(.) = $names) ],
          $new
        }
      }
    ),
    io:lock-release($uri)
  )
}

define function c:update-session($nodes as element()*)
 as empty()
{
  let $names := (
    for $n in $nodes return node-name($n),
    node-name(<sess:last-modified/>)
  )
  where $c:SESSION
  return (
    io:write(
      $c:SESSION-URI,
      document {
        element {node-name($c:SESSION)} {
          $c:SESSION/@*,
          $c:SESSION/node()[ not(node-name(.) = $names) ],
          element sess:last-modified { current-dateTime() },
          $nodes
        }
      }
    )
  )
}

(: lib-controller.xqy :)