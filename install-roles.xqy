xquery version "1.0-ml";
(:
 : cq
 :
 : Copyright (c) 2002-2010 MarkLogic Corporation. All Rights Reserved.
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

import module namespace c = "com.marklogic.developer.cq.controller"
 at "lib-controller.xqy";

declare option xdmp:mapping "false";

declare variable $CONFIG :=
<roles>
  <role name="cq-basic">
    <exec-privilege>profile-my-requests</exec-privilege>
    <exec-privilege>xdmp:add-response-header</exec-privilege>
    <exec-privilege>xdmp:eval</exec-privilege>
    <exec-privilege>xdmp:invoke</exec-privilege>
    <exec-privilege>xdmp:license-accepted</exec-privilege>
  </role>
  <role name="cq-sessions">
    <role name="cq-basic"/>
{
  if (xdmp:modules-database() eq 0) then (
    <exec-privilege>xdmp:document-get</exec-privilege>,
    <exec-privilege>xdmp:filesystem-directory</exec-privilege>,
    <exec-privilege>xdmp:save</exec-privilege> )
  else (
    element uri-privilege {
      attribute name {
        concat('cq-uri-privilege-',
          translate($c:SERVER-APPLICATION-PATH, '/', '-') ) },
      $c:SERVER-APPLICATION-PATH },
    <permission name="cq-sessions-permission"
     capability="read update insert">cq-sessions</permission>
  )
}
  </role>
  <role name="cq-databases">
    <role name="cq-basic"/>
    <exec-privilege>admin:module-read</exec-privilege>
    <exec-privilege>xdmp:eval-in</exec-privilege>
    <exec-privilege>xdmp:eval-modules-change</exec-privilege>
    <exec-privilege>xdmp:eval-modules-change-file</exec-privilege>
    <exec-privilege>xdmp:invoke-in</exec-privilege>
    <exec-privilege>xdmp:invoke-modules-change</exec-privilege>
    <exec-privilege>xdmp:invoke-modules-change-file</exec-privilege>
  </role>
  <role name="cq-all">
    <role name="cq-basic"/>
    <role name="cq-sessions"/>
    <role name="cq-databases"/>
  </role>
</roles>
;

if (xdmp:request-timestamp()) then ()
else error(
  (), 'CQ-NOTIMESTAMP',
  text { 'install-roles.xqy must run in timestamped mode.' } )
,
let $options :=
  <options xmlns="xdmp:eval">
    <database>{ xdmp:security-database() }</database>
    <isolation>different-transaction</isolation>
  </options>
for $role in $CONFIG/role
for $module in (
  'install-roles-invokable.xqy', 'configure-roles-invokable.xqy')
return xdmp:invoke($module, (xs:QName('ROLE'), $role), $options)

(: install-roles.xqy :)