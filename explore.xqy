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
 : TODO paginate?
 : TODO use cts:uris(), if available? interferes with element-display...
 :
 :)

import module namespace admin = "http://marklogic.com/xdmp/admin"
  at "/MarkLogic/admin.xqy";

import module namespace c = "com.marklogic.developer.cq.controller"
 at "lib-controller.xqy";

import module namespace v = "com.marklogic.developer.cq.view"
  at "lib-view.xqy";

import module namespace x = "com.marklogic.developer.cq.xquery"
 at "lib-xquery.xqy";

declare variable $OPTIONS as element() :=
  <options xmlns="xdmp:eval">
  {
    element database { $c:FORM-EVAL-DATABASE-ID }
  }
  </options>
;

declare variable $HAS-URI-LEXICON as xs:boolean :=
  admin:database-get-uri-lexicon($c:ADMIN-CONFIG, $c:FORM-EVAL-DATABASE-ID)
;

declare variable $QUERY as xs:string :=
  (: uri lexicon does not do much good here,
   : since we want to pull the root node info too.
   :)
  'xquery version "1.0-ml";
   declare variable $LIMIT as xs:integer external;
   xdmp:estimate(doc()),
   doc()[1 to $LIMIT]
  '
;

c:set-content-type(),

let $limit := 5000
let $result := xdmp:eval($QUERY, (xs:QName('LIMIT'), $limit), $OPTIONS)
let $est := $result[1]
let $database-name := xdmp:database-name($c:FORM-EVAL-DATABASE-ID)
return <html xmlns="http://www.w3.org/1999/xhtml">{
  element head { v:get-html-head() },
  element body {
    element p {
      attribute class { 'head2' },
      'Database ', element b { $database-name }, ' contains ',
      if ($est gt $limit)
      then text {
        'too many documents to display!',
        'First', $limit, 'documents of', $est, 'total:'
      }
      else text { $est, 'documents total:' }
    },
    for $i in subsequence($result, 2)
    let $uri := xdmp:node-uri($i)
    let $n := ($i/*[1], $i/(binary()|element()|text())[1])[1]
    where exists($n)
    order by $uri
    return (
      element a {
        attribute href { c:build-form-eval-query('view.xqy', 'uri', $uri) },
        $uri
      },
      <span> - </span>,
      <i>{ x:node-kind($n) }</i>,
      (: why not node-name? because this is a human-readable context :)
      <code>&#160;{ name($n) }</code>,
      <br/>
    )
  }
}</html>

(: explore.xqy :)