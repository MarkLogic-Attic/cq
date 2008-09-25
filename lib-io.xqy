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

(:
 : This library provides routines for reading and writing server modules,
 : whether stored on the filesystem or in a database.
 :)
module namespace io = "com.marklogic.developer.cq.io";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

import module namespace admin = "http://marklogic.com/xdmp/admin"
  at "/MarkLogic/admin.xqy";

import module namespace su = "com.marklogic.developer.cq.security"
  at "lib-security-utils.xqy";

import module namespace x = "com.marklogic.developer.cq.xquery"
 at "lib-xquery.xqy";

declare namespace dir = "http://marklogic.com/xdmp/directory";

(:~ @private :)
declare variable $io:MODULES-DB as xs:unsignedLong :=
  xdmp:modules-database()
;

(:~ @private :)
declare variable $io:MODULES-ROOT as xs:string :=
  (: life is easier if the root does not end in "/" :)
  let $root := xdmp:modules-root()
  return
    if (ends-with($root, "/"))
    then substring($root, 1, string-length($root) - 1)
    else $root
;

(:~ @private :)
declare variable $io:EVAL-OPTIONS as element() :=
  <options xmlns="xdmp:eval">{
    element database { $io:MODULES-DB }
  }</options>
;

(:~ read the contents of a path :)
declare function io:read($path as xs:string)
  as document-node()?
{
  let $path := io:canonicalize($path)
  return
    if ($io:MODULES-DB eq 0)
    then io:read-fs($path)
    else io:read-db($path)
};

(:~ write a document-node to a path :)
declare function io:write($path as xs:string, $new as document-node())
  as empty-sequence()
{
  let $path := io:canonicalize($path)
  return
    if ($io:MODULES-DB eq 0)
    then io:write-fs($path, $new)
    else io:write-db($path, $new)
};

(:~ list contents of a directory path :)
declare function io:list($path as xs:string)
  as document-node()*
{
  (: TODO pagination :)
  let $path := io:canonicalize($path)
  return
    if ($io:MODULES-DB eq 0)
    then io:list-fs($path)
    else io:list-db($path)
};

(:~ delete a path :)
declare function io:delete($path as xs:string)
 as empty-sequence()
{
  let $path := io:canonicalize($path)
  return
    if ($io:MODULES-DB eq 0)
    then io:delete-fs($path)
    else io:delete-db($path)
};

(:~ return true if path exists :)
declare function io:exists($path as xs:string)
 as xs:boolean
{
  let $path := io:canonicalize($path)
  return
    if ($io:MODULES-DB eq 0)
    then io:exists-fs($path)
    else io:exists-db($path)
};

(:~ release a lock :)
declare function io:lock-release($path as xs:string)
  as empty-sequence()
{
  let $path := io:canonicalize($path)
  return
    if ($io:MODULES-DB eq 0)
    then io:lock-release-fs($path)
    else io:lock-release-db($path)
};

(:~ acquire a lock :)
declare function io:lock-acquire($path as xs:string)
  as empty-sequence()
{
  io:lock-acquire($path, (), (), (), xs:unsignedLong(300))
};

(:~ acquire a lock :)
declare function io:lock-acquire(
  $path as xs:string, $scope as xs:string?,
  $depth as xs:string?, $owner as item()?,
  $timeout as xs:unsignedLong?)
  as empty-sequence()
{
  if ($path eq '' or ends-with($path, '/'))
  then error(xs:QName('IO-BADPATH'), text { $path })
  else (),
  let $path := io:canonicalize($path)
  (: a pox on varargs - anyway, we can spec our own defaults :)
  let $scope := ($scope[. = ("exclusive", "shared")], "exclusive")[1]
  let $depth := ($depth[. = ("0", "infinity")], "0")[1]
  let $owner := ($owner, xdmp:get-current-user())[1]
  (: NB empty timeout is considered infinite :)
  return
    if ($io:MODULES-DB eq 0)
    then io:lock-acquire-fs($path, $scope, $depth, $owner, $timeout)
    else io:lock-acquire-db($path, $scope, $depth, $owner, $timeout)
};

(:~ list locks :)
declare function io:document-locks($paths as xs:string*)
 as document-node()*
{
  let $paths := for $path in $paths return io:canonicalize($path)
  return
    if ($io:MODULES-DB eq 0)
    then io:document-locks-fs($paths)
    else io:document-locks-db($paths)
};

(:~ @private :)
declare function io:exists-db($uri as xs:string)
 as xs:boolean
{
  xdmp:eval(
    'xquery version "1.0-ml";
     declare variable $URI as xs:string external;
     xdmp:exists(doc($URI))',
    (xs:QName('URI'), $uri),
    $io:EVAL-OPTIONS
  )
};

(:~ @private :)
declare function io:exists-fs($path as xs:string)
 as xs:boolean
{
  try {
    exists(xdmp:document-get($path))
  } catch ($ex) {
    false(),
    if ($ex/error:code eq 'SVC-FILOPN') then ()
    else xdmp:log(text {
      "io:exists-fs:", normalize-space(xdmp:quote($ex)) })
  }
};

(:~ @private :)
declare function io:delete-db($uri as xs:string)
 as empty-sequence()
{
  xdmp:eval(
    'xquery version "1.0-ml";
     declare variable $URI as xs:string external;
     xdmp:document-delete($URI)',
    (xs:QName('URI'), $uri),
    $io:EVAL-OPTIONS
  )
};

(:~ @private :)
declare function io:delete-fs($path as xs:string)
 as empty-sequence()
{
  (: TODO we cannot delete the document, so save an empty text node. :)
  xdmp:save($path, text { '' })
};

(:~ @private :)
declare function io:list-db($uri as xs:string)
  as document-node()*
{
  xdmp:eval(
    'xquery version "1.0-ml";
     declare variable $URI as xs:string external;
     xdmp:directory($URI, "1")',
    (xs:QName('URI'), $uri),
    $io:EVAL-OPTIONS
  )
};

(:~ @private :)
declare function io:list-fs($path as xs:string)
  as document-node()*
{
  for $p in data(xdmp:filesystem-directory($path)/dir:entry
    [ dir:type eq "file" ]/dir:pathname)
  return xdmp:document-get(
    $p,
    <options xmlns="xdmp:document-get">{
      element format { 'xml' } }</options>
  )
};

(:~ @private :)
declare function io:canonicalize($path as xs:string)
  as xs:string
{
  concat(
    $io:MODULES-ROOT,
    "/"[not(starts-with($path, "/"))],
    $path
  )
};

(:~ @private :)
declare function io:lock-path-fs($path as xs:string)
  as xs:string
{
  (: primitive, yet messy :)
  concat($path, ".lock")
};

(:~ @private :)
declare function io:read-db($uri as xs:string)
  as document-node()?
{
  xdmp:eval(
    'xquery version "1.0-ml";
     declare variable $URI as xs:string external;
     doc($URI)',
    (xs:QName('URI'), $uri),
    $io:EVAL-OPTIONS
  )
};

(:~ @private :)
declare function io:read-fs($path as xs:string)
  as document-node()?
{
  if (ends-with($path, "/")) then () else try {
    (: hack - possibly a problem with ntfs streams? :)
    xdmp:document-get(
      $path,
      <options xmlns="xdmp:document-get">
        <format>xml</format>
      </options>
    )[1]
  } catch ($ex) {
    if ($ex/error:code eq 'SVC-FILOPN') then ()
    else xdmp:log(text {
      "io:read-fs:", normalize-space(xdmp:quote($ex)) })
  }
};

(:~ @private :)
declare function io:write-db($uri as xs:string, $new as document-node())
  as empty-sequence()
{
  xdmp:eval(
    'xquery version "1.0-ml";
     declare variable $URI as xs:string external;
     declare variable $NEW as document-node() external;
     declare variable $EXISTS as xs:boolean := xdmp:exists(doc($URI));
     xdmp:document-insert(
       $URI, $NEW,
       if ($EXISTS) then xdmp:document-get-permissions($URI)
       else xdmp:default-permissions(),
       if ($EXISTS) then xdmp:document-get-collections($URI)
       else xdmp:default-collections(),
       if ($EXISTS) then xdmp:document-get-quality($URI)
       else 0
     )',
    (xs:QName('URI'), $uri, xs:QName('NEW'), $new),
    $io:EVAL-OPTIONS
  )
};

(:~ @private :)
declare function io:write-fs($path as xs:string, $new as document-node())
  as empty-sequence()
{
  xdmp:save($path, $new)
};

(:~ @private :)
declare function io:lock-release-db($uri as xs:string)
 as empty-sequence()
{
  xdmp:eval(
    'xquery version "1.0-ml";
     declare variable $URI as xs:string external;
     xdmp:lock-release($URI)',
    (xs:QName('URI'), $uri),
    $io:EVAL-OPTIONS
  )
};

(:~ @private :)
declare function io:lock-release-fs($path as xs:string)
 as empty-sequence()
{
  (: filesystem lock-release - check and release.
   : This might do ok with multiple locks.
   :)
  let $old := io:document-locks($path)/lock:lock
  let $locks := $old/lock:active-locks/lock:active-lock
  let $check :=
    if (exists($locks)) then ()
    else error(xs:QName("IO-NOTLOCKED"), text { $path, "is not locked" })
  let $check :=
    if ($su:USER-IS-ADMIN or $locks[sec:user-id eq $su:USER-ID]) then ()
    else error(
      xs:QName("IO-NOUSER"), text {
        $path, "is not locked by", $su:USER, $su:USER-ID,
        "existing locks are held by", data($locks/sec:user-id)
      }
    )
  let $path := io:canonicalize($path)
  let $lock-path := io:lock-path-fs($path)
  return
    if ($su:USER-IS-ADMIN or empty($locks[ sec:user-id ne $su:USER-ID ]))
    then io:delete-fs($lock-path)
    else io:write-fs($lock-path, document {
      element {node-name($old)} {
        $old/@*,
        $old/node()[ node-name(.) ne xs:QName("lock:active-locks") ],
        element lock:active-locks {
          $old/lock:active-locks/@*,
          $old/lock:active-locks/node()
            [ node-name(.) ne xs:QName("lock:active-locks") ],
          $locks[ sec:user-id ne $su:USER-ID ]
        }
      }
    } )
};

(:~ @private :)
declare function io:lock-acquire-db(
  $uri as xs:string, $scope as xs:string,
  $depth as xs:string, $owner as item(),
  $timeout as xs:unsignedLong)
  as empty-sequence()
{
  xdmp:eval(
    'xquery version "1.0-ml";
     declare variable $URI as xs:string external;
     declare variable $SCOPE as xs:string external;
     declare variable $DEPTH as xs:string external;
     declare variable $OWNER as xs:string external;
     declare variable $TIMEOUT as xs:unsignedLong external;
     xdmp:lock-acquire($URI, $SCOPE, $DEPTH, $OWNER, $TIMEOUT)',
    (xs:QName('URI'), $uri, xs:QName('SCOPE'), $scope,
     xs:QName('DEPTH'), $depth, xs:QName('OWNER'), $owner,
     xs:QName('TIMEOUT'), $timeout),
    $io:EVAL-OPTIONS
  )
};

declare function io:get-conflicting-locks(
  $uri as xs:string, $limit as xs:integer?, $owner as xs:string
)
 as element(lock:active-lock)*
{
  (: a lock is conflicting if...
   :   1. it is a write-lock
   :   2. the owner is not $owner
   :   3. it has an active-lock which has not expired
   :)
  let $now := x:get-epoch-seconds()
  let $locks :=
    for $c in io:document-locks($uri)
      /lock:lock[lock:lock-type eq 'write']
      /lock:active-locks/lock:active-lock
        [ lock:owner ne $owner ]
    let $timeout := data($c/lock:timeout)
    let $expires :=
      if (empty($timeout)) then (1 + $now)
      else ($c/lock:timestamp + xs:unsignedLong($timeout))
    where $expires ge $now
    (: we only care about the lock(s) that expires last.
     : an empty timeout is considered infinite.
     :)
    order by empty($timeout) descending, $expires descending
    return $c
  return
    if (empty($limit)) then $locks else subsequence($locks, 1, $limit)
};

(:~ @private :)
declare function io:lock-acquire-fs(
  $path as xs:string, $scope as xs:string,
  $depth as xs:string, $owner as item(),
  $timeout as xs:unsignedLong?)
 as empty-sequence()
{
  (: NB: the caller is responsible for checking our arguments! :)
  (: TODO does not handle multiple locks, shared vs exclusive :)
  (: first... can we lock this path?
   : admin always can... others can only break their own locks.
   :)
  let $conflict :=
    if ($su:USER-IS-ADMIN) then ()
    else io:document-locks($path)/lock:lock/lock:active-locks
      /lock:active-lock[ sec:user-id ne $su:USER-ID ]
  let $check :=
    if (not($conflict)) then ()
    else error(
      xs:QName("IO-LOCKED"),
      text { $path, "is locked by", $conflict/lock:owner }
    )
  let $lock := document {
    element lock:lock {
      element lock:lock-type { "write" },
      element lock:lock-scope { $scope },
      element lock:active-locks {
        element lock:active-lock {
          element lock:depth { $depth },
          element lock:owner { $owner },
          element lock:timeout { $timeout },
          element lock:lock-token {
            concat(
              'http://marklogic.com/xdmp/locks/',
              xdmp:integer-to-hex(xdmp:random())
            )
          },
          element lock:timestamp { x:get-epoch-seconds() },
          element sec:user-id { $su:USER-ID }
        }
      }
    }
  }
  let $path := io:lock-path-fs($path)
  return io:write-fs($path, $lock)
};

(:~ @private :)
declare function io:document-locks-db($uris as xs:string*)
 as document-node()*
{
  xdmp:eval(
    'xquery version "1.0-ml";
     declare variable $URIS-SSV as xs:string external;
     declare variable $URIS as xs:string+ := tokenize($URIS-SSV, "\s+");
     xdmp:document-locks($URIS)',
    (xs:QName('URIS-SSV'), string-join($uris, ' ')),
    $io:EVAL-OPTIONS
  )
};

(:~ @private :)
declare function io:document-locks-fs($paths as xs:string*)
 as document-node()*
{
  for $path in $paths
  let $lock-path := io:lock-path-fs($path)
  let $fs := io:read-fs($lock-path)
  return $fs
};

(: lib-io.xqy :)
