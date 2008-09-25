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
 : view.xqy - handy query to view one document, as native type
 :
 :)

import module namespace c = "com.marklogic.developer.cq.controller"
 at "lib-controller.xqy";

declare variable $PROPERTIES as xs:boolean :=
  xs:boolean(xdmp:get-request-field('properties', '0'))
;

declare variable $URI as xs:string :=
  xdmp:get-request-field('uri')
;

let $options :=
  <options xmlns="xdmp:eval">{
    element database { $c:FORM-EVAL-DATABASE-ID },
    element root { $c:SERVER-APPLICATION-PATH },
    element modules { $c:SERVER-ROOT-DB }
  }</options>
let $vars := (xs:QName('URI'), $URI, xs:QName('PROPERTIES'), $PROPERTIES)
let $result := xdmp:invoke('view-invokable.xqy', $vars, $options)
(: Allow the browser to handle binary documents.
 : It would be nice to use the same mechanism as eval.xqy,
 : but eval.xqy must handle much more complex result sequences.
 : Here, the result is always a document, so the code is simpler.
 :)
let $mimetype :=
  if ($result/node() instance of binary()) then ()
  else if ($result/node() instance of text()) then 'text/plain'
  else 'text/xml'
let $set :=
  if ($mimetype) then xdmp:set-response-content-type($mimetype) else ()
return $result

(: view.xqy :)