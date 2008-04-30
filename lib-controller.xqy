xquery version "0.9-ml"
(:
 : cq: lib-controller.xqy
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
module "com.marklogic.developer.cq.controller"

default function namespace = "http://www.w3.org/2003/05/xpath-functions"

declare namespace c = "com.marklogic.developer.cq.controller"

declare namespace mlhs = "http://marklogic.com/xdmp/status/host"

declare namespace mlss = "http://marklogic.com/xdmp/status/server"

declare namespace mlgc = "http://marklogic.com/xdmp/group"

declare namespace mlhc = "http://marklogic.com/xdmp/hosts"

declare namespace sess = "com.marklogic.developer.cq.session"

declare namespace pol = "com.marklogic.developer.cq.policy"

import module namespace d = "com.marklogic.developer.cq.debug"
  at "lib-debug.xqy"

import module namespace io = "com.marklogic.developer.cq.io"
  at "lib-io.xqy"

import module namespace v = "com.marklogic.developer.cq.view"
  at "lib-view.xqy"

import module namespace su = "com.marklogic.developer.cq.security"
  at "lib-security-utils.xqy"

define variable $c:ACCEPT-XML as xs:boolean {
  (: per Mary Holstege: Opera says that it accepts xhtml+xml,
   : but fails to handle it correctly.
   :)
  contains(xdmp:get-request-header('accept'), 'application/xhtml+xml')
    and not(contains(xdmp:get-request-header('user-agent'), 'Opera'))
}

define variable $c:APP-SERVER-INFO as element()+ {
 c:get-app-server-info() }

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

define variable $c:DATABASE-ID as xs:unsignedLong {
 xdmp:database() }

define variable $c:HOST-ID as xs:unsignedLong {
 xdmp:host() }

define variable $c:POLICY as element(pol:policy)? {
  let $path := c:build-document-path("policy.xml")
  where io:exists($path)
  return io:read($path)/pol:policy
}

(: some deployments like to set their own default worksheet:
 : if it is available, use it.
 :)
define variable $c:DEFAULT-WORKSHEET as element(sess:session) {
  let $d := d:debug(('DEFAULT-WORKSHEET: init'))
  let $worksheet as element(sess:session)? :=
    let $path := c:build-document-path("worksheet.xml")
    let $d := d:debug(('DEFAULT-WORKSHEET: path =', $path))
    where io:exists($path)
    return io:read($path)/sess:session
  return
    (: did someone deletes the template document? be nice about it! :)
    if ($worksheet)
    then $worksheet
    else <session xmlns="com.marklogic.developer.cq.session">
    {
      element name { "New Session" },
      element query-buffers {
        for $i in (1 to 10) return element query {
          concat(
            '(: buffer ', string($i), ' :)', $v:NL,
            '<p>hello world</p>'
          )
        }
      },
      <query-history/>
    }
    </session>
}

define variable $c:POLICY-TITLE as xs:string? {
  d:debug(("policy:", $c:POLICY)),
  $c:POLICY/pol:title
}

define variable $c:POLICY-ACCENT-COLOR as xs:string? {
  $c:POLICY/pol:accent-color
}

define variable $c:PROFILING-ALLOWED as xs:boolean {
   prof:allowed(xdmp:request()) }

define variable $c:SERVER-ID as xs:unsignedLong {
  xdmp:server() }

define variable $c:SERVER-NAME as xs:string {
  xdmp:server-name($SERVER-ID) }

define variable $c:SERVER-ROOT-PATH as xs:string {
  $io:MODULES-ROOT }

define variable $c:SERVER-ROOT-DB as xs:unsignedLong {
  $io:MODULES-DB }

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
define variable $c:SESSION-ID as xs:string? {
  d:debug(('$c:SESSION-ID:', 'cookies =', $c:COOKIES)),
  d:debug(('$c:SESSION-ID:', 'session-dir =', $c:SESSION-RELPATH)),
  let $matches := $c:COOKIES[@key eq '/cq:session-id']
  let $d := d:debug(('$c:SESSION-ID:', 'matching =', $matches))
  let $id := ($matches/@value)[1]
  let $d := d:debug(('$c:SESSION-ID:', 'value =', $id))
  return $id
}

define variable $c:SESSION-OWNER as xs:string {
  concat($su:USER, "@", xdmp:get-request-client-address()) }

define variable $c:SESSION-TIMEOUT as xs:unsignedLong {
  xs:unsignedLong(300) }

define variable $c:SESSION as element(sess:session)? {
  (: get the current session,
   : falling back to the last session or a new one.
   :)
   let $d := d:debug(("$c:SESSION: id =", $c:SESSION-ID))
   (: get the last session, as long as it is not locked :)
   let $session :=
     if (exists($c:SESSION-ID))
     then c:get-session($c:SESSION-ID, true())
     else ()
   let $d := d:debug((
     "$c:SESSION: session =", $session, data($session/sess:last-modified)))
   let $session :=
     if (exists($session)) then $session
     (: We were explicitly asked for a new session,
      : so do not use the last session.
      :)
     else if ($c:SESSION-ID eq 'NEW') then ()
     else c:get-last-session()
   (: if none of the above worked, generate a new session :)
   let $session := if ($session) then $session else c:new-session()
   let $d := d:debug(("$c:SESSION: session =", $session/sess:created))
   where $session
   return
     let $id :=
       if ($c:SESSION-EXCEPTION) then () else c:get-session-id($session)
     let $set := xdmp:set($c:SESSION-ID, $id)
     let $lock :=
       if (empty($c:SESSION-ID) or $c:SESSION-ID eq '') then ()
       else c:lock-acquire($c:SESSION-ID)
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

define function c:lock-acquire($id as xs:string)
 as empty()
{
  io:lock-acquire(
    c:get-uri-from-id($id), "exclusive", "0",
    $c:SESSION-OWNER, $c:SESSION-TIMEOUT
  )
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
  d:debug(('c:get-conflicting-locks', $uri, $limit, $c:SESSION-OWNER)),
  let $locks := io:get-conflicting-locks($uri, $limit, $c:SESSION-OWNER)
  let $d := d:debug(('c:get-conflicting-locks',
    $uri, $limit, $c:SESSION-OWNER, $locks))
  return $locks
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
  d:debug(('c:get-sessions:', $c:SESSION-DIRECTORY, $check-conflicting)),
  try {
    for $i in io:list($c:SESSION-DIRECTORY)/sess:session
    where not($check-conflicting)
      or empty(c:get-conflicting-locks(c:get-session-uri($i)))
    order by
      if ($i/sess:last-modified castable as xs:dateTime)
      then xs:dateTime($i/sess:last-modified) else () descending,
      if ($i/sess:created castable as xs:dateTime)
      then xs:dateTime($i/sess:created) else () descending,
      $i/name
    return $i
  } catch ($ex) {
    (: looks like we have a problem - disable sessions :)
    d:debug(('c:get-sessions:', $ex)),
    xdmp:set($c:SESSION-EXCEPTION, $ex),
    xdmp:set($c:SESSION-ID, ())
  }
}

define function c:get-session(
  $id as xs:string, $check-conflicting as xs:boolean)
 as element(sess:session)?
{
  let $session :=
    let $path := c:get-uri-from-id($id)
    let $d := d:debug(('c:get-session:',
      'id =', $id, ', root =', $io:MODULES-ROOT, ', path =', $path))
    let $exists := io:exists($path)
    let $conflicts :=
      if (not($check-conflicting)) then ()
      else c:get-conflicting-locks($path)
    let $lock :=
      if (not($check-conflicting) or exists($conflicts)) then ()
      else c:lock-acquire($id)
    where $exists and empty($conflicts)
    return io:read($path)/sess:session
  let $d := d:debug(('c:get-session:', $session))
  return $session
}

define function c:get-last-session()
 as element(sess:session)?
{
  (c:get-available-sessions())[1]
}

define function c:get-id-from-uri($uri as xs:string)
 as xs:string
{
  substring-before(tokenize($uri, '/+')[last()], '.xml')
}

define function c:get-uri-from-id($id as xs:string)
 as xs:string
{
  concat($c:SESSION-DIRECTORY, $id, '.xml')
}

define function c:get-session-id($session as element(sess:session))
 as xs:string
{
  ($session/@id,
    let $uri := $session/@uri
    where $uri
    return c:get-id-from-uri($uri)
  )[1]
}

define function c:get-session-uri($session as element(sess:session))
 as xs:string?
{
  let $id := c:get-session-id($session)
  let $uri := c:get-uri-from-id($id)
  let $d := d:debug(('c:get-session-uri', $id, $uri))
  where $id
  return $uri
}

define function c:generate-id()
 as xs:string
{
  let $id := xdmp:integer-to-hex(xdmp:random())
  let $uri := c:get-uri-from-id($id)
  return if (io:exists($uri)) then c:generate-id() else $id
}

(:
 : Create a new session.
 :)
define function c:new-session()
 as element(sess:session)
{
  let $id :=
    if ($c:SESSION-EXCEPTION) then () else c:generate-id()
  let $d := d:debug((
    "new-session:", $id, string($c:SESSION-EXCEPTION/err:format-string) ))
  let $attributes := attribute id { $id }
  let $attribute-qnames := for $i in $attributes return node-name($i)
  let $elements := (
    element sec:user { $su:USER },
    element sec:user-id { $su:USER-ID },
    element sess:created { current-dateTime() },
    element sess:last-modified { current-dateTime() }
  )
  let $element-qnames := for $i in $elements return node-name($i)
  let $new :=
    <session xmlns="com.marklogic.developer.cq.session">
    {
      $attributes,
      $elements,
      (: default buffers and history, excluding any conflicts :)
      $c:DEFAULT-WORKSHEET/@*[ not(node-name(.) = $attribute-qnames) ],
      $c:DEFAULT-WORKSHEET/node()[ not(node-name(.) = $element-qnames) ]
    }
    </session>
  let $action :=
    if ($c:SESSION-EXCEPTION) then ()
    else try {
      c:save-session($new)
    } catch ($ex) {
      (: if something goes wrong, disable sessions :)
      xdmp:set($c:SESSION-EXCEPTION, $ex)
    }
  return $new
}

define function c:save-session($session as element(sess:session))
 as empty()
{
  io:write(c:get-uri-from-id($session/@id), document { $session })
}

define function c:delete-session($id as xs:string)
 as empty()
{
  (: make sure it really is a session :)
  let $uri := c:get-uri-from-id($id)
  let $session := io:read($uri)/sess:session
  where $session
  return (
    c:lock-acquire($id),
    io:delete($uri) (:, io:lock-release($uri) :)
  )
}

define function c:rename-session($uri as xs:string, $name as xs:string)
 as empty()
{
  d:debug(("c:rename-session:", $uri, "to", $name)),
  c:update-session($uri, element sess:name { $name })
}

define function c:update-session($id as xs:string, $nodes as element()*)
 as empty()
{
  d:debug(("c:update-session: id =", $id, $nodes)),
  let $session := c:get-session($id, true())
  let $d := d:debug(("c:update-session: session =", $session))
  let $assert :=
    if ($session) then ()
    else error('CTRL-SESSION', text { 'No session for', $id } )
  let $x-attrs := for $n in ('id', 'uri') return xs:QName($n)
  let $x-elems := (
    for $n in $nodes return node-name($n),
    node-name(<sec:user/>),
    node-name(<sess:last-modified/>)
  )
  let $session := element {node-name($session)} {
    $session/@*[ not(node-name(.) = $x-attrs) ],
    attribute id { $id },
    (: by default, take ownership :)
    if (exists($nodes/sec:user)) then ()
    else element sec:user { $su:USER },
    $session/node()[ not(node-name(.) = $x-elems) ],
    element sess:last-modified { current-dateTime() },
    $nodes
  }
  return c:save-session($session)
}

define function c:get-app-server-info()
 as element()+
{
  (: first, list all the app-servers (except webdav and task servers).
   : next, list all databases that aren't part of an app-server.
   : NOTE: requires MarkLogic Server 3.1-1 or later.
   : NOTE: this used to use a mix of xdmp:hosts(), xdmp:host-status(),
   :   and xdmp:server-status(), but it was too slow on large clusters.
   : TODO provide a mechanism to update the list, to pull admin changes.
   :)
   let $hosts as element(mlhc:host)+ :=
     xdmp:read-cluster-config-file('hosts.xml')/mlhc:hosts/mlhc:host
   for $g in xdmp:read-cluster-config-file('groups.xml')
     /mlgc:groups/mlgc:group
   let $group-id as xs:unsignedLong := $g/mlgc:group-id
   let $host-id as xs:unsignedLong :=
     $hosts[mlhc:group eq $group-id][1]/mlhc:host-id
   (: skip any webdav servers, since it makes little sense to query them :)
   for $i in $g/*/*[mlgc:http-server-id|mlgc:xdbc-server-id]
   let $server-id as xs:unsignedLong :=
     $i/(mlgc:http-server-id|mlgc:xdbc-server-id)
   let $server-name as xs:string :=
     $i/(mlgc:http-server-name|mlgc:xdbc-server-name)
   where $i instance of element(mlgc:xdbc-server) or not(data($i/mlgc:webDAV))
   return element c:app-server-info {
     element c:host-id { $host-id },
     element c:server-id { $server-id },
     element c:server-name { $server-name },
     element c:database { data($i/mlgc:database) },
     element c:modules { data($i/mlgc:modules) },
     element c:root { data($i/mlgc:root) }
   }
}

define function c:get-orphan-database-ids()
 as xs:unsignedLong*
{
  (: list the databases that aren't exposed via an app-server -
   : use reasonable defaults for modules, root values: current server.
   : note that we can default to one of these, too!
   :)
  let $exposed := data($c:APP-SERVER-INFO/c:database)
  return xdmp:databases()[not(. = $exposed)]
}

define function c:build-document-path($document-name as xs:string)
 as xs:string {
  let $path := xdmp:get-request-path()
  (: ensure that the path ends with "/" :)
  let $path :=
    if (ends-with($path, "/"))
    then $path
    else concat(string-join(tokenize(
      $path, "/")[ 1 to last() - 1], "/"), "/")
  (: canonicalize the document-name :)
  let $document-name :=
    if (not(starts-with($document-name, '/')))
    then $document-name
    else replace($document-name, '^(/+)(.+)', '$2')
  return concat($path, $document-name)
}

(: lib-controller.xqy :)
