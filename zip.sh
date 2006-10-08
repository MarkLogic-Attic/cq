#!/bin/sh
#
set -x

DIRNAME=`dirname $0`
DIRNAME=`pwd`/$DIRNAME/..
(
 cd $DIRNAME \
 && pwd \
 && rm -f releases/cq.zip \
 && zip -9 releases/cq.zip \
   cq/[^t]*.xqy \
   cq/[^t]*.js cq/[^t]*.css \
   cq/[^t]?arr.gif cq/[^t]*.txt \
   cq/worksheet.xml cq/cq-result.html 
)

# end
