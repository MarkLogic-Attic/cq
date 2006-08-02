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
module "com.marklogic.xqzone.cq.controller"

declare namespace c = "com.marklogic.xqzone.cq.controller"

default function namespace = "http://www.w3.org/2003/05/xpath-functions"

define variable $c:g-debug as xs:boolean { false() }

define variable $c:g-nl { fn:codepoints-to-string((10)) }

define function c:get-debug() as xs:boolean { $c:g-debug }

define function c:debug-on() as empty() { xdmp:set($c:g-debug, true()) }
define function c:debug-off() as empty() { xdmp:set($c:g-debug, false()) }

define function c:debug($s as item()*)
 as empty()
{
  if (not($c:g-debug)) then () else xdmp:log(
    string-join(("DEBUG:", translate(xdmp:quote($s), $c:g-nl, " ")), " ")
  )
}

define function c:check-debug()
 as empty()
{
  if (xs:boolean(xdmp:get-request-field("debug", string($c:g-debug))))
  then c:debug-on()
  else ()
}

(: lib-controller.xqy :)