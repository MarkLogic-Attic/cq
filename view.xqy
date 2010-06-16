xquery version "1.0-ml";
(:
 : Content Query Tool (cq)
 :
 : Copyright (c) 2002-2010 Mark Logic Corporation. All Rights Reserved.
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

import module namespace v = "com.marklogic.developer.cq.view"
 at "lib-view.xqy";

declare option xdmp:mapping "false";

declare variable $PROPERTIES as xs:boolean :=
  xs:boolean(xdmp:get-request-field('properties', '0'))
;

declare variable $URI as xs:string :=
  xdmp:get-request-field('uri')
;

declare variable $USE-XSL as xs:boolean := xs:boolean(
  xdmp:get-request-field('xsl', '0')
);

declare variable $RESULT := xdmp:invoke(
  'view-invokable.xqy',
  (xs:QName('URI'), $URI, xs:QName('PROPERTIES'), $PROPERTIES),
  <options xmlns="xdmp:eval">{
    element database { $c:FORM-EVAL-DATABASE-ID },
    element root { $c:SERVER-APPLICATION-PATH },
    element modules { $c:SERVER-ROOT-DB }
  }</options>
)/node()
;

(: Allow the browser to handle binary documents.
 : It would be nice to use the same mechanism as eval.xqy,
 : but eval.xqy must handle much more complex result sequences.
 : Here, the result is always a document, so the code is simpler.
 :)
declare variable $MIMETYPE := (
  typeswitch ($RESULT)
  case binary() return ()
  case text() return 'text/plain'
  default return 'text/xml'
);

if ($MIMETYPE) then xdmp:set-response-content-type($MIMETYPE)
else ()
,
if ($USE-XSL and $MIMETYPE eq 'text/xml') then $v:XML-TREE-PI
else ()
,
$RESULT

(: view.xqy :)