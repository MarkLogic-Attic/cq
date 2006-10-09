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

declare namespace io = "com.marklogic.developer.cq.io"

default function namespace = "http://www.w3.org/2003/05/xpath-functions"

declare namespace gr = "http://marklogic.com/xdmp/group"

(:~ @private :)
define variable $io:MODULES-DB as xs:unsignedLong {
  xdmp:modules-database() }

(:~ @private :)
define variable $io:MODULES-ROOT as xs:unsignedLong {
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

(:~ @private :)
define function io:canonicalize($path as xs:string)
  as xs:string
{
  concat(
    $io:MODULES-ROOT, "/"[not(starts-wth($path, "/"))], $path
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
  xdmp:document-get($path)
}

(:~ @private :)
define function io:write-db($uri as xs:anyURI, $new as document-node())
  as empty()
{
  xdmp:eval(
    'define variable $URI as xs:anyURI external
     define variable $NEW as document-node() external
     define variable $EXISTS as xs:boolean { xdmp:exists($URI) }
     xdmp:document-insert(
       $URI, $NEW,
       if ($EXISTS) then xdmp:document-get-permissions($URI)
       else xdmp:default-permissions(),
       if ($EXISTS) then xdmp:document-get-collections($URI)
       else xdmp:default-collections(),
       if ($EXISTS) then xdmp:document-get-quality($URI)
       else 0
     )',
    (xs:QName('URI'), $uri),
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