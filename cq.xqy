(: cq.xqy :)

<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>{
  "cq - Mark Logic",
  xdmp:product-initials(), xdmp:version(),
  "for", xdmp:platform(),
  "on", xdmp:get-request-header("Host")
    }</title>
    <link rel="stylesheet" type="text/css" href="style/default3.css"/>
  </head>
  <frameset rows="500,*">
    <frame src="cq-query.xqy" name="cq_queryFrame" id="cq_queryFrame"/>
    <frame src="cq-result.html" name="cq_resultFrame" id="cq_resultFrame"/>
  <noframes>
          <p>Apparently your browser does not support frames.
            Try using this <a href="cq-query.html">link</a>.
          </p>
  </noframes>
  </frameset>
</html>

(: cq.xqy :)