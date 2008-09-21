xquery version "1.0-ml";
(:
 : eval.xqy
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
 : arguments:
 :   query, the query to evaluate
 :   mime-type, the mime type with which to return results
 :   eval, the database under which to evaluate the query
 :)

import module namespace admin = "http://marklogic.com/xdmp/admin"
  at "/MarkLogic/admin.xqy";

import module namespace c = "com.marklogic.developer.cq.controller"
 at "lib-controller.xqy";

import module namespace d = "com.marklogic.developer.cq.debug"
 at "lib-debug.xqy";

import module namespace v = "com.marklogic.developer.cq.view"
 at "lib-view.xqy";

declare variable $QUERY as xs:string := xdmp:get-request-field("query", "");

declare variable $DATABASE-ID as xs:unsignedLong := $c:FORM-EVAL-DATABASE-ID ;

declare variable $SERVER-ID as xs:unsignedLong := $c:FORM-EVAL-SERVER-ID ;

declare variable $MODULES-ID as xs:unsignedLong :=
  admin:appserver-get-modules-database($c:ADMIN-CONFIG, $SERVER-ID)
;

declare variable $XQUERY-VERSION as xs:string :=
  admin:appserver-get-default-xquery-version($c:ADMIN-CONFIG, $SERVER-ID)
;

declare variable $MODULES-ROOT as xs:string :=
  admin:appserver-get-root($c:ADMIN-CONFIG, $SERVER-ID)
;

declare variable $MIMETYPE as xs:string :=
  xdmp:get-request-field("mime-type", "text/plain")
;

declare variable $PROFILING as xs:boolean :=
  $MIMETYPE eq 'application/x-com.marklogic.developer.cq.profiling'
;

declare variable $OPTIONS as element() :=
  <options xmlns="xdmp:eval">
  {
    (: TODO add collation, when options supports it - 4023 :)
    element database { $DATABASE-ID },
    element modules { $MODULES-ID },
    element default-xquery-version { $XQUERY-VERSION },
    (: we should always have a root path, but better safe than sorry :)
    if ($MODULES-ROOT) then element root { $MODULES-ROOT }
    else (),
    element isolation { "different-transaction" },
    if (fn:starts-with (xdmp:version(), "4"))
      then element default-xquery-version { "app-server" }
      else ()
  }
  </options>
;

d:check-debug(),
d:debug(("eval:", $MIMETYPE)),
d:debug(("eval:", $c:FORM-EVAL)),
d:debug(("eval:", $c:DATABASE-ID, $MODULES-ID, $MODULES-ROOT, $QUERY)),
try {
  (: set the mime-type inside the try-catch block,
   : so errors can override it.
   :)
  let $x as item()* :=
    if (not($PROFILING)) then xdmp:eval($QUERY, (), $OPTIONS)
    else if ($c:PROFILING-ALLOWED) then prof:eval($QUERY, (), $OPTIONS)
    else <p class="head1 error">
      Profiling is disabled for the application server
      <b>{ $c:SERVER-NAME }</b>.
      You may enable profiling in the admin server.
    </p>
  let $d := d:debug(("eval:", $x))
  (: Sometimes we override the user's request,
   : and display the results as text/plain instead
   :
   : Problem: sometimes IE6 insists on using a helper app for text/plain.
   : The 'Content-Disposition: inline' header trick does not fix this.
   : So can we use html and pre instead? Not for binary....
   : Note that there's a registry fix: isTextPlainHonored.
   : http://support.microsoft.com/default.aspx?scid=kb;EN-US;q239750
   :
   : It is dangerous to view a sequence of attributes as xml: XDMP-DUPATTR.
   : Binaries should not be viewed as html or text.
   :)
  let $mimetype :=
    if (empty($x)) then "text/html"
    (: try to autosense profiler output :)
    else if ($PROFILING) then "text/html"
    (: for binaries, let the browser autosense the mime-type :)
    else if ($x instance of node()+
      and exists((
        $x[ . instance of binary()+ or . instance of document-node()+ ]
        /(self::binary()|child::binary())
      )) ) then ()
    else if (($x instance of attribute()+ and count($x) gt 1)
      or (count($x) eq 1 and $x instance of document-node()+
        and empty($x/node()))
    )
    then "text/plain"
    else $MIMETYPE
  let $set :=
    if (exists($mimetype))
    then xdmp:set-response-content-type(
      string-join(($mimetype, 'charset=utf-8'), '; '))
    else ()
  let $set :=
    if (empty($mimetype) or $mimetype ne "text/plain") then () else
    (: does this fix the IE6 text/plain helper-app issue? cf Q239750 :)
    xdmp:add-response-header('Content-Disposition', 'inline; filename=cq.txt')
  return
    if ($mimetype eq "text/xml") then v:get-xml($x)
    else if ($mimetype eq "text/html") then v:get-html($x)
    else v:get-text($x)
} catch ($ex) {
  (: errors are always displayed as html :)
  xdmp:set-response-content-type("text/html; charset=utf-8"),
  v:get-error-html($DATABASE-ID, $MODULES-ID, $MODULES-ROOT, $ex, $QUERY)
}

(: eval.xqy :)
