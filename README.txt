CQ is a web-based query executing form useful for writing ad-hoc queries
without using .xqy files. CQ has JavaScript hooks that make it practically an
IDE. You can view the results as XHTML, XML, or plain-text output. CQ is
designed for use with a MarkLogic Server HTTPServer instance
and a modern web browser with JavaScript support and XML display.

To install CQ, copy the files from the downloaded zip under a directory
served by MarkLogic Server. You run CQ by making a web request to
the directory. For example, by placing the files under the C:\Program
Files\MarkLogic\Docs\cq directory, you can run CQ as
http://localhost:8000/cq/. Please be very careful in exposing CQ on a
production site, as it allows queries to be written by remote clients.

This release of CQ requires MarkLogic Server 4.0-1 or later.

CQ is developed using Mozilla Firefox 3.0, and periodically tested
using MS Internet Explorer 6. Other browsers are not tested, and may not work,
but patches are welcome.

The CQ source code is included in the download, licensed under the open source
Apache 2.0 license. You will also find the source code checked into the
developer.marklogic.com subversion repository. If you make improvements,
you are welcome to contribute them back to the project.

This application uses code from Prototype.js and script.aculo.us. See
See js/prototype.js, js/effects.js, and js/controls.js
for copyright and license information.

This application uses code, styles, and images from the TableKit demo.
See js/tablekit.js for copyright and license information.

This application uses a modified version of Kazuki Ohta's resizable.js.
See js/resizable.js for copyright and license information.

Enjoy!

