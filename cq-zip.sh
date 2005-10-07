#!/bin/sh
#
set -x

DIRNAME=`dirname $0`
DIRNAME=`pwd`/$DIRNAME/..
(
 cd $DIRNAME \
 && pwd \
 && rm -f cq.zip \
 && zip -9 cq.zip \
   cq/cq.xqy cq/cq-[eq]*.xqy cq/cq.js cq/cq.css \
   cq/?arr.gif worksheet.xml \
   cq/index.html cq/lib-*.xqy cq/cq-result.html cq/*.txt
)

# end