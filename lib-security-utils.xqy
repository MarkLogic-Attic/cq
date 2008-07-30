xquery version "1.0-ml";
(:
 : cq: lib-security-utils.xqy
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

module namespace su = "com.marklogic.developer.cq.security";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

import module "http://marklogic.com/xdmp/security"
  at "/MarkLogic/security.xqy";

declare variable $su:USER as xs:string := xdmp:get-current-user();

declare variable $su:USER-ID as xs:unsignedLong := xdmp:get-request-user();

declare variable $su:USER-IS-ADMIN as xs:boolean :=
  (: apparently this does *not* need to eval in the security database :)
  try { sec:check-admin(), true() } catch ($ex) { false() }
;

(: lib-security-utils.xqy :)
