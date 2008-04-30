xquery version "0.9-ml"
(:
 : cq: lib-debug.xqy
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
module "com.marklogic.developer.cq.debug"

default function namespace = "http://www.w3.org/2003/05/xpath-functions"

declare namespace d = "com.marklogic.developer.cq.debug"

define variable $d:NL { fn:codepoints-to-string((10)) }

define variable $d:DEBUG as xs:boolean { false() }

define variable $d:DEBUG-FIELD as xs:string { "debug" }

define function d:get-debug() as xs:boolean { $d:DEBUG }

define function d:debug-on()
 as empty()
{
  xdmp:set($d:DEBUG, true()),
  d:debug("debug is on")
}

define function d:debug-off() as empty() {
  xdmp:set($d:DEBUG, false())
}

define function d:debug($s as item()*)
 as empty()
{
  if (not($d:DEBUG)) then () else xdmp:log(
    string-join(("DEBUG:", translate(xdmp:quote($s), $d:NL, " ")), " ")
  )
}

define function d:check-debug()
 as empty()
{
  if (xs:boolean(xdmp:get-request-field($d:DEBUG-FIELD, string($d:DEBUG))))
  then d:debug-on()
  else ()
}

(: lib-debug.xqy :)
