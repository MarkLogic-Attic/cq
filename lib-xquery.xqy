xquery version "0.9-ml"
(:
 : cq: lib-xquery.xqy
 :
 : Copyright (c)2008 Mark Logic Corporation. All Rights Reserved.
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
 : This library contains things that should be in XQuery in the first place.
 :
 :)
module "com.marklogic.developer.cq.xquery"

default function namespace = "http://www.w3.org/2003/05/xpath-functions"

declare namespace x = "com.marklogic.developer.cq.xquery"

define variable $x:NBSP as xs:string { codepoints-to-string(160) }

define variable $x:NL as xs:string { codepoints-to-string(10) }

(:~ for 1.0-ml modules - why did the committee remove useful functions? :)
define function x:string-pad(
  $padString as xs:string?,
  $padCount as xs:integer)
 as xs:string?
{
  (: for 1.0-ml modules - why did the committee remove useful functions? :)
  string-pad($padString, $padCount)
}

define function x:cumulative-seconds-from-duration($d as xdt:dayTimeDuration)
 as xs:double
{
  86400 * days-from-duration($d)
  + 3600 * hours-from-duration($d)
  + 60 * minutes-from-duration($d)
  + seconds-from-duration($d)
}

(:~ get the epoch seconds :)
define function x:get-epoch-seconds($dt as xs:dateTime)
  as xs:unsignedLong
{
  xs:unsignedLong(x:cumulative-seconds-from-duration(
    $dt - xs:dateTime('1970-01-01T00:00:00Z')))
}

(:~ get the epoch seconds :)
define function x:get-epoch-seconds()
  as xs:unsignedLong
{
  x:get-epoch-seconds(current-dateTime())
}

(:~ convert epoch seconds to dateTime :)
define function x:epoch-seconds-to-dateTime($v)
  as xs:dateTime
{
  xs:dateTime("1970-01-01T00:00:00-00:00")
  + xdt:dayTimeDuration(concat("PT", $v, "S"))
}

define function x:duration-to-microseconds($d as xs:dayTimeDuration)
 as xs:unsignedLong {
   xs:unsignedLong(
     1000 * 1000 * x:cumulative-seconds-from-duration($d)
   )
}

define function x:lead-nbsp($v as xs:string, $len as xs:integer)
 as xs:string {
  x:lead-string($v, $x:NBSP, $len)
}

define function x:lead-space($v as xs:string, $len as xs:integer)
 as xs:string {
  x:lead-string($v, ' ', $len)
}

define function x:lead-zero($v as xs:string, $len as xs:integer)
 as xs:string {
  x:lead-string($v, '0', $len)
}

define function x:lead-string(
  $v as xs:string, $pad as xs:string, $len as xs:integer)
 as xs:string {
  concat(x:string-pad($pad, $len - string-length(string($v))), string($v))
}

(: lib-xquery.xqy :)
