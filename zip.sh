#!/bin/sh
#
#set -x
set -e

CQDIRNAME=`dirname $0`
DIRNAME=`pwd`/$CQDIRNAME/..

cd $DIRNAME
pwd

DATE=`date +%Y%m%d`
ZIP=$DIRNAME/releases/mark-logic-cq-`cat cq/VERSION.txt`.zip
echo building $ZIP

rm -f $ZIP
chmod a+rwx cq/sessions

# NB omit test xqy
# NB non-recursive add of sessions dir
zip -9 $ZIP \
  cq/[a-su-z]*.xqy \
  cq/*.xml \
  cq/*.js \
  cq/js/*.js \
  cq/*.css \
  cq/*.gif \
  cq/*.ico \
  cq/*.txt \
  cq/*.html \
  cq/sessions

rsync -vazP $ZIP ssh.marklogic.com:public_html/

URL=http://corp1/~michael/`basename $ZIP`

ssh ssh.marklogic.com HEAD $URL

echo $URL ok
echo

# end
