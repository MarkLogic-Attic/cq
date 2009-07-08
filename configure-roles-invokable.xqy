xquery version "1.0-ml";
(:
 : Client Query Application
 :
 : Copyright (c) 2002-2009 Mark Logic Corporation. All Rights Reserved.
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

import module namespace sec="http://marklogic.com/xdmp/security"
 at "/MarkLogic/security.xqy";

declare variable $ROLE as element(role) external;

(: check environment :)
if (xdmp:database() eq xdmp:security-database()) then ()
else error(
  (), 'CQ-NOTSECURITY',
  ('Current database', xdmp:database-name(xdmp:database()),
    'is not the security database'))
,
(: configure sub-roles :)
sec:role-set-roles($ROLE/@name, $ROLE/role/@name)
,
(: configure privileges :)
for $priv in $ROLE/(exec-privilege|uri-privilege)
let $action as xs:string := (
  (: NB - only supports built-in exec privs :)
  typeswitch($priv)
  case element(exec-privilege) return concat(
    'http://marklogic.com/xdmp/privileges/',
    translate($priv, ':', '-') )
  case element(uri-privilege) return $priv
  default return error(
    (), 'CQ-UNEXPECTED', text { xdmp:unquote($priv) })
)
let $kind as xs:string := (
  typeswitch($priv)
  case element(exec-privilege) return 'execute'
  case element(uri-privilege) return 'uri'
  default return error(
    (), 'CQ-UNEXPECTED', text { xdmp:unquote($priv) })
)
where not(sec:privilege-get-roles($action, $kind) = $ROLE/@name)
return text {
  sec:privilege-add-roles($action, $kind, $ROLE/@name),
  'role', $ROLE/@name, 'added', $kind, $action
}
,
(: configure permissions :)
sec:role-set-default-permissions(
  $ROLE/@name,
  for $perm in $ROLE/permission
  for $capability in xs:NMTOKENS($perm/@capability)
  return xdmp:permission($ROLE/@name, $capability)
)
,
text { 'role', $ROLE/@name, 'configured', current-dateTime() }

(: configure-roles-invokable.xqy :)