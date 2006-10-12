CQ is a web-based query executing form useful for writing ad hoc queries
without using .xqy files.  CQ has JavaScript hooks that make it practically an
IDE.  You can view the results as XHTML, XML, or plain text output.  CQ is
designed for use with MarkLogic Server HTTP Server applications,
using Mozilla 1.0+ or Internet Explorer 6+. Other modern browsers may also 
work, but have not been tested.

To install CQ, copy the files from the downloaded zip under a directory
served by MarkLogic Server.  You run CQ by making a web request to
the directory.  For example, by placing the files under the C:\Program
Files\MarkLogic\Docs\cq directory, you can run CQ as
http://localhost:8000/cq/.  Please be very careful in exposing CQ on a
production site, as it allows queries to be written by remote clients.

The CQ version number corresponds to the version number of MarkLogic
Server against which it's optimized.  This release requires MarkLogic Server 
3.0-1 or later.

The CQ source code is included in the download, licensed under the open source
Apache 2.0 license.  You'll also find the source code checked into the xq:zone
subversion repository.  If you make improvements you're welcome to contribute
them back.  That way they'll appear in subsequent releases.

Enjoy!

