xquery version "1.0-ml";
(:
 : cq: lib-debug.xqy
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
module namespace d = "com.marklogic.developer.cq.debug";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare variable $d:NL := codepoints-to-string(10);

declare variable $d:DEBUG as xs:boolean := false();

declare variable $d:DEBUG-FIELD as xs:string := "debug";

declare function d:get-debug()
 as xs:boolean
{
  $d:DEBUG
};

declare function d:debug-on()
 as empty-sequence()
{
  xdmp:set($d:DEBUG, true()),
  d:debug("debug is on")
};

declare function d:debug-off()
 as empty-sequence()
{
  xdmp:set($d:DEBUG, false())
};

declare function d:debug($s as item()*)
 as empty-sequence()
{
  if (not($d:DEBUG)) then () else xdmp:log(
    string-join(("DEBUG:", translate(xdmp:quote($s), $d:NL, " ")), " ")
  )
};

declare function d:check-debug()
 as empty-sequence()
{
  if (xs:boolean(xdmp:get-request-field($d:DEBUG-FIELD, string($d:DEBUG))[1]))
  then d:debug-on()
  else ()
};

declare function d:whereami()
{
  xdmp:log(text{'whereami:', try {
     error(xs:QName('DEBUG-WHEREAMI'), 'fake error for d:whereami')
   } catch ($ex) {
     for $op in $ex/error:stack/error:frame/error:operation
     return substring-before($op, '(')
   }
 })
};

(: lib-debug.xqy :)
