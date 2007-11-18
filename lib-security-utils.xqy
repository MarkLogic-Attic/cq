xquery version "0.9-ml"
(:
 : cq: lib-security-utils.xqy
 :
 : Copyright (c)2002-2007 Mark Logic Corporation. All Rights Reserved.
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
module "com.marklogic.developer.cq.security"

default function namespace = "http://www.w3.org/2003/05/xpath-functions"

declare namespace su = "com.marklogic.developer.cq.security"

import module "http://marklogic.com/xdmp/security"
  at "/MarkLogic/security.xqy"

define variable $su:USER as xs:string { xdmp:get-current-user() }

define variable $su:USER-ID as xs:unsignedLong {
  su:get-user-id($su:USER) }

define variable $su:USER-IS-ADMIN as xs:boolean {
  (: apparently this does not need to eval in the security database? :)
  try { sec:check-admin(), true() } catch ($ex) { false() } }

(: Sadly, xdmp:get-current-user() only returns the username.
 : Sometimes we need the id.
 :)
define function su:get-user-id($username as xs:string)
 as xs:unsignedLong
{
  xdmp:eval(
    'xquery version "0.9-ml"
     define variable $USER as xs:string external
     import module "http://marklogic.com/xdmp/security"
      at "/MarkLogic/security.xqy"
     sec:uid-for-name($USER)',
     (xs:QName('USER'), $username),
     <options xmlns="xdmp:eval">
       <database>{ xdmp:security-database() }</database>
       <isolation>different-transaction</isolation>
     </options>
  )
}

(: lib-security-utils.xqy :)
