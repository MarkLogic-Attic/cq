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

// GLOBAL CONSTANTS: but IE6 doesn't support "const"
var kFramesetId = "/cq:frameset";
var kQueryFrameId = "/cq:queryFrame";
var kResultFrameId = "/cq:resultFrame";
var kQueryFormId = "/cq:form";
var kQueryInput = "/cq:query";
var kQueryMimeType = "/cq:mime-type";

// I would prefer something like \u2715, but many systems don't display it.
var kDeleteWidget = " (x) ";

// is there some *optional* linebreak character we could use?
// yes: http://www.quirksmode.org/oddsandends/wbr.html
// but I don't want to muck with the wbr element in a string...
// solution: "&shy;" (#173, 0xAD) seems to work for IE and gecko
// another candiate is #8203 (0x200b), but it isn't as nice.
// not perfect, but seems to be ok...
var kBreakChar = "\u00ad"; //"\u200b";

// GLOBAL VARIABLES
var gBrowserIs = new BrowserIsClass();
var gBufferTabs = null;
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
    if (null == s) {
        return null;
    }
    s = s.replace("/(/g", "(" + kBreakChar);
    s = s.replace("/)/g", kBreakChar + ")");
    s = s.replace("/,/g", "," + kBreakChar);
    s = s.replace("/=/g", kBreakChar + "=" + kBreakChar);
    return normalizeSpace(s);
}

function escapeXml(s) {
    if (null == s) {
        return null;
    }
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
    //debug.print(label + "n = " + n);
    if (null == n) {
        //debug.print(label + "null buf!");
        return false;
    }
    if (n.style.display == 'none') {
        //debug.print(label + "hidden buf");
        return false;
    }

    // must handle this differently for gecko vs IE6
    // must test non-gecko first, since this code will persist
    // it's a little tricky to tell the difference between IE6 and opera,
    // but I'd rather avoid calling gBrowserIs.opera()
    if (!window.getSelection && !document.getSelection
        && document.selection && document.selection.createRange) {
        //debug.print(label + "document.selection found");
        // set it up, using IE5+ API
        // http://msdn.microsoft.com/workshop/author/dhtml/reference
        //   /objects/obj_textrange.asp
        // first, make sure we have the focus
        debug.print(label + "focus on " + n);
        //n.focus();
        var range = document.selection.createRange();
        debug.print(label + "range = " + range);
        var storedRange = range.duplicate();
        if (null == storedRange) {
          debug.print(label + "null storedRange");
          n.selectionStart = 0;
          return false;
        }
        debug.print(label + "storedRange = " + storedRange);
        // TODO this call seems to be failing: Invalid argument
        //storedRange.moveToElementText(n);
        debug.print(label + "storedRange = " + storedRange);
        storedRange.setEndPoint('EndToEnd', range);
        debug.print(label + "storedRange = " + storedRange);
        //debug.print(label + "storedRange.text = '"
        //          + storedRange.text + "'"
        //          + " (" + storedRange.text.length
        //          + "," + range.text.length
        //          + "," + n.value.length
        //          + ")");
        // set start and end points, ala gecko
        n.selectionStart = (storedRange.text.length
                                     - range.text.length);
        // now we can pretend that IE6 is gecko
        //debug.print(label + "selectionStart = " + n.selectionStart);
        return true;
    }

    if (n && n.selectionStart) {
        // looks like gecko: selectionStart should work
        //debug.print(label + "found " + n.selectionStart);
        return true;
    }

    // unsupported, or at the start of buffer: either way, pretend 0
    //debug.print(label + "no selection information: setting 0");
    n.selectionStart = 0;
    return true;
}

// Given a node and a new caret position, set it.
function setPosition(n, start, top, left) {
    var label = "setPosition: ";

    if (null == start) {
        start = n.value.length;
    }

    // IE6 - is that you?
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
        n.scrollTop = top;
        n.scrollLeft = left;
        return;
    }

    // gecko
    debug.print(label + "gecko, setting " + start + ", " + top + ", " + left);
    n.selectionStart = start;
    n.selectionEnd = start;
    n.scrollTop = top;
    n.scrollLeft = left;
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

function BufferTabsClass(nodeId, instructionId, buffers, history) {
    this.node = $(nodeId);
    this.instructionNode = $(instructionId);
    this.buffers = buffers;
    this.history = history;
    this.buffersTitle = $(nodeId + "-0");
    this.historyTitle = $(nodeId + "-1");
    this.current = null;
    this.session = null;

    this.getCurrent = function() {
        return this.current;
    }

    this.getBuffers = function() {
        return this.buffers;
    }

    this.getHistory = function() {
        return this.history;
    }

    this.getSession = function() {
        return this.session;
    }

    this.setSession = function(s) {
        this.session = s;
    }

    this.setInstructionText = function() {
        if (! (this.instructionNode && this.instructionNode.innerHTML)) {
            return;
        }
        // if this seems to be IE6, hide the text entirely (keys do not work)
        if (gBrowserIs.ie) {
            debug.print("BufferTabsClass.setInstructionText: skipping IE");
            Element.hide(this.instructionNode.parentNode);
            return;
        }
        // we only need to worry about X11 (see the comment in handleKeyPress)
        var theText = gBrowserIs.x11 ? "ctrl" : "alt";
        debug.print("setInstructionText: " + theText);
        // clear any old text
        Element.removeChildren(this.instructionNode);
        this.instructionNode.appendChild(document.createTextNode(theText));
    }

    this.toggle = function() {
        debug.print("BufferTabsClass.toggle: this.current");
        this.refresh((0 == this.current) ? 1 : 0);
    }

    this.refresh = function(n) {
        var label = "BufferTabsClass.refresh: ";
        debug.print(label + n + ", " + this.current);

        if (isNaN(n)) {
            this.refresh(this.current);
            return;
        }

        this.current = null == n ? 0 : n;

        // focus on the textarea
        this.buffers.focus();

        var buffersNode = this.buffers.labelList;
        var historyNode = this.history.node;

        // simple for now: node 0 is buffer list, 1 is history
        // TODO move the instruction text too?
        if (this.current == 0) {
            debug.print(label + "displaying buffers");
            // highlight the active tab
            this.buffersTitle.className = "buffer-tab-active accent-color";
            this.historyTitle.className = "buffer-tab";
            // hide and show the appropriate list
            Element.show(buffersNode);
            Element.hide(historyNode);
            return;
        }

        debug.print(label + "displaying history");
        // highlight the active tab
        this.buffersTitle.className = "buffer-tab";
        this.historyTitle.className = "buffer-tab-active accent-color";

        // must ensure that buffers are visible for this to work.
        Element.show(buffersNode);
        Element.hide(historyNode);
        // TODO use the form, instead?
        var bufferHeight = this.buffers.input.clientHeight;
        var bufferOffset = this.buffers.input.offsetTop;
        var bufferWidth = buffersNode.clientWidth;
        debug.print(label + "buffer width = " + buffersNode.clientWidth);

        // must ensure that history is visible for this to work.
        Element.hide(buffersNode);
        Element.show(historyNode);
        var historyOffset = historyNode.offsetTop;

        // match the textarea height
        var height = bufferHeight + bufferOffset - historyOffset;
        debug.print(label + "new height = " + height);
        historyNode.style.minHeight = height + "px";

        // set the history and buffers to have the same width
        // this works with IE6 and gecko
        historyNode.style.width = bufferWidth + "px";
        debug.print(label + "history width = " + historyNode.clientWidth);

        // hide and show the appropriate list
        Element.hide(buffersNode);
        Element.show(historyNode);
    }

    this.unload = function(e) {
        //alert("BufferTabsClass: unload "
        //      + e + ", " + this.buffers + ", " + this.session);
        // sync the input
        if (null != this.buffers) {
            this.buffers.activate();
            if (null != this.session) {
                this.session.sync();
            }
        }
    }

    this.toXml = function() {
        var name = "active-tab";
        return "<" + name + ">" + this.current + "</" + name + ">";
    }

    this.enableButtons = function() {
        var list = document.getElementsByTagName("input");
        for (var i = 0; i< list.length; i++) {
            if (list[i].getAttribute('type') == 'button') {
                list[i].disabled = false;
            }
        }
    }

    this.disableButtons = function() {
        var list = document.getElementsByTagName("input");
        for (var i = 0; i< list.length; i++) {
            if (list[i].getAttribute('type') == 'button') {
                list[i].disabled = true;
            }
        }
    }

} // BufferTabsClass

// The history will act something like a stack,
// and something like an array.
// This requires a two-fold structure:
//   - hash: a Hash with normalized-query as key, li element as value
//   - listNode: an ol element with li children
// The hash provides de-duplication of queries,
// while the listNode acts like a fixed-size stack.
function QueryHistoryClass(id, buffers, limit) {
    // init history list node
    this.node = $(id);
    this.limit = limit ? limit : 50;
    this.buffers = buffers;
    debug.print("QueryHistoryClass.init: node = " + this.node
                + ", buffers = " + buffers);

    this.listNode = document.createElement("ol");
    this.hash = $H();
    this.lastModified = new Date();

    this.add = function(query) {
        var label = "QueryHistoryClass.add: ";
        //debug.print(label + query);
        if (query == null || query == "") {
            return;
        }

        // the whitespace-normalized query acts as the hash key
        var key = this.getKey(query);
        if (key == null || key == "") {
            return;
        }

        //debug.print(label + "key = " + key);

        // lazy initialization
        if (null == this.listNode.parentNode) {
            // We haven't attached the listNode to the document yet:
            // remove any existing text and attach our listNode.
            Element.removeChildren(this.node);
            this.node.appendChild(this.listNode);
        }

        var listItem = this.hash[key];
        if (null != listItem) {
            // new query has a duplicate: replace the existing item.
            Element.remove(listItem);
            this.hash[key] = null;
        }
        // build a new listItem
        listItem = this.newListItem(key, query);

        // update the hash
        this.hash[key] = listItem;
        this.lastModified = new Date();

        if (!this.listNode.hasChildNodes()) {
            debug.print(label + "first entry");
            this.listNode.appendChild(listItem);
            return;
        }

        // place the new listItem at the top of the listNode children
        this.listNode.insertBefore(listItem, this.listNode.firstChild);

        // check size limit, and truncate if needed
        var overflow = $A(this.listNode.childNodes).slice(this.limit);

        if (null == overflow || overflow.length < 1) {
            return;
        }

        debug.print(label + "truncating " + overflow.length);
        var key = null;
        for (i = 0; i < overflow.length; i++) {
            // we have values, but this.remove() takes a key
            // a key is just the normalized query, though
            key = this.getKey(this.getListItemValue(overflow[i]));
            debug.print(label + "truncating " + i + " = " + key);
            this.remove(key);
        }
    }

    this.getKey = function(value) {
        return normalizeSpace(value);
    }

    this.remove = function(key) {
        // remove this listItem and its corresponding hash entry
        // will this work? relying on garbage collection?
        var node = this.hash[key];
        if (null != node) {
            Element.remove(node);
        }
        this.hash[key] = null;
        this.lastModified = new Date();
    }

    this.getLastModified = function() {
        return this.lastModified;
    }

    this.setQuery = function(e) {
        // we don't know which query was clicked,
        // but we know that the click was on a span element
        var node = Event.element(e);
        node.setAttribute("xml:space", "preserve");
        debug.print("QueryHistoryClass.setQuery: " + node);
        var query = node.firstChild.nodeValue;
        debug.print("QueryHistoryClass.setQuery: " + query);
        this.buffers.setQuery(query);
    }

    this.newListItem = function(key, query) {
        var newItem = document.createElement("li");

        // delete widget
        var deleteLink = document.createElement("span");
        newItem.appendChild(deleteLink);
        deleteLink.className = "delete-widget";
        Event.observe(deleteLink, "click",
                      function() {
            if (confirm("Are you sure you want to delete this query?")) {
                this.remove(key);
            }
        }.bindAsEventListener(this)
                      );
        deleteLink.title = "Click to delete this query from your history.";
        deleteLink.appendChild(document.createTextNode(kDeleteWidget));

        // query text - all of it
        var queryNode = document.createElement("span");
        queryNode.appendChild(document.createTextNode(query));
        // onclick, copy to current textarea
        Event.observe(queryNode, "click",
                      this.setQuery.bindAsEventListener(this));

        // tool-tip
        queryNode.title = "Click to copy this into the active buffer.";
        newItem.appendChild(queryNode);

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

    this.getListItemValue = function(node) {
        // skip over the delete widget
        // XPath would be something like:
        // data($query/*[@class ne 'delete-widget'][1]/text()[1])
        var query = node.firstChild;
        while (query.className == "delete-widget") {
            query = query.nextSibling;
        }
        return query.firstChild.nodeValue;
    }

    this.toXml = function() {
        var parentName = "query-history";
        var queryName = "query";

        var xml = "<" + parentName + ">\n";

        // values() yields an unstable order,
        // so we use listNode.childNodes instead.
        var nodes = $A(this.listNode.childNodes);
        var query = null;
        for (var i = 0; i < nodes.length; i++) {
            query = this.getListItemValue(nodes[i]);
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
    // start at the top
    this.selectionStart = (null == selectionStart)
        ? selectionStart : query.length;
    // also track the scrollTop, scrollWidth
    this.scrollTop = this.selectionStart;
    this.scrollLeft = 0;
    // also track the contentbase and app-server
    this.contentSource = contentSource;

    this.getQuery = function() {
        return this.query;
    }

    this.setQuery = function(query) {
        this.query = query;
    }

    this.getScrollTop = function() {
        return this.scrollTop;
    }

    this.setScrollTop = function(v) {
        this.scrollTop = v;
    }

    this.getScrollLeft = function() {
        return this.scrollLeft;
    }

    this.setScrollLeft = function(v) {
        this.scrollLeft = v;
    }

    this.getSelectionStart = function() {
        return this.selectionStart;
    }

    this.setPosition = function(start, top, left) {
        debug.print("QueryBufferClass.setPosition: "
                    + start + ", " + top + ", " + left);
        this.selectionStart = start;
        this.scrollTop = top;
        this.scrollLeft = left;
    }

    this.getContentSource = function() {
        return this.contentSource;
    }

    this.setContentSource = function(v) {
        if (null == v) {
            return;
        }
        this.contentSource = v;
    }

    this.toXml = function() {
        var name = "query";
        var xml ="<" + name;
        if (null != this.contentSource) {
            xml += " content-source=\"" + escapeXml(this.contentSource) + "\"";
        }
        xml += ">" + escapeXml(this.query) + "</" + name + ">\n";
        return xml;
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
    this.lastLineStatus = null;
    this.last = null;

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

    this.focus = function() {
        this.input.focus();
    }

    this.getQuery = function(n) {
        //debug.print("QueryBufferListClass.getBufferValue: " + n);
        if (null == n || this.pos == n) {
            //debug.print("QueryBufferListClass.getQuery: using textarea "
            //            + this.input.value);
            var buf = this.getBuffer(n);
            buf.setQuery(this.input.value);
            return buf.getQuery();
        }
        return this.getBuffer(n).getQuery();
    }

    this.setQuery = function(query) {
        debug.print("QueryBufferListClass.setQuery: pos = " + this.pos);
        if (null == query) {
            return;
        }

        // first, propagate everything to the active buffer object
        var buf = this.getBuffer();
        simulateSelectionStart(this.input);
        buf.setPosition(this.input.selectionStart,
                        this.input.scrollTop,
                        this.input.scrollLeft);
        buf.setQuery(query);
        buf.setContentSource(this.eval.value);

        // update the input, if it changed:
        // checking this avoids re-setting the input.value caret.
        if (this.input.value != query) {
            this.input.value = query;
        }

        // update the label
        this.setLabel(this.pos, true);
    }

    this.add = function(query, source) {
        //debug.print("QueryBufferListClass.add: query = " + query);
        debug.print("QueryBufferListClass.add: source = " + source);
        var n = this.buffers.length;
        this.buffers[n] = new QueryBufferClass(query);
        this.buffers[n].setContentSource(source);
        var active = false;
        if (n == this.pos) {
            // lazy init
            this.input.value = query;
            //debug.print("QueryBufferListClass.add: input.value = "
            //            + this.input.value);
            if (source != null) {
                this.eval.value = source;
            }
            //this.focus();
            active = true;
        }
        this.setLabel(n, active);
    }

    this.remove = function(n) {
        if (this.buffers.length <= n) {
            return;
        }

        if (n == this.pos) {
            this.activate(this.last);
            this.last = null;
        }

        this.buffers[n] = null;
        this.buffers = this.buffers.compact();
        var labelNode = this.getLabel(n);
        debug.print("QueryBufferListClass.remove: " + n
                    + ", labelNode = " + labelNode);
        if (null != labelNode) {
            // we actually want the table row
            labelNode = labelNode.parentNode.parentNode;
            debug.print("QueryBufferListClass.remove: " + n
                        + ", labelNode = " + labelNode.nodeName);
            Element.remove(labelNode);
        }

        for (var i = n; i < this.buffers.length; i++) {
            this.setLabel(i, i == this.pos);
        }

    }

    this.setLabel = function(n, active) {
        debug.print("QueryBufferListClass.setLabel: " + n + ", " + active);
        n = (null == n) ? this.pos : n;
        active = active || false;

        var label = this.getLabel(n);
        if (null == label) {
            debug.print("QueryBufferListClass.setLabel: null label");
            return;
        }

        // update the active status
        var theNum = this.setLabelNumber(n, label, active);

        // sometimes 1 + "1" = "11"
        theNum.appendChild(document.createTextNode((1 + Number(n)) + "."));
        label.appendChild(theNum);

        if (active) {
            this.addLabelDeleteWidget(label);
        }

        // Update the label text from the query
        // ...make sure it doesn't break for huge strings
        var query = this.getQuery(n);
        query = (null == query) ? "" : query;
        query = query.substr(0, 1024);
        // ...let the css handle text that's too large for the buffer
        // ...we shouldn't have to normalize spaces, but IE6 is broken
        // ...and so we have to hint word-breaks to both browsers.
        query = nudge(query);

        // put a nbsp here for formatting, so it won't be inside the link
        label.appendChild(document.createTextNode("\u00a0" + query));

        // TODO mouseover for fully formatted text contents as tooltip?
    }

    this.setLabelNumber = function(n, label, active) {
        var theNum = null;

        if (active) {
            // show the current index in bold, with no link
            theNum = document.createElement('b');
            // use highlighting
            label.className = 'bufferlabel-active accent-color';
            // deactivate any onclick
            label.onclick = null;
            // set tooltip
            label.title = null;
            return theNum;
        }

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
        return theNum;
    }

    this.addLabelDeleteWidget = function(label) {
        // delete widget
        var deleteLink = document.createElement("span");
        label.appendChild(deleteLink);
        deleteLink.className = "delete-widget";
        Event.observe(deleteLink, "click",
                      function() {
            if (confirm("Are you sure you want to delete this query?")) {
                this.remove(this.pos);
            }
        }.bindAsEventListener(this)
                      );
        deleteLink.title = "Click to delete this query from your list.";
        deleteLink.appendChild(document.createTextNode(kDeleteWidget));
    }

    this.getLabel = function(n) {

        // it will be the n-th div below this.labelsBody
        var labels = this.labelsBody.getElementsByTagName('div');
        var labelNode = labels[n];

        // what if there isn't a label for n?
        if (null == labelNode) {
            // if it isn't a valid buffer, skip it
            if (this.buffers.length <= n) {
                return null;
            }
            // otherwise, create one
            var row = document.createElement('tr');
            this.labelsBody.appendChild(row);
            var cell = document.createElement('td');
            row.appendChild(cell);
            labelNode = document.createElement('div');
            cell.appendChild(labelNode);
        } else {
            // destroy any contents
            Element.removeChildren(labelNode);
        }
        return labelNode;
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

    this.resize = function(x, y) {
        debug.print("QueryBufferListClass.resize: " + x + "," + y);
        this.input.cols += x;
        this.input.rows += y;
    }

    this.setRows = function(x) {
        if (null == x) {
            return;
        }
        this.input.rows = x;
    }

    this.setCols = function(y) {
        if (null == y) {
            return;
        }
        this.input.cols = y;
    }

    this.nextBuffer = function() {
        if (this.pos >= this.buffers.length - 1) {
            this.activate(0);
            return;
        }

        this.activate(1 + Number(this.pos));
    }

    this.previousBuffer = function() {
        if (this.pos < 1) {
            this.activate(this.buffers.length - 1);
            return;
        }

        this.activate(this.pos - 1);
    }

    this.activate = function(n) {
        var label = "QueryBufferListClass.activate: ";
        debug.print(label + this.pos + " to " + n);

        var buf = this.getBuffer();

        // save any state from the current buffer
        if (null != buf) {
            this.setQuery(this.input.value);
        }

        if (null == n
            || isNaN(n)
            || 0 > n
            || this.buffers.length <= n)
        {
            return;
        }

        if (this.pos == n) {
            return;
        }

        // deactivate the current buffer
        this.setLabel(this.pos, false);

        // activate the new buffer and restore its state
        this.last = this.pos;
        this.pos = n;
        buf = this.getBuffer(n);
        this.input.value = buf.getQuery();
        this.setContentSource(buf.getContentSource());
        this.setLabel(this.pos, true);

        setPosition(this.input, buf.getSelectionStart(),
                    buf.getScrollTop(), buf.getScrollLeft());
        this.focus();
    }

    this.setContentSource = function(v) {
        var old = this.eval.value;
        this.eval.className = "";
        if (old == v) {
            return;
        }
        this.eval.value = v;
        if (null == old || "" == old || null == v || "" == v) {
            return;
        }
        // this was a real change, so cue the user visually
        //alert("old = " + old);
        var oldClassName = this.eval.className;
        this.strobe(6, "accent-color", oldClassName);
    }

    // strobe the eval selector (n / 2) times, recursively
    this.strobe = function(n, accent, old) {
        if ((n % 2) == 0) {
            this.eval.className = old;
        } else {
            this.eval.className = accent;
        }
        if (n < 1) {
            this.eval.className = old;
            return;
        }
        setTimeout(function() { this.strobe(n - 1, accent, old); }
                   .bindAsEventListener(this),
                   100);
    }

    this.getLastLineStatus = function() {
        return this.lastLineStatus;
    }

    this.setLineNumberStatus = function(e) {
        var label = "QueryBufferListClass.setLineNumberStatus: ";
        this.lastLineStatus = new Date();

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
        if (null == start) {
            debug.print(label + "null start");
        }
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
        var xml = "<" + name;
        // persist active buffer
        if (this.pos) {
            xml += " active=\"" + this.pos + "\"";
        }
        // persist textarea dimensions
        xml += " rows=\"" + this.input.rows + "\"";
        xml += " cols=\"" + this.input.cols + "\"";
        xml += ">\n";

        for (var i = 0; i < this.buffers.length; i++) {
            if (this.pos == i) {
                this.setQuery(this.input.value);
            }
            xml += this.buffers[i].toXml();
        }

        xml += "</" + name + ">\n";
        //debug.print("QueryBufferListClass.toXml: " + xml);

        return xml;
    }

} // QueryBufferListClass

// PolicyClass
function PolicyClass(titleId, title, accentClass, accentColor) {
    debug.print("PolicyClass: " + "titleId = " + titleId)

    this.titleNode = $(titleId);
    this.title = title;
    this.accentClass = accentClass;
    this.accentColor = accentColor;

    this.getTitle = function() {
        return this.title;
    }

    this.getAccentColor = function() {
        return this.accentColor;
    }

    // see http://www.quirksmode.org/dom/w3c_css.html
    // see http://www.quirksmode.org/dom/changess.html
    this.enforce = function() {

        var label = "PolicyClass.enforce: ";

        debug.print(label + "titleNode = " + this.titleNode)
        debug.print(label + "title = " + this.title)
        if (null != this.titleNode
            && null != this.title
            && "" != this.title)
        {
            // enforce title
            Element.removeChildren(this.titleNode);
            this.titleNode.appendChild(document.createTextNode(this.title));
        }

        if (null != this.accentColor && "" != this.accentColor) {
            // enforce accentColor, on accent class only
            var frames = new Array(document,
                                   parent.frames[1].document);
            var nodes;
            debug.print(label + "frames " + frames.length);
            for (var i = 0; i < frames.length; i++) {
                debug.print(label + "frame " + i + " = " + frames[i]);
                nodes = frames[i].getElementsByClassName(accentClass);
                for (var j = 0; j < nodes.length; j++) {
                    debug.print(label + "node for accent-color = "
                                + nodes[j].nodeName);
                    nodes[j].style.backgroundColor = this.accentColor;
                }
            }
        }
    }

} // PolicyClass

function cqOnLoad() {
    debug.print("cqOnLoad: begin");

    if (gBrowserIs.gecko) {
        // gecko problem with nodeValue longer than 4kB (encoded):
        // it creates multiple text-node children.
        // this is a DOM violation, but won't be fixed for some time.
        // see https://bugzilla.mozilla.org/show_bug.cgi?id=194231
        // This affects session restore.
        // workaround: call normalize() early
        debug.print("finishImport: normalizing for gecko workaround");
        document.normalize();
    }

    // register for key-presses
    Event.observe(this, "keypress", handleKeyPress);

    // set up the UI objects
    gBuffers = new QueryBufferListClass("/cq:input",
                                        "/cq:eval-in",
                                        "/cq:buffer-list",
                                        "/cq:textarea-status");
    gBuffers.initHandlers();

    gHistory = new QueryHistoryClass("/cq:history",
                                     gBuffers);

    gBufferTabs = new BufferTabsClass("/cq:buffer-tabs",
                                      "/cq:buffer-accesskey-text",
                                      gBuffers,
                                      gHistory);
    // set the OS-specific instruction text
    gBufferTabs.setInstructionText();

    gSession = new SessionClass(gBufferTabs, "/cq:restore-session");
    gSession.restore();
    // TODO enable autosave
    gSession.setAutoSave();

    gBufferTabs.setSession(gSession);

    // enforce local policy, if any
    var policy = new PolicyClass("/cq:title",
                                 $F("/cq:policy/title"),
                                 "head1",
                                 $F("/cq:policy/accent-color"));
    policy.enforce();

    // display the buffer list, exposing buffer 0
    gBuffers.activate();

    // once more, to fix widths
    gBufferTabs.refresh();

    resizeFrameset();

    // TODO save on unload
    // looks like we need prototype 1.5 for this:
    // "$A is not defined" at line 48, in the bind() code....
    //Event.observe(parent.window, "unload",
    //              gBufferTabs.unload.bindAsEventListener(gBufferTabs));
}

function resizeFrameset() {
    var frameset = parent.document.getElementById(kFramesetId);
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
    var visible = $(kQueryFormId);
    if (visible == null) {
        // hackish
        var documentNode = window.frames[0].window.document;
        visible = documentNode.getElementById(kQueryFormId);
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

// keycode support:
//   ctrl-ENTER for XML, alt-ENTER for HTML, shift-ENTER for text/plain
//   alt-1 to alt-0 exposes the corresponding buffer (really 0-9)
//   next buffer: alt-> (46)
//   previous buffer: alt-< (44)
//   NB: the modifer changes according to platform
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

    if (debug.isEnabled()) {
        var keyInfo = "win=" + gBrowserIs.win
            + " x11=" + gBrowserIs.x11
            + " mac=" + gBrowserIs.mac + ", "
            + (metaKey ? "meta " : "")
            + (ctrlKey ? "ctrl " : "") + (shiftKey ? "shift " : "")
            + (altKey ? "alt " : "") + theCode;
        debug.print("handleKeyPress: " + keyInfo);
    }

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

    // next buffer: alt-> (46)
    if (46 == theCode) {
        gBuffers.nextBuffer();
        return false;
    }

    // previous buffer: alt-< (44)
    if (44 == theCode) {
        gBuffers.previousBuffer();
        return false;
    }

    // toggle tab: alt-` (96)
    if (96 == theCode) {
        gBufferTabs.toggle();
        return false;
    }

    // treat ctrl-shift-s (83) as session-sync
    if (shiftKey && ctrlKey && theCode == 83) {
        // sync the session to the database
        // if sync fails, return true so that the event will bubble
        return ! gSession.sync();
    }

    if (theCode == Event.KEY_RETURN) {
        var theForm = $(kQueryFormId);
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

function submitForm(theForm, query, theMimeType, saveHistory) {
    debug.print("submitForm: " + query);

    if (! theForm) {
        alert("null form in submitForm!");
        return;
    }

    if (saveHistory) {
        gHistory.add(query);
    }

    // sync the session, if it has changed
    gSession.sync();

    // copy query to the hidden element
    $(kQueryInput).value = query;
    //debug.print("submitForm: " + $F(kQueryInput));

    // set the mime type
    if (null != theMimeType) {
        debug.print("submitForm: mimeType = " + theMimeType);
        $(kQueryMimeType).value = theMimeType;
    }

    // TODO it would be nice to grey out the target frame, if possible

    // post the form
    theForm.submit();

    // would like to disable buttons during post
    // TODO what if the user hits the stop button?
    // IE6 supports onstop, gecko does not
    // onabort is not useful for this.
    //gBufferTabs.disableButtons();
    //Event.observe(parent.frames[1].window, "unload",
    //function(e) { this.enableButtons(); }
    //.bindAsEventListener(gBufferTabs));
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

    submitForm(theForm, gBuffers.getQuery(), mimeType, true);
}

function cqListDocuments() {
    // I would rather use text/plain, but it causes problems for IE6
    // TODO create a link to display each document?
    var theQuery =
        "let $limit := 10000 "
        + "let $est := xdmp:estimate(doc()) "
        + "return ("
        + " if ($est gt $limit)"
        + " then element p { 'Too many documents to display!',"
        + "  'First', $limit, 'documents of', $est, 'total:' }"
        + " else element p { $est, 'documents total' },"
        + " for $i in doc()[1 to $limit]"
        + " let $uri := xdmp:node-uri($i)"
        + " let $n := $i/(binary()|element()|text())[1]"
        + " where $n"
        + " order by $uri"
        + " return ( $uri,"
        + " <span> - </span>,"
        + " <i>{ node-kind($n) }</i>,"
        + " <code>&#160;{ name($n) }</code>, <br/> )"
        + ")";
    submitForm($(kQueryFormId), theQuery, "text/html", false);
}

// query.js
