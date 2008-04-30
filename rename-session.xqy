xquery version "0.9-ml"
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

define variable $ID as xs:string {
  xdmp:get-request-field("ID") }

define variable $NAME as xs:string {
  xdmp:get-request-field("NAME") }

define variable $DEBUG as xs:boolean {
  xs:boolean(xdmp:get-request-field("DEBUG", 'false')) }

import module namespace c = "com.marklogic.developer.cq.controller"
 at "lib-controller.xqy"

import module namespace d = "com.marklogic.developer.cq.debug"
 at "lib-debug.xqy"

if ($DEBUG) then d:debug-on() else (),
c:rename-session($ID, $NAME)

(: rename-session.xqy :)
