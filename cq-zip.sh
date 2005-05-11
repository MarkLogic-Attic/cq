#!/bin/sh
#
set -x
(
 cd $0/../.. \
 && pwd \
 && rm -f cq.zip \
 && zip -9 cq.zip \
   cq/cq.xqy cq/cq-[eq]*.xqy cq/cq.js cq/cq.css \
   cq/index.html cq/lib-view.xqy cq/cq-result.html cq/*.txt
)

# end