CQ is a web-based query executing form useful for writing ad hoc queries
without using .xqy files.  XQ has JavaScript hooks that make it practically an
IDE.  You can view the results as XHTML, XML, or plain text output.  CQ is
designed for use with Content Interaction Server HTTP Server applications,
using Internet Explorer 5.5+ or most other modern browsers.

To install CQ just copy the files from the downloaded zip under a directory
served by Content Interaction Server.  You run CQ by making a web request to
the directory.  For example, by placing the files under the C:\Program
Files\Mark Logic CIS\Docs\cq directory, you can run CQ as
http://localhost:8000/cq/.  Just please be very careful in exposing CQ on a
production site as it allows queries to be written by remote clients.

The CQ version number corresponds to the version number of Content Interaction
Server against which it's optimized.  For example, CQ 2.1.x is designed to
work against Content Interaction Server 2.1-x.  CQ 2.2.x may take advantage of
Content Interaction server 2.2-x specific features.

The CQ source code is included in the download, licensed under the open source
Apache 2.0 license.  You'll also find the source code checked into the xq:zone
subversion repository.  If you make improvements you're welcome to contribute
them back.  That way they'll appear in subsequent releases.

Enjoy!

