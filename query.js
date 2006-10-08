// Copyright (c) 2003-2006 Mark Logic Corporation. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// The use of the Apache License does not indicate that this project is
// affiliated with the Apache Software Foundation.
//
//////////////////////////////////////////////////////////////////////

// TODO better eval-in handling

// TODO refactor more of this controller-style logic into classes:
// QueryTabsClass, etc.

// TODO test for IE6 compatibility
// TODO test for memory leaks

// GLOBAL CONSTANTS: but IE6 doesn't support "const"
var gFramesetId = "/cq:frameset";
var gQueryFrameId = "/cq:queryFrame";
var gResultFrameId = "/cq:resultFrame";
var gQueryInput = "/cq:query";
var gUri = "/cq:worksheet-uri";
var gQueryFormId = "/cq:form";
var gQueryMimeType = "/cq:mime-type";
var gBufferAccesskeyText = "/cq:buffer-accesskey-text";
var gBufferTabsNode = "/cq:buffer-tabs";
// is there some *optional* linebreak character we could use?
// yes: http://www.quirksmode.org/oddsandends/wbr.html
// but I don't want to muck with the wbr element in a string...
// solution: "&shy;" (#173, 0xAD) seems to work for IE and gecko
// another candiate is #8203 (0x200b), but it isn't as nice.
// not perfect, but seems to be ok...
var gBreakChar = "\u00ad"; //"\u200b";

// GLOBAL VARIABLES
var gBufferTabsCurrent = null;
var gBrowserIs = new BrowserIsClass();
var gBuffers = null;
var gHistory = null;
var gSession = null;

// static functions
// useful string functions
function trim(s) { return s == null ? null : s.replace(/^\s+|\s+$/g, ""); }

// normalize-space, in JavaScript
function normalizeSpace(s) { return trim(s.replace(/[\n\t\s]+/g, ' ')); }

// create some whitespace, for line breaking in the buffer labels
function nudge(s) {
    s = s.replace("/(/g", "(" + gBreakChar);
    s = s.replace("/)/g", gBreakChar + ")");
    s = s.replace("/,/g", "," + gBreakChar);
    s = s.replace("/=/g", gBreakChar + "=" + gBreakChar);
    return normalizeSpace(s);
}

function escapeXml(s) {
    s = s.replace(/\&/g, "&amp;");
    s = s.replace(/\</g, "&lt;");
    s = s.replace(/\>/g, "&gt;");
    return s;
}

// Given a textarea node,
// tries to make it gecko-compatible.
// Returns a boolean if successful.
function simulateSelectionStart(n) {
    var label = "simulateSelectionStart: ";
    debug.print(label + "buf = " + n);
    if (null == n) {
        debug.print(label + "null buf!");
        return false;
    }
    if (n.style.display == 'none') {
        debug.print(label + "hidden buf");
        return false;
    }

    // must handle this differently for gecko vs IE6
    // must test non-gecko first, since this code will persist
    // it's a little tricky to tell the difference between IE6 and opera,
    // but I'd rather avoid calling gBrowserIs.opera()
    if (!window.getSelection && !document.getSelection
        && document.selection && document.selection.createRange) {
        debug.print(label + "document.selection ok");
        // set it up, using IE5+ API
        // http://msdn.microsoft.com/workshop/author/dhtml/reference
        //   /objects/obj_textrange.asp
        // first, make sure we have the focus
        debug.print(label + "focus on " + n);
        n.focus();
        var range = document.selection.createRange();
        debug.print(label + "range = " + range);
        var storedRange = range.duplicate();
        storedRange.moveToElementText(n);
        storedRange.setEndPoint('EndToEnd', range);
        debug.print(label + "storedRange.text = '"
                    + storedRange.text + "'"
                    + " (" + storedRange.text.length
                    + "," + range.text.length
                    + "," + n.value.length
                    + ")");
        // set start and end points, ala gecko
        n.selectionStart = (storedRange.text.length
                                     - range.text.length);
        // now we can pretend that IE6 is gecko
        return true;
    }

    if (n.selectionStart) {
        // looks like gecko: selectionStart should work
        debug.print(label + "found " + n.selectionStart);
        return true;
    }

    // unsupported, or at the start of buffer: either way, pretend 0
    debug.print(label + "no selection information: setting 0");
    n.selectionStart = 0;
    return true;
}

// Given a node and a new caret position, set it.
function setSelectionStart(n, start) {
    var label = "setSelectionStart: ";
    if (document.selection) {
        debug.print(label + "document.selection, cannot set selectionStart");
        // TODO use IE5+ API
        // http://msdn.microsoft.com/workshop/author/dhtml/reference
        //   /objects/obj_selection.asp
        // http://msdn.microsoft.com/workshop/author/dhtml/reference
        //   /objects/obj_textrange.asp
        //var range = document.selection.createRange();
        //var storedRange = range.duplicate();
        //storedRange.moveToElementText(n);
        //storedRange.setEndPoint('EndToEnd', range);
        //n.selectionStart =
        //  storedRange.text.length - range.text.length;
        return;
    }

    // gecko
    debug.print(label + "gecko, restoring " + start);
    n.selectionStart = start;
    n.selectionEnd = start;
}

// classes
function BrowserIsClass() {
    // convert all characters to lowercase to simplify testing
    var agt = navigator.userAgent.toLowerCase();

    this.major = parseInt(navigator.appVersion);
    this.minor = parseFloat(navigator.appVersion);

    this.nav  = ((agt.indexOf('mozilla') != -1)
                 && ((agt.indexOf('spoofer') == -1)
                     &&  (agt.indexOf('compatible') == -1)));

    this.gecko = (this.nav
                  && (agt.indexOf('gecko') != -1));

    this.ie   = (agt.indexOf("msie") != -1);

    // don't use these unless we must
    this.x11 = (agt.indexOf("x11") != -1);
    this.mac = (agt.indexOf("macintosh") != -1);
    this.win = (agt.indexOf("windows") != -1);
}

// The history will act something like a stack,
// and something like an array.
// This requires a two-fold structure:
//   - hash: a Hash with normalized-query as key, li element as value
//   - listNode: an ol element with li children
// The hash provides de-duplication of queries,
// while the listNode acts like a fixed-size stack.
function QueryHistoryClass(id, buffers, size) {
    // init history list node
    this.node = $(id);
    this.size = size ? size : 50;
    this.buffers = buffers;
    debug.print("QueryHistoryClass.init: node = " + this.node
                + ", buffers = " + buffers);

    this.listNode = document.createElement("ol");
    this.hash = $H();
    this.lastModified = new Date();

    this.add = function(query) {
        //debug.print("QueryHistoryClass.add: " + query);
        if (query == null || query == "") {
            return;
        }

        // the whitespace-normalized query acts as the hash key
        var key = normalizeSpace(query);
        if (key == null || key == "") {
            return;
        }

        //debug.print("QueryHistoryClass.add: " + ": " + key);

        // lazy initialization
        if (null == this.listNode.parentNode) {
            // We haven't attached the listNode to the document yet:
            // remove any existing text and attach our listNode.
            Element.update(this.node, '');
            this.node.appendChild(this.listNode);
        }

        var listItem = this.hash[key];
        if (null != listItem) {
            // new query has a duplicate: replace the existing item.
            Element.remove(listItem);
        }
        // build a new listItem
        listItem = this.newListItem(key, query);

        // place the new listItem at the top of the listNode children
        if (this.listNode.hasChildNodes()) {
            this.listNode.insertBefore(listItem, this.listNode.firstChild);
        } else {
            debug.print("QueryHistoryClass.add: first entry");
            this.listNode.appendChild(listItem);
        }

        // update the hash
        this.hash[key] = listItem;
        this.lastModified = new Date();

        // check size limit, and truncate if needed
        var values = this.hash.values();
        if (values.length > this.size) {
            debug.print("QueryHistoryClass.add: truncating "
                        + values.length + " > " + this.size);
            for (i = this.size; i < values.length; i++) {
                debug.print("QueryHistoryClass.add: truncating " + i);
                this.remove(values[i]);
            }
        }
    }

    this.remove = function(key) {
        // remove this listItem and its corresponding hash entry
        var node = this.hash[key]
        // will this work? relying on garbage collection?
        this.hash[key] = null;
        Element.remove(node);
        this.lastModified = new Date();
    }

    this.setQuery = function(e) {
        // we don't know which query was clicked,
        // but we know that the click was on a span element
        var node = Event.findElement(e, "span");
        node.setAttribute("xml:space", "preserve");
        debug.print("QueryHistoryClass.setQuery: " + node);
        var query = node.firstChild.nodeValue;
        debug.print("QueryHistoryClass.setQuery: " + query);
        this.buffers.setQuery(query);
    }

    this.newListItem = function(key, query) {
        var newItem = document.createElement("li");
        var queryNode = document.createElement("span");
        queryNode.appendChild(document.createTextNode(query));
        // onclick, copy to current textarea
        // we need to both bind(query) and bindAsEventListener(this.buffers)
        Event.observe(queryNode, "click",
                      this.setQuery.bindAsEventListener(this));

        // tool-tip
        queryNode.title = "Click to copy this into the active buffer.";
        newItem.appendChild(queryNode);

        // delete widget
        var deleteLink = document.createElement("span");
        newItem.appendChild(deleteLink);
        deleteLink.className = "query-delete";
        Event.observe(deleteLink, "click",
                      function() {
            if (confirm("Are you sure you want to delete this query?")) {
                this.remove(key);
            }
        }.bindAsEventListener(this)
                      );
        deleteLink.title = "Click to delete this query from your history.";
        deleteLink.appendChild(document.createTextNode(" (x) "));

        // spacing: css padding, margin don't seem to work with ol
        newItem.appendChild(document.createElement("hr"));

        return newItem;
    }

    this.show = function() {
        Element.show(this.node);
    }

    this.hide = function() {
        Element.hide(this.node);
    }

    this.toXml = function() {
        var parentName = "query-history";
        var queryName = "query";

        var xml = "<" + parentName + ">\n";

        // values() yields an unstable order,
        // so we use listNode.childNodes instead.
        var nodes = this.listNode.childNodes;
        var query = null;
        for (var i = 0; i < nodes.length; i++) {
            // XPath would be data($query/span/text())
            query = nodes[i].firstChild.textContent;
            if (null != query && "" != query) {
                // I'm tempted to wrap each query in a CDATA,
                // but the query might use CDATA sections too.
                xml += "<" + queryName + ">"
                    + escapeXml(query)
                    + "</" + queryName + ">\n";
            }
        }

        xml += "</" + parentName + ">\n";
        //debug.print("QueryHistory.toXml: " + xml);

        return xml;
    }

} // QueryHistoryClass

// this class maintains the contents and context of a query buffer
function QueryBufferClass(query, selectionStart, contentSource) {
    this.query = query;
    // start at the end
    this.selectionStart = (null == selectionStart)
        ? selectionStart : textArea.length;
    // also track the contentbase and app-server
    this.contentSource = contentSource;

    this.getQuery = function() {
        return this.query;
    }

    this.setQuery = function(query) {
        this.query = query;
    }

    this.getSelectionStart = function() {
        return this.selectionStart;
    }

    this.setSelectionStart = function(start) {
        this.selectionStart = start;
    }

    this.getContentSource = function() {
        return this.contentSource;
    }

    this.setContentSource = function(v) {
        this.contentSource = v;
    }

    this.toXml = function() {
        var name = "query";
        return "<" + name + ">" + escapeXml(this.query) + "</" + name + ">\n";
    }

} // QueryBufferClass

function QueryBufferListClass(inputId, evalId, labelsId, statusId, size) {
    // This is a fixed-size list of query buffers.
    this.buffers = new Array();
    // The input node will be the textarea of the active query
    this.input = $(inputId);
    // ...track the index of the active query
    this.pos = 0;
    // ...manage the content-source as well
    this.eval = $(evalId);
    // ...and a list of query labels
    this.labelList = $(labelsId);
    // ...and the caret line-column status
    this.lineStatus = $(statusId);

    // Create a wrapper for the labels: table layout.
    // This tbody is needed by gecko, and doesn't hurt IE6
    this.labelsBody = document.createElement('tbody');
    this.labelList.appendChild(this.labelsBody);

    this.initHandlers = function() {
        // set up handlers to update line-number display
        Event.observe(this.input, "focus",
                      this.setLineNumberStatus.bindAsEventListener(this));
        Event.observe(this.input, "click",
                      this.setLineNumberStatus.bindAsEventListener(this));
        Event.observe(this.input, "keyup",
                      this.setLineNumberStatus.bindAsEventListener(this));
    }

    this.add = function(query) {
        var n = this.buffers.length;
        this.buffers[n] = new QueryBufferClass(query);
        var active = false;
        if (n == this.pos) {
            // lazy init
            this.input.value = query;
            active = true;
        }
        this.setLabel(n, active);
    }

    this.setLabel = function(n, active) {
        debug.print("QueryBufferListClass.setLabel: " + n + ", " + active);
        n = (null == n) ? this.pos : n;
        active = active || false;

        var label = this.getLabel(n);

        // update the active status
        var theNum = null;
        if (active) {
            // show the current index in bold, with no link
            theNum = document.createElement('b');
            // use highlighting
            label.className = 'bufferlabelactive';
            // deactivate any onclick
            label.onclick = null;
            // set tooltip
            label.title = null;
        } else {
            // provide a link to load the buffer
            theNum = document.createElement('a');
            theNum.setAttribute('href', '#');
            // inactive class
            label.className = 'bufferlabel';
            // make the whole node active
            Event.observe(label, "click",
                          function() { this.activate(n) }
                          .bindAsEventListener(this));
            // set tooltip
            label.title = "Click to activate this query buffer.";
        }

        theNum.appendChild(document.createTextNode("" + (1+n) + "."));
        label.appendChild(theNum);

        // Update the label text from the query
        // ...make sure it doesn't break for huge strings
        var query = this.getQuery(n).substr(0, 1024);
        // ...let the css handle text that's too large for the buffer
        // ...we shouldn't have to normalize spaces, but IE6 is broken
        // ...and so we have to hint word-breaks to both browsers.
        query = nudge(query);

        // put a nbsp here for formatting, so it won't be inside the link
        label.appendChild(document.createTextNode("\u00a0" + query));

        // TODO mouseover for fully formatted text contents as tooltip?
    }

    this.getLabel = function(n) {

        // it will be the n-th div below this.labelsBody
        var labels = this.labelsBody.getElementsByTagName('div');
        var label = labels[n];

        // if there isn't a label for n, create one
        if (null == label) {
            var row = document.createElement('tr');
            this.labelsBody.appendChild(row);
            var cell = document.createElement('td');
            row.appendChild(cell);
            label = document.createElement('div');
            cell.appendChild(label);
        } else {
            // destory any contents
            Element.update(label, '');
        }
        return label;
    }

    this.getBuffer = function(n) {
        if (null == n) {
            n = this.pos;
        }
        if (n < 0) {
            debug.print("QueryBufferListClass.getBuffer: negative index " + n);
            n = 0;
        }
        if (n >= this.buffers.length) {
            debug.print("QueryBufferListClass.getBuffer: overflow index " + n);
            n = this.buffers.length - 1;
        }

        return this.buffers[n]
    }

    this.getQuery = function(n) {
        //debug.print("QueryBufferListClass.getBufferValue: " + n);
        return this.getBuffer(n).getQuery();
    }

    this.resize = function(x, y) {
        debug.print("QueryBufferListClass.resize: " + x + "," + y);
        this.input.cols += x;
        this.input.rows += y;
    }

    this.activate = function(n) {
        label = "QueryBufferListClass.activate: ";
        debug.print(label + this.pos + " to " + n);

        var buf = this.getBuffer();

        if (null == n || this.pos == n) {
            // make sure our state is correct
            buf.setQuery(this.input.value);
            buf.setContentSource(this.eval.value);
            this.setLabel(this.pos, true);
            simulateSelectionStart(this.input);
            buf.setSelectionStart(this.input.selectionStart);
            return;
        }

        // save any state from the current buffer, and deactivate it.
        if (null != buf) {
            buf.setQuery(this.input.value);
            buf.setContentSource(this.eval.value);
            this.setLabel(this.pos, false);
            simulateSelectionStart(this.input);
            buf.setSelectionStart(this.input.selectionStart);
        }

        // activate the new buffer and restore its state
        this.pos = n;
        buf = this.getBuffer();
        this.input.value = buf.getQuery();
        this.setContentSource(buf.getContentSource());
        this.setLabel(this.pos, true);
        setSelectionStart(this.input, buf.getSelectionStart());
    }

    this.setQuery = function(query) {
        this.input.value = query;
        this.getBuffer().setQuery(query);
    }

    this.setContentSource = function(v) {
        // TODO set the content source using this.eval
        this.eval.value = v;
    }

    this.setLineNumberStatus = function(e) {
        var label = "QueryBufferListClass.setLineNumberStatus: ";
        //debug.print(label + e);
        if (this.lineStatus == null) {
            debug.print(label + "null textareaStatus!");
            return;
        }

        var buf = this.input;

        if (!simulateSelectionStart(this.input)) {
            return;
        }

        var start = buf.selectionStart;
        var textToStart = null;
        var linesArray = null;
        var lineNumber = 1;
        var column = 0;
        if (start > 0) {
            // figure out where start is, in the query
            textToStart = buf.value.substr(0, start);
            linesArray = textToStart.split(/\r\n|\r|\n/);
            lineNumber = linesArray.length;
            // because of the earlier substr() call,
            // we know that the last line ends at selectionStart
            var column = linesArray[lineNumber - 1].length;
            // NB: at the start of a line, firefox returns an empty string
            // meanwhile, IE6 swallows the whitespace...
            // seems to be in the selection-range API, not in split(),
            // so there is no workaround!
            //debug.print(label + " start = " + start
            //          + " lineNumber = " + lineNumber
            //          + " column = " + column
            //          + ", lastLine = " + linesArray[lineNumber - 1] );
        } else {
            debug.print(label + "start = 0");
        }
        this.lineStatus.innerHTML = "" + lineNumber + "," + column;
    }

    this.toXml = function() {
        var name = "query-buffers";
        var xml = "<" + name + ">\n";

        for (var i = 0; i < this.buffers.length; i++) {
            xml += this.buffers[i].toXml();
        }

        xml += "</" + name + ">\n";
        //debug.print("QueryBufferListClass.toXml: " + xml);

        return xml;
    }

} // QueryBufferListClass

function cqOnLoad() {
    debug.print("cqOnLoad: begin");

    // register for key-presses
    Event.observe(this, "keypress", handleKeyPress);

    // set the OS-specific instruction text
    setInstructionText();

    // set up the UI objects
    gBuffers = new QueryBufferListClass("/cq:input", "/cq:eval-in",
                                        "/cq:buffer-list",
                                        "/cq:textarea-status");
    gBuffers.initHandlers();
    gHistory = new QueryHistoryClass("/cq:history", gBuffers);
    var sessionDatabaseId = $F("/cq:session-database");
    gSession = new SessionClass(sessionDatabaseId, gBuffers, gHistory);

    // restore buffers and history
    var restore = $("/cq:restore-session");
    debug.print("onload: restoring from "
                + restore + " " + restore.hasChildNodes());
    if (null != restore && restore.hasChildNodes()) {
        var children = restore.childNodes;
        var queries = null;
        var query = null;

        // first div is the buffers
        var buffers = children[0];
        queries = buffers.childNodes;
        debug.print("onload: restoring buffers " + queries.length);
        for (var i = 0; i < queries.length; i++) {
            query = queries[i].textContent;
            //debug.print("onload: restoring " + i + " " + query);
            gBuffers.add(query);
        }

        // second div is the history
        var history = children[1];
        queries = history.childNodes;
        debug.print("onload: restoring history " + queries.length);
        // restore in reverse order
        for (var i = queries.length; i > 0; i--) {
            query = queries[ i - 1 ].textContent;
            //debug.print("onload: restoring " + i + " " + query);
            gHistory.add(query);
        }
    }

    // expose the correct tabs
    refreshBufferTabs(0);

    // display the buffer list, exposing buffer 0, and focus
    gBuffers.activate();

    resizeFrameset();

}

function setInstructionText() {
    var instructionNode = $(gBufferAccesskeyText);
    if (!instructionNode) {
        alert("no instruction text node!");
        return;
    }
    // if this is IE6, hide the text entirely (keys do not work)
    if (gBrowserIs.ie) {
        Element.hide(instructionNode.parentNode);
        return;
    }
    var theText = "alt";
    // we only need to worry about X11 (see the comment in handleKeyPress)
    if (gBrowserIs.x11) {
        theText = "ctrl";
    }
    debug.print("setInstructionText: " + theText);
    Element.update(instructionNode, '');
    instructionNode.appendChild(document.createTextNode(theText));
}

function getFrameset() {
    // get it from the parent document
    return parent.document.getElementById(gFramesetId);
}

function getQueryFrame() {
    // get it from the parent document
    return parent.document.getElementById(gQueryFrameId);
}

function getResultFrame() {
    // get it from the parent document
    return parent.document.getElementById(gResultFrameId);
}

function resizeFrameset() {
    var frameset = getFrameset();
    if (frameset == null) {
        debug.print("resizeFrameset: null frameset");
        return;
    }
    // set the result-frame height to fill the available space
    // pick a reasonable default value
    var rows = 500;
    // figure out where some well-known element ended up
    // in this case we'll use the total height of the query form
    // this might be called from the queryframe or from the parent frameset
    var visible = $(gQueryFormId);
    if (visible == null) {
        // hackish
        var documentNode = window.frames[0].window.document;
        visible = documentNode.getElementById(gQueryFormId);
    }
    if (visible == null) {
        debug.print("nothing to resize from!");
        return;
    }

    debug.print("resizeFrameset: visible " + visible
          + ", " + visible.offsetTop + ", " + visible.offsetHeight);
    // add a smidgen for fudge-factor, so we don't activate scrolling:
    // 15px is enough for gecko, but IE6 wants 17px
    rows = 17 + visible.offsetTop + visible.offsetHeight;
    frameset.rows = rows + ",*";
} // resizeFrameset

function refreshBufferTabs(n) {
    if (n == null || n == gBufferTabsCurrent)
        return;

    debug.print("refreshBufferTabs: " + n + ", " + gBufferTabsCurrent);
    gBufferTabsCurrent = n;

    var tabsNode = $(gBufferTabsNode);
    if (tabsNode == null) {
        debug.print("refreshBufferTabs: null tabsNode");
        return;
    }

    // check gBufferTabsCurrent against each child span
    var buffersTitleNode =
        $(gBufferTabsNode + "-0");
    var historyTitleNode =
        $(gBufferTabsNode + "-1");
    if (!buffersTitleNode || ! historyTitleNode) {
        debug.print("refreshBufferTabs: null title node(s)");
        return;
    }

    var buffersNode = gBuffers.labelList;
    var historyNode = gHistory.node;

    // set the history and queries to have the same width
    historyNode.style.minWidth = buffersNode.clientWidth + "px";

    // simple for now: node 0 is buffer list, 1 is history
    // TODO move the instruction text too?
    if (gBufferTabsCurrent == 0) {
        debug.print("refreshBufferTabs: displaying buffer list");
        // highlight the active tab
        buffersTitleNode.className = "buffer-tab-active";
        historyTitleNode.className = "buffer-tab";
        // hide and show the appropriate list
        Element.show(buffersNode);
        Element.hide(historyNode);
        return;
    }

    debug.print("refreshBufferTabs: displaying history");
    // highlight the active tab
    buffersTitleNode.className = "buffer-tab";
    historyTitleNode.className = "buffer-tab-active";

    // match the buffer height, to reduce frame-redraw
    debug.print("resizeBufferTabs: " + buffersNode.offsetTop + ", "
                + buffersNode.offsetHeight);
    historyNode.height = buffersNode.offsetHeight;

    // hide and show the appropriate list
    Element.hide(buffersNode);
    Element.show(historyNode);

}

// keycode support:
//   ctrl-ENTER for XML, alt-ENTER for HTML, shift-ENTER for text/plain
//   alt-1 to alt-0 exposes the corresponding buffer (really 0-9)
function handleKeyPress(e) {
    var theCode = e.keyCode;
    // see http://www.mozilla.org/editor/key-event-spec.html
    // for weird gecko behavior
    // see also: http://www.brainjar.com/dhtml/events/default4.asp
    if (e.charCode && e.charCode != 0) {
        theCode = e.charCode;
    }

    var altKey = e['altKey'];
    var ctrlKey = e['ctrlKey'];
    var shiftKey = e['shiftKey'];
    var metaKey = e['metaKey'];

    // short-circuit if we obviously don't care about this keypress
    if (! (ctrlKey || altKey) ) {
        return true;
    }

    // in case we need debug info...
    var keyInfo = "win=" + gBrowserIs.win
        + " x11=" + gBrowserIs.x11
        + " mac=" + gBrowserIs.mac + ", "
        + (metaKey ? "meta " : "")
        + (ctrlKey ? "ctrl " : "") + (shiftKey ? "shift " : "")
        + (altKey ? "alt " : "") + theCode;
    debug.print("handleKeyPress: " + keyInfo);

    // handle buffers: 1 = 49, 9 = 57, 0 = 48
    // ick: firefox-linux decided to use alt 0-9 for tabs
    //   win32 uses ctrl, macos uses meta.
    // So we accept either ctrl or alt:
    // the browser will swallow anything that it doesn't want us to see.
    if ( (theCode >= 48) && (theCode <= 57) ) {
        // expose the corresponding buffer: 0-9
        var n = (theCode == 48) ? 9 : (theCode - 49);
        gBuffers.activate(n);
        return false;
    }

    // treat ctrl-shift-s (83) as session-sync
    var theForm = $(gQueryFormId);
    if (shiftKey && ctrlKey && theCode == 83) {
        // sync the session to the database
        gSession.sync();
        return false;
    }

    if (theCode == Event.KEY_RETURN) {
        if (ctrlKey && shiftKey) {
            submitText(theForm);
        } else if (altKey) {
            // TODO alt-enter doesn't work in IE6?
            submitHTML(theForm);
        } else {
            submitXML(theForm);
        }
        return false;
    }

    // ignore other keys
    return true;
} // handleKeyPress

function submitForm(theForm, query, theMimeType) {
    if (! theForm) {
        alert("null form in submitForm!");
        return;
    }

    gBuffers.activate();

    gHistory.add(query);

    // sync the session, if it has changed
    gSession.sync(gHistory.lastModified);

    // TODO would like to disable buttons during post
    // TODO it would be nice to grey out the target frame, if possible

    // copy query to the hidden element
    $(gQueryInput).value = query;
    debug.print("submitForm: " + $F(gQueryInput));

    // set the mime type
    if (theMimeType != null) {
        debug.print("submitForm: mimeType = " + theMimeType);
        $(gQueryMimeType).value = theMimeType;
    }

    // post the form
    theForm.submit();
}

function submitXML(theForm) {
    submitFormWrapper(theForm, "text/xml");
}

function submitHTML(theForm) {
    submitFormWrapper(theForm, "text/html");
}

function submitText(theForm) {
    submitFormWrapper(theForm, "text/plain");
}

function submitFormWrapper(theForm, mimeType) {
    debug.print("submitFormWrapper: " + theForm + " as " + mimeType);
    if (!theForm) {
        return;
    }

    var query = gBuffers.getQuery();

    submitForm(theForm, query, mimeType);
}

function cqListDocuments() {
    // TODO create a link to display each document?
    var theForm = $(gQueryFormId);
    var theQuery =
        "let $est := xdmp:estimate(doc()) "
        + "return ("
        + "( text { 'Too many documents to display!' },"
        + " text { 'First 1000 documents of', $est, 'total:' },"
        + " text{})[$est gt 1000],"
        + "  for $i in doc()[1 to 1000] return text { base-uri($i) }"
        + ")";
    submitForm(theForm, theQuery, "text/plain");
}

// query.js
