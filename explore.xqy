xquery version "1.0-ml";
(:
 : Content Query Tool (cq)
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
 :
 : explore.xqy - fancy list of up to N documents, including root node type.
 :
 :)

import module namespace c = "com.marklogic.developer.cq.controller"
 at "lib-controller.xqy";

import module namespace d = "com.marklogic.developer.cq.debug"
 at "lib-debug.xqy";

declare variable $FILTER :=
  xdmp:get-request-field('filter');

declare variable $FILTER-TEXT as xs:string? :=
  xdmp:get-request-field('filter-text', '');

declare variable $START as xs:integer :=
  xs:integer(xdmp:get-request-field('start', '1'));

declare variable $SIZE as xs:integer :=
  xs:integer(xdmp:get-request-field('size', '20'));

d:check-debug(),
let $options :=
  <options xmlns="xdmp:eval">
  {
    element database { $c:FORM-EVAL-DATABASE-ID },
    element root { $c:SERVER-APPLICATION-PATH },
    element modules { $c:SERVER-ROOT-DB }
  }
  </options>
let $d := d:debug(('explore:', $options, $START, $SIZE, $FILTER, $FILTER-TEXT))
let $filter :=
  for $i in $FILTER
  return cts:query(xdmp:unquote($i)/*)
let $filter as cts:query? :=
  if (not($filter)) then ()
  else if (count($filter) eq 1) then $filter
  else cts:and-query($filter)
return xdmp:invoke(
  'explore-invokable.xqy',
  (xs:QName('START'), $START, xs:QName('SIZE'), $SIZE,
   xs:QName('FILTER-TEXT'), $FILTER-TEXT,
   xs:QName('FILTER'),
   if (not($filter)) then '' else xdmp:quote(document { $filter })
  ),
  $options
)

(: explore.xqy :)