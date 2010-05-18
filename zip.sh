#!/bin/sh
#
#set -x
set -e

CQDIRNAME=`dirname $0`
DIRNAME=`pwd`/$CQDIRNAME/..

cd $DIRNAME
pwd

DATE=`date +%Y%m%d`
ZIP=$DIRNAME/cq-gh-pages/mark-logic-cq-`cat cq/VERSION.xml | awk -F\< '{ print $2 }' | awk -F\> '{ print $2 }'`.zip
echo building $ZIP

rm -f $ZIP
chmod a+rwx cq/sessions

# NB omit test xqy
# NB non-recursive add of sessions dir
FILES=`echo cq/[a-su-z]*.xqy \
  cq/*.xml \
  cq/*.js \
  cq/js/*.js \
  cq/js/COPYING-PersistJS \
  cq/*.css \
  cq/*.gif \
  cq/*.ico \
  cq/*.txt \
  cq/*.html \
  cq/sessions`
zip -9 $ZIP $FILES

rsync -vazP $ZIP ssh.marklogic.com:public_html/

URL=http://corp1/~michael/`basename $ZIP`

ssh ssh.marklogic.com HEAD $URL

echo $URL ok
echo

# end
