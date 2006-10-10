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
   cq/[a-su-z]*.xqy \
   cq/*.xml \
   cq/*.js \
   cq/cq.css \
   cq/?arr.gif \
   cq/*.txt \
   cq/*.html \
   cq/sessions
)

# end
