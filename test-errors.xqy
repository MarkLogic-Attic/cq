xquery version "0.9-ml"
(:
 : cq: cq-test-errors.xqy
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
 : arguments:
 :   cq:query: the query to evaluate
 :   cq:mime-type: the mime type with which to return results
 :   cq:database: the database under which to evaluate the query
 :)

import module namespace v = "com.marklogic.developer.cq.view"
 at "lib-view.xqy"

xdmp:set-response-content-type("text/html; charset=utf-8"),
<html>
  <head/>
  <body>
{
for $e in (
  <err:error
   xsi:schemaLocation="http://marklogic.com/xdmp/error error.xsd"
   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
   xmlns:err="http://marklogic.com/xdmp/error">
  <err:code>XDMP-DOCUTF8SEQ</err:code>
  <err:message>Invalid UTF-8 escape sequence</err:message>
  <err:format-string>XDMP-DOCUTF8SEQ: Invalid UTF-8 escape sequence at http://news.google.com/ line 91 - document is not UTF-8 encoded</err:format-string>
  <err:retryable>false</err:retryable>
  <err:expr/>
  <err:data>
    <err:datum>http://news.google.com/</err:datum>
    <err:datum>91</err:datum>
  </err:data>
  <err:stack>
    <err:frame>
      <err:line>22</err:line>
    </err:frame>
  </err:stack>
  </err:error>
  ,
  <err:error
   xsi:schemaLocation="http://marklogic.com/xdmp/error error.xsd"
   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
   xmlns:err="http://marklogic.com/xdmp/error">
  <err:code>XDMP-UNEXPECTED</err:code>
  <err:message>Unexpected token</err:message>
  <err:format-string>XDMP-UNEXPECTED: Unexpected token QName_, expecting Comma_ or Rpar_</err:format-string>
  <err:retryable>false</err:retryable>
  <err:expr/>
  <err:data>
    <err:datum>QName_, expecting Comma_ or Rpar_</err:datum>
  </err:data>
  <err:stack>
    <err:frame>
      <err:line>10</err:line>
    </err:frame>
  </err:stack>
  </err:error>
  ,
  <err:error
   xsi:schemaLocation="http://marklogic.com/xdmp/error error.xsd"
   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
   xmlns:err="http://marklogic.com/xdmp/error">
  <err:code>XDMP-MANYITEMSEQ</err:code>
  <err:message>Sequence containing more than one item</err:message>
  <err:format-string>XDMP-MANYITEMSEQ: ("http:", "") eq "http:" - Sequence containing more than one item</err:format-string>
  <err:retryable>false</err:retryable>
  <err:expr>("http:", "") eq "http:"</err:expr>
  <err:data/>
  <err:stack>
    <err:frame>
      <err:line>13</err:line>
      <err:operation>fn:document-get("http://news.google.com/", ())</err:operation>
      <err:variables>
    <err:variable>
      <err:name xmlns="">uri</err:name>
      <err:value>"http://news.google.com/"</err:value>
    </err:variable>
    <err:variable>
      <err:name xmlns="">options</err:name>
      <err:value>()</err:value>
    </err:variable>
      </err:variables>
      <err:context-item>"http:"</err:context-item>
      <err:context-position>1</err:context-position>
    </err:frame>
    <err:frame>
      <err:line>22</err:line>
    </err:frame>
  </err:stack>
</err:error>
)
return element div {
  v:get-error-html($e),
  element hr {}
}
}
</body>
</html>

(: cq-test-errors.xqy :)
