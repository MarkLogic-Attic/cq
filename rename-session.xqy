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

define variable $DB as xs:unsignedLong {
  xs:unsignedLong(xdmp:get-request-field("DB")) }

define variable $URI as xs:anyURI {
  xs:anyURI(xdmp:get-request-field("URI")) }

define variable $NAME as xs:string {
  xdmp:get-request-field("NAME") }

import module namespace c="com.marklogic.developer.cq.controller"
 at "lib-controller.xqy"

let $opts :=
  <options xmlns="xdmp:eval">
    <database>{ $DB }</database>
  </options>
return
  if (xdmp:database() eq $DB)
  then c:rename-session($DB, $URI, $NAME)
  else xdmp:invoke('rename-session.xqy', (), $opts)

(: rename-session.xqy :)