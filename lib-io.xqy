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

(:
 : This library provides routines for reading and writing server modules,
 : whether stored on the filesystem or in a database.
 :)
module "com.marklogic.developer.cq.io"

default function namespace = "http://www.w3.org/2003/05/xpath-functions"

import module namespace c = "com.marklogic.developer.cq.controller"
  at "lib-controller.xqy"

declare namespace io = "com.marklogic.developer.cq.io"
declare namespace gr = "http://marklogic.com/xdmp/group"
declare namespace dir = "http://marklogic.com/xdmp/directory"

(:~ @private :)
define variable $io:MODULES-DB as xs:unsignedLong {
  xdmp:modules-database() }

(:~ @private :)
define variable $io:MODULES-ROOT as xs:string {
  (: life is easier if the root does not end in "/" :)
  let $root := xdmp:modules-root()
  return
    if (ends-with($root, "/"))
    then substring($root, 1, string-length($root) - 1)
    else $root
}

(:~ @private :)
define variable $io:EVAL-OPTIONS as element() {
  <options xmlns="xdmp:eval">
    <database>{ $io:MODULES-DB }</database>
  </options>
}

(:~ read the contents of a path :)
define function io:read($path as xs:string)
  as document-node()?
{
  let $path := io:canonicalize($path)
  return
    if ($io:MODULES-DB eq 0)
    then io:read-fs($path)
    else io:read-db(xs:anyURI($path))
}

(:~ write a document-node to a path :)
define function io:write($path as xs:string, $new as document-node())
  as empty()
{
  let $path := io:canonicalize($path)
  return
    if ($io:MODULES-DB eq 0)
    then io:write-fs($path, $new)
    else io:write-db(xs:anyURI($path), $new)
}

(:~ replace an existing node :)
define function io:node-replace(
  $uri as xs:anyURI, $doc as document-node(),
  $old as node(), $new as node())
 as empty()
{
  if ($io:MODULES-DB ne 0)
  then xdmp:node-replace($old, $new)
  else io:node-replace-fs($uri, $doc, $old, $new)
}

(:~ insert a new child node :)
define function io:node-insert-child(
  $uri as xs:anyURI, $doc as document-node(),
  $parent as node(), $new as node())
 as empty()
{
  if ($io:MODULES-DB ne 0)
  then xdmp:node-insert-child($parent, $new)
  else io:node-insert-child-fs($uri, $doc, $parent, $new)
}

(:~ list contents of a directory path :)
define function io:list($path as xs:string)
  as document-node()*
{
  (: TODO pagination :)
  let $path := io:canonicalize($path)
  return
    if ($io:MODULES-DB ne 0)
    then xdmp:directory($path, "infinity")
    else io:list-fs($path)
}

(:~ delete a path :)
define function io:delete($path as xs:string)
 as empty()
{
  let $path := io:canonicalize($path)
  return
    if ($io:MODULES-DB ne 0)
    then xdmp:document-delete($path)
    else io:delete-fs($path)
}

(:~ return true if path exists :)
define function io:exists($path as xs:string)
 as xs:boolean
{
  let $path := io:canonicalize($path)
  return
    if ($io:MODULES-DB ne 0)
    then xdmp:exists(doc($path))
    else io:exists-fs($path)
}

(:~ @private :)
define function io:exists-fs($path as xs:string)
 as xs:boolean
{
  try {
    exists(xdmp:document-get($path))
  } catch ($ex) {
    false(),
    if ($ex/err:code eq 'SVC-FILOPN') then ()
    else xdmp:log(text {
      "io:exists-fs:", normalize-space(xdmp:quote($ex)) })
  }
}

(:~ @private :)
define function io:delete-fs($path as xs:string)
 as empty()
{
  (: TODO filesystem delete :)
  error("UNIMPLEMENTED")
}

(:~ @private :)
define function io:node-insert-child-fs(
  $uri as xs:anyURI, $doc as document-node(),
  $parent as node(), $new as node())
 as empty()
{
  io:write(
    $uri,
    document { io:node-insert-child-R($doc, $parent, $new) }
  )
}

(:~ @private :)
define function io:node-replace-fs(
  $uri as xs:anyURI, $doc as document-node(),
  $old as node(), $new as node())
 as empty()
{
  io:write(
    $uri,
    document { io:node-replace-R($doc, $old, $new) }
  )
}

(:~ @private :)
define function io:node-insert-child-R(
  $input as node()*, $parent as node(), $new as node())
as node()*
{
  (: TODO node-insert-child-fs :)
  error("UNIMPLEMENTED"),
  for $n in $input
  return typeswitch ($n)
    case element()
    return
      if ($n is $parent)
      then element {node-name($parent)} {
        $n/(@*|node()), $new
      }
      else element {node-name($n)} {
        io:node-insert-child-R($n/(@*|node()), $parent, $new)
      }
    default return $n
}

(:~ @private :)
define function io:node-replace-R(
  $input as node()*, $old as node(), $new as node())
as node()*
{
  (: TODO node-replace-fs :)
  error("UNIMPLEMENTED"),
  for $n in $input
  return typeswitch ($n)
    case element()
    return
      if ($n is $old) then $new
      else element {node-name($n)} {
        io:node-replace-R($n/(@*|node()), $old, $new)
      }
    default return
      if ($n is $old) then $new else $old
}

(:~ @private :)
define function io:list-fs($path as xs:string)
  as document-node()*
{
  for $p in data(xdmp:filesystem-directory($path)/dir:entry
    [ dir:type eq "file" ]/dir:pathname)
  return xdmp:document-get(
    $p,
    <options xmlns="xdmp:document-get">{
      element format { 'xml' } }</options>
  )
}

(:~ @private :)
define function io:canonicalize($path as xs:string)
  as xs:string
{
  concat(
    $io:MODULES-ROOT, "/"[not(starts-with($path, "/"))], $path
  )
}

(:~ @private :)
define function io:read-db($uri as xs:anyURI)
  as document-node()?
{
  xdmp:eval(
    'define variable $URI as xs:anyURI external
     doc($URI)',
    (xs:QName('URI'), $uri),
    $io:EVAL-OPTIONS
  )
}

(:~ @private :)
define function io:read-fs($path as xs:string)
  as document-node()?
{
  if (ends-with($path, "/")) then () else try {
    (: hack - possibly a problem with ntfs streams? :)
    xdmp:document-get($path)[1]
  } catch ($ex) {
    if ($ex/err:code eq 'SVC-FILOPN') then ()
    else xdmp:log(text {
      "io:exists-fs:", normalize-space(xdmp:quote($ex)) })
  }
}

(:~ @private :)
define function io:write-db($uri as xs:anyURI, $new as document-node())
  as empty()
{
  xdmp:eval(
    'define variable $URI as xs:anyURI external
     define variable $NEW as document-node() external
     define variable $EXISTS as xs:boolean { xdmp:exists(doc($URI)) }
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
}

(:~ @private :)
define function io:write-fs($path as xs:string, $new as document-node())
  as empty()
{
  xdmp:save($path, $new)
}

(: lib-io.xqy :)