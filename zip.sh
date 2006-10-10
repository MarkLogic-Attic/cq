#!/bin/sh
#
set -x

CQDIRNAME=`dirname $0`
DIRNAME=`pwd`/$CQDIRNAME/..
(
 cd $DIRNAME \
 && pwd \
 && rm -f cq.zip \
 && zip -9 cq.zip \
   */[a-su-z]*.xqy \
   */*.xml \
   */*.js \
   */cq.css \
   */?arr.gif \
   */*.txt \
   */*.html 
)

# end
