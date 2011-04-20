xquery version "1.0-ml";
(:
 : cq/lib-controller.xqy
 :
 : Copyright (c) 2002-2011 MarkLogic Corporation. All Rights Reserved.
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
module namespace c = "com.marklogic.developer.cq.controller";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare namespace sess = "com.marklogic.developer.cq.session";

declare namespace pol = "com.marklogic.developer.cq.policy";

import module namespace admin = "http://marklogic.com/xdmp/admin"
  at "/MarkLogic/admin.xqy";

import module namespace d = "com.marklogic.developer.cq.debug"
  at "lib-debug.xqy";

import module namespace io = "com.marklogic.developer.cq.io"
  at "lib-io.xqy";

import module namespace su = "com.marklogic.developer.cq.security"
  at "lib-security-utils.xqy";

import module namespace v = "com.marklogic.developer.cq.view"
  at "lib-view.xqy";

import module namespace x = "com.marklogic.developer.cq.xquery"
  at "lib-xquery.xqy";

declare option xdmp:mapping "false";

declare variable $c:ACCEPT-XML as xs:boolean := (
  (: per Mary Holstege: Opera says that it accepts xhtml+xml,
   : but fails to handle it correctly.
  :)
  contains(xdmp:get-request-header('accept'), 'application/xhtml+xml')
  and not(contains(xdmp:get-request-header('user-agent'), 'Opera'))
);

declare variable $c:ADMIN-CONFIG as element(configuration) :=
  admin:get-configuration()
;

declare variable $c:APP-SERVER-INFO as element()+ :=
  c:app-server-info()
;

declare variable $c:COOKIES as element(c:cookie)* :=
  for $c in tokenize(xdmp:get-request-header("cookie"), ";\s*")[. ne '']
  return element c:cookie {
    let $toks := tokenize($c, "=")
    return (
      attribute key { xdmp:url-decode($toks[1]) },
      attribute value { xdmp:url-decode($toks[2]) }
    )
  }
;

declare variable $c:DATABASE-ID as xs:unsignedLong := xdmp:database();

(: some deployments like to set their own default worksheet:
 : if it is available, use it.
 :)
declare variable $c:DEFAULT-WORKSHEET as element(sess:session) :=
  let $d := d:debug(('DEFAULT-WORKSHEET: init'))
  let $worksheet as element(sess:session)? :=
    let $path := c:build-document-path("worksheet.xml")
    let $d := d:debug(('DEFAULT-WORKSHEET: path =', $path))
    where io:exists($path)
    return io:read($path)/sess:session
  return
    (: usually the query will come from the worksheet.xml template :)
    if ($worksheet) then $worksheet
    (: no worksheet template? try to be nice anyway :)
    else <session xmlns="com.marklogic.developer.cq.session">
    {
      element name { "New Session" },
      element query-buffers {
        for $i in 1 to 10
        return element query {
          concat(
            'xquery version "1.0-ml";', $x:NL,
            '(: buffer ', string($i), ' :)', $x:NL,
            '<p>hello world</p>'
          )
        }
      },
      <query-history/>
    }
    </session>
;

declare variable $c:FORM-EVAL as xs:string :=
  xdmp:get-request-field(
    'eval',
    string-join(
      (string($c:DATABASE-ID), string($c:SERVER-ROOT-DB), $c:SERVER-ROOT-PATH),
      ':'
    )
  )
;

declare variable $c:FORM-EVAL-VALUES as xs:anyAtomicType+ := (
  (: colon-delimited value, dependent on the first field...
   : if not "as", then database-id:modules-id:root-path,
   : otherwise use tokens 2 (group-id) and 3 (server-id)
   : to look up the database-id, modules-id, and root-path.
   : NB - possible errors if a server changes groups.
   :)
  let $form := $c:FORM-EVAL
  let $is-appserver := starts-with($c:FORM-EVAL, 'as:')
  let $server-id as xs:unsignedLong :=
    if ($is-appserver)
    then xs:unsignedLong(
      substring-before(substring-after($form, 'as:'), ':'))
    else xdmp:server()
  let $database-id as xs:unsignedLong := (
    if (not($is-appserver)) then xs:unsignedLong(
      substring-before($c:FORM-EVAL, ':') )
    else try {
      admin:appserver-get-database($c:ADMIN-CONFIG, $server-id) }
    catch ($ex) {
      if ($ex/error:code eq 'SEC-PRIV')
      then xdmp:database()
      else xdmp:rethrow()
    }
  )
  return ($database-id, $server-id)
)
;

declare variable $c:FORM-EVAL-DATABASE-ID as xs:unsignedLong :=
  $c:FORM-EVAL-VALUES[1]
;

declare variable $c:FORM-EVAL-SERVER-ID as xs:unsignedLong :=
  $c:FORM-EVAL-VALUES[2]
;

declare variable $c:HOST-ID as xs:unsignedLong :=
 xdmp:host()
;

declare variable $c:POLICY as element(pol:policy)? :=
  let $path := c:build-document-path("policy.xml")
  where io:exists($path)
  return io:read($path)/pol:policy
;

declare variable $c:POLICY-TITLE as xs:string? :=
  d:debug(("policy:", $c:POLICY)),
  $c:POLICY/pol:title
;

declare variable $c:POLICY-ACCENT-COLOR as xs:string? :=
  $c:POLICY/pol:accent-color
;

declare variable $c:PROFILING-ALLOWED as xs:boolean :=
  prof:allowed(xdmp:request());

declare variable $c:REQUEST-PATH as xs:string :=
  let $path := xdmp:get-request-path()
  (: ensure that the path ends with "/" :)
  return
    if (ends-with($path, "/"))
    then $path
    else concat(
      string-join(tokenize($path, "/")[ 1 to last() - 1], "/"), "/"
    )
;

declare variable $c:SERVER-ID as xs:unsignedLong :=
  xdmp:server() ;

declare variable $c:SERVER-NAME as xs:string :=
  xdmp:server-name($SERVER-ID) ;

declare variable $c:SERVER-APPLICATION-PATH as xs:string :=
  concat($c:SERVER-ROOT-PATH, $c:REQUEST-PATH) ;

declare variable $c:SERVER-ROOT-PATH as xs:string :=
  $io:MODULES-ROOT ;

declare variable $c:SERVER-ROOT-DB as xs:unsignedLong :=
  $io:MODULES-DB ;

(: Get the current session.
 : If the current session is not set or is not available,
 : supply a new session with no session-id.
 : The browser will use local storage.
 :)
declare variable $c:SESSION as element(sess:session) := (
  let $d := d:debug(("$c:SESSION: id =", $c:SESSION-ID))
  (: Get the last session, as long as it is not locked.
   : If we were explicitly asked for a new session, honor that.
   :)
  let $session := (
    if (empty($c:SESSION-ID) or $c:SESSION-ID = ('LOCAL', 'NEW')) then ()
    else c:session($c:SESSION-ID, true())
  )
  let $d := d:debug(
    ("$c:SESSION: session =", $session, data($session/@version)) )
  (: if no session was found, defer to a local session :)
  let $session := (
    if ($session) then $session
    else if ($c:SESSION-ID eq 'NEW') then c:session-new(true())
    else (
      xdmp:set($c:SESSION-ID, 'LOCAL'),
      c:session-new(false())
    )
  )
  let $id := c:session-id($session)
  let $d := d:debug(("$c:SESSION: session-id =", $id))
  (: locking may fail - if it does, disable sessions :)
  let $lock := (
    if ($c:SESSION-EXCEPTION or 'LOCAL' eq $c:SESSION-ID) then ()
    else try { c:lock-acquire($c:id) } catch ($ex) {
      xdmp:set($c:SESSION-EXCEPTION, $ex) }
  )
  (: ensure that the module session-id matches the final session :)
  let $set := xdmp:set($c:SESSION-ID, $id)
  let $d := d:debug((
      "$c:SESSION: session-id =", $id,
      ' exception =', exists($c:SESSION-EXCEPTION) ))
  return $session
);

declare variable $c:SESSION-DB as xs:unsignedLong :=
  $io:MODULES-DB ;

declare variable $c:SESSION-RELPATH as xs:string := "sessions/" ;

declare variable $c:SESSION-DIRECTORY as xs:string :=
  concat($c:REQUEST-PATH, $c:SESSION-RELPATH) ;

declare variable $c:SESSION-EXCEPTION as element(error:error)? := () ;

(: We expect JavaScript to set a cookie for the session uri.
 : Now that cq supports browser storage, we will assume local storage
 : unless the cookie is explicitly set to a non-local value.
 :)
declare variable $c:SESSION-ID as xs:string? :=
  d:debug(('$c:SESSION-ID:', 'cookies =', $c:COOKIES)),
  d:debug(('$c:SESSION-ID:', 'session-dir =', $c:SESSION-RELPATH)),
  let $matches := $c:COOKIES[@key eq '/cq:session-id']
  let $d := d:debug(('$c:SESSION-ID:', 'matching =', $matches))
  let $id := ($matches/@value)[1]
  let $d := d:debug(('$c:SESSION-ID:', 'value =', $id))
  return $id
;

declare variable $c:SESSION-ETAG as xs:string? :=
  ($c:SESSION/@version, "0")[1] ;

declare variable $c:SESSION-NAME as xs:string? :=
  $c:SESSION/sess:name ;

declare variable $c:SESSION-OWNER as xs:string :=
  concat($su:USER, "@", xdmp:get-request-client-address()) ;

declare variable $c:SESSION-PATH as xs:string :=
  concat(
    $c:SERVER-ROOT-PATH,
    if (ends-with($c:SERVER-ROOT-PATH, '/')
      or starts-with($c:SESSION-DIRECTORY, '/')) then ''
    else '/',
    $c:SESSION-DIRECTORY) ;

declare variable $c:SESSION-TIMEOUT as xs:unsignedLong :=
  xs:unsignedLong(300) ;

declare variable $c:TITLE-TEXT as xs:string :=
  (: show the user what platform and host we're querying :)
  text {
    "cq -",
    concat($su:USER, "@", xdmp:get-request-header("Host")),
    "-", xdmp:product-name(), xdmp:version(),
    "-", xdmp:platform()
  }
;

(: use server version if cq version is missing or unreadable :)
declare variable $c:VERSION as xs:string :=
  let $version := io:read(c:build-document-path('VERSION.xml'))/version
  return
    if ($version) then $version
    else xdmp:version()
;

(: do not call io:lock-acquire directly :)
declare function c:lock-acquire($id as xs:string)
 as empty-sequence()
{
  io:lock-acquire(
    c:uri-from-id($id), "exclusive", "0",
    $c:SESSION-OWNER, $c:SESSION-TIMEOUT
  )
};

declare function c:set-content-type()
 as empty-sequence()
{
  xdmp:set-response-content-type( concat(
      if ($c:ACCEPT-XML) then "application/xhtml+xml" else "text/html",
      "; charset=utf-8") )
};

declare function c:conflicting-locks($uri as xs:string)
 as element(lock:active-lock)*
{
  c:conflicting-locks($uri, ())
};

declare function c:conflicting-locks(
  $uri as xs:string, $limit as xs:integer?)
 as element(lock:active-lock)*
{
  d:debug(('c:conflicting-locks', $uri, $limit, $c:SESSION-OWNER)),
  let $locks := io:get-conflicting-locks($uri, $limit, $c:SESSION-OWNER)
  let $d := d:debug(('c:conflicting-locks',
    $uri, $limit, $c:SESSION-OWNER, $locks))
  return $locks
};

declare function c:available-sessions()
 as element(sess:session)*
{
  c:sessions(true())
};

declare function c:sessions()
 as element(sess:session)*
{
  c:sessions(false())
};

declare function c:sessions($check-conflicting as xs:boolean)
 as element(sess:session)*
{
  d:debug(('c:sessions:', $c:SESSION-DIRECTORY, $check-conflicting)),
  let $result := try {
    (: ignore any id-less sessions - should not happen, but more robust :)
    for $i in io:list($c:SESSION-DIRECTORY)/sess:session[@id/string()]
    where not($check-conflicting)
      or empty(c:conflicting-locks(c:session-uri($i)))
    order by
      if ($i/sess:last-modified castable as xs:dateTime)
      then xs:dateTime($i/sess:last-modified) else () descending,
      if ($i/sess:created castable as xs:dateTime)
      then xs:dateTime($i/sess:created) else () descending,
      $i/name
    return $i
  } catch ($ex) {
    (: if this is a filesystem with no sessions directory, create it.
     : this may throw SVC-DIRCREAT if we don't have write permission.
     :)
    if ($ex/error:code eq 'CQ-ASSERT') then xdmp:rethrow()
    else if ($ex/error:code eq 'SVC-DIROPEN' and $c:SERVER-ROOT-DB eq 0)
    then try {
      xdmp:filesystem-directory-create($c:SESSION-PATH),
      c:sessions($check-conflicting)
    } catch ($fdc-ex) {
      $fdc-ex,
      $ex
    }
    else $ex
  }
  return
    if ($result[1] instance of element(error:error)) then (
      (: looks like we have a problem - disable sessions :)
      d:debug(('c:sessions:', $result)),
      xdmp:set($c:SESSION-EXCEPTION, $result),
      xdmp:set($c:SESSION-ID, ())
      (: returns the empty sequence :)
    )
    else $result
};

declare function c:session(
  $id as xs:string, $check-conflicting as xs:boolean)
 as element(sess:session)?
{
  let $session :=
    try {
      let $path := c:uri-from-id($id)
      let $d := d:debug(('c:session:',
        'id =', $id, ', root =', $io:MODULES-ROOT, ', path =', $path))
      let $exists := io:exists($path)
      let $conflicts :=
        if (not($check-conflicting)) then ()
        else c:conflicting-locks($path)
      let $lock :=
        if (not($check-conflicting) or exists($conflicts)) then ()
        else c:lock-acquire($id)
      where $exists and empty($conflicts)
      return io:read($path)/sess:session
    } catch ($ex) {
      (: if we can't open the file at startup,
       : returning empty will disable sessions
       :)
      if ($ex/error:code eq 'SVC-FILOPN') then ()
      else if ($ex/error:code eq 'SEC-PRIV') then ()
      else xdmp:rethrow()
    }
  let $d := d:debug(('c:session:', $session))
  return $session
};

declare function c:id-from-uri($uri as xs:string)
 as xs:string
{
  substring-before(tokenize($uri, '/+')[last()], '.xml')
};

declare function c:uri-from-id($id as xs:string)
 as xs:string
{
  concat($c:SESSION-DIRECTORY, $id, '.xml')
};

declare function c:session-export(
  $id as xs:string)
 as element(sess:session)
{
  c:session($id, false())
};

declare function c:session-id(
  $session as element(sess:session))
 as xs:string?
{
  (: New sessions will have an id if intended for server session storage,
   : but browser-local sessions will not have an id.
   :)
  (
    $session/@id/string(),
    let $uri := $session/@uri
    where $uri
    return c:id-from-uri($uri)
  )[1]
};

declare function c:session-uri($session as element(sess:session))
 as xs:string?
{
  let $id := c:session-id($session)
  let $uri := c:uri-from-id($id)
  let $d := d:debug(('c:session-uri', $id, $uri))
  where $id
  return $uri
};

declare function c:generate-id()
 as xs:string
{
  let $id := xdmp:integer-to-hex(xdmp:random())
  let $uri := c:uri-from-id($id)
  return if (io:exists($uri)) then c:generate-id() else $id
};

(:
 : Create a new session.
 :)
declare function c:session-new(
  $with-id as xs:boolean)
 as element(sess:session)
{
  let $id := if (not($with-id)) then () else c:generate-id()
  let $d := d:debug(
    ("session-new:", $with-id, $id,
      data($c:SESSION-EXCEPTION/error:format-string)) )
  let $attributes := (
    if (not($id)) then () else attribute id { $id },
    attribute version { 1 }
  )
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
    if ($c:SESSION-EXCEPTION or 'LOCAL' eq $c:SESSION-ID) then ()
    else try {
      c:save-session($new)
    } catch ($ex) {
      (: if something goes wrong, disable sessions :)
      xdmp:set($c:SESSION-EXCEPTION, $ex)
    }
  return $new
};

declare function c:save-session($session as element(sess:session))
 as empty-sequence()
{
  let $id as xs:string := $session/@id[. ne '']
  let $lock := c:lock-acquire($id)
  return io:write(c:uri-from-id($id), document { $session })
};

declare function c:session-delete($id as xs:string)
 as empty-sequence()
{
  (: make sure it really is a session :)
  let $uri := c:uri-from-id($id)
  let $session := io:read($uri)/sess:session
  where $session
  return (
    c:lock-acquire($id),
    io:delete($uri)
  )
};

declare function c:session-clone($source-id as xs:string, $name as xs:string)
 as xs:string
{
  d:debug(("c:session-clone:", $source-id, "as", $name)),
  (: do not check for locks, since we will not update the source :)
  let $source := c:session($source-id, false())
  let $target-id := c:generate-id()
  (: NB - this function does not lock nor return the etag,
   : so the caller must restore the new id before trying to update it.
   :)
  let $do := c:session-update(
    $target-id, (), element sess:name { $name }, $source)
  return $target-id
};

(: rename an existing session by id and etag - must return new etag :)
declare function c:session-rename(
  $id as xs:string, $name as xs:string, $etag as xs:string)
 as xs:string
{
  d:debug(("c:session-rename:", $id, "to", $name, '@', $etag)),
  c:session-update($id, $etag, element sess:name { $name })
};

(: update an existing session by id and etag - must return new etag :)
declare function c:session-update(
  $id as xs:string, $etag as xs:string, $nodes as element()*)
 as xs:string
{
  d:debug(("c:session-update: id =", $id, $etag, $nodes)),
  let $session as element(sess:session)? := c:session($id, true())
  let $assert :=
    if ($session) then ()
    else c:error('CTRL-SESSION', ('No available session for', $id))
  (: allow for older sessions that do not yet have a version attribute :)
  let $version as xs:string := ($session/@version, '0')[1]
  return (
    if ($version ne $etag) then (
      xdmp:set-response-code(412, 'Precondition Failed'),
      text {
        'Precondition Failed:', $etag, 'does not match', $version
      }
    )
    else c:session-update($id, $etag, $nodes, $session)
  )
};

(: NB - This function does not use the etag parameter,
 : but needs to have a different arity from the preceding function.
 :)
(: must return new etag :)
declare function c:session-update(
  $id as xs:string, $etag as xs:string?,
  $nodes as element()*, $session as element(sess:session))
 as xs:string
{
  d:debug(("c:session-update: id =", $id, $nodes, $session)),
  let $last-modified := current-dateTime()
  (: allow for older sessions that do not yet have a version attribute :)
  let $new-version as xs:integer := xs:integer(1 + ($session/@version, 0)[1])
  let $x-attrs as xs:QName+ :=
    for $n in ('id', 'uri', 'version')
    return xs:QName($n)
  let $x-elems as xs:QName+ :=
    for $n in ($nodes, <sec:user/>, <sess:last-modified/>)
    return node-name($n)
  let $session := element { node-name($session) } {
    $session/@*[ not(node-name(.) = $x-attrs) ],
    attribute id { $id },
    attribute version { $new-version },
    (: by default, take ownership :)
    if (exists($nodes/sec:user)) then ()
    else element sec:user { $su:USER },
    $session/node()[ not(node-name(.) = $x-elems) ],
    element sess:last-modified { $last-modified },
    $nodes
  }
  let $do := c:save-session($session)
  return string($new-version)
};

declare function c:app-server-info()
 as element(c:app-server-info)+
{
  (: first, list all the app-servers (except webdav and task servers).
   : next, list all databases that aren't part of an app-server.
   : NOTE: requires MarkLogic Server 4.0-1 or later.
   : TODO provide a mechanism to update the list, to pull admin changes.
   :)
  try {
    for $group-id in admin:get-group-ids($c:ADMIN-CONFIG)
    for $server-id in (
      admin:group-get-httpserver-ids($c:ADMIN-CONFIG, $group-id),
      admin:group-get-xdbcserver-ids($c:ADMIN-CONFIG, $group-id)
    )
    let $database-id as xs:unsignedLong? := try {
      admin:appserver-get-database($ADMIN-CONFIG, $server-id) } catch ($ex) {
      d:exception-log($ex, ('c:app-server-info', $server-id))
    }
    where $database-id
    return element c:app-server-info {
      element c:server-id { $server-id },
      element c:server-name {
        admin:appserver-get-name($c:ADMIN-CONFIG, $server-id)
      },
      element c:database-id { $database-id }
    }
  }
  catch ($ex) {
    if ($ex/error:code eq 'SEC-PRIV')
    then element c:app-server-info {
      element c:server-id { xdmp:server() },
      element c:server-name { xdmp:server-name(xdmp:server()) },
      element c:database-id { xdmp:database() }
    }
    else xdmp:rethrow()
  }
};

declare function c:orphan-database-ids()
 as xs:unsignedLong*
{
  (: list the databases that aren't exposed via an app-server -
   : use reasonable defaults for modules, root values: current server.
   : note that we can default to one of these, too!
   :)
  let $exposed := data($c:APP-SERVER-INFO/c:database-id)
  return try {
    admin:get-database-ids($c:ADMIN-CONFIG)[not(. = $exposed)] }
  catch ($ex) {
    if ($ex/error:code eq 'SEC-PRIV') then ()
    else xdmp:rethrow()
  }
};

declare function c:build-document-path($document-name as xs:string)
 as xs:string {
  let $path := $c:REQUEST-PATH
  (: canonicalize the document-name :)
  let $document-name :=
    if (not(starts-with($document-name, '/')))
    then $document-name
    else replace($document-name, '^(/+)(.+)', '$2')
  return concat($path, $document-name)
};

declare function c:build-form-eval-query(
  $base as xs:string, $keys as item()*, $values as item()*)
 as xs:string
{
  if (count($keys) eq count($values)) then ()
  else c:error('CQ-MISMATCH', 'keys do not match values')
  ,
  string-join((
      $base,
      '?',
      string-join((
          concat('eval=', $c:FORM-EVAL),
          for $x in 1 to count($keys)
          return concat($keys[$x], '=', xdmp:url-encode(string($values[$x])))
          ), '&amp;')
      ), '')
};

declare function c:request-string($excludes as xs:string*)
 as xs:string
{
  (: use the last request string to build a new one,
   : excluding pagination data
   :)
  concat(
    "?",
    string-join(
      for $f in xdmp:get-request-field-names()
        [not(. = $excludes)]
      let $values := xdmp:get-request-field($f)
      for $v in $values
      return string-join(
        (xdmp:url-encode($f), xdmp:url-encode($v)), "="),
      "&amp;"
    )
  )
};

declare function c:pagination-href($start as xs:integer)
 as xs:string
{
  c:pagination-href($start, (), ())
};

declare function c:pagination-href(
 $start as xs:integer, $keys as xs:string*, $values as xs:string*)
as xs:string
{
  (: TODO cache-buster for IE? :)
  concat(
    c:request-string(("submit", "start", "search-button", $keys)),
    "&amp;", xdmp:url-encode("start"), "=", string($start),
    if (not($keys)) then ''
    else string-join((
        '',
        for $x in 1 to count($keys)
        return concat($keys[$x], '=', xdmp:url-encode(string($values[$x])))
        ), '&amp;')
  )
};

declare function c:assert-read-only()
 as empty-sequence()
{
  if (xdmp:request-timestamp()) then ()
  else c:error('CQ-NOTREADONLY', 'query is not read-only')
};

(:~ convenience wrapper, for XQuery 1.0-ml conformance :)
declare function c:error($code as xs:string)
 as empty-sequence()
{
  c:error($code, ())
};

(:~ convenience wrapper, for XQuery 1.0-ml conformance :)
declare function c:error($code as xs:string, $details as item()*)
 as empty-sequence()
{
  error((), $code, text { $details })
};

(: lib-controller.xqy :)
