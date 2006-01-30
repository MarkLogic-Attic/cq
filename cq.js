// Copyright (c) 2003-2005 Mark Logic Corporation. All rights reserved.
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
//
//////////////////////////////////////////////////////////////////////
//
// REFERENCES:
//   * good cross-browser info at http://quirksmode.org/
//   * keycodes from http://sniptools.com/jskeys
//
//////////////////////////////////////////////////////////////////////

// TODO refactor more of this controller-style logic into classes:
// BufferClass, BufferListClass, HistoryClass, etc.

// GLOBAL CONSTANTS: but IE6 doesn't support "const"
// NB: I'd like to ditch these underscores,
// NB: in favor of /cq:foo-bar-baz,
// NB: but the xml export format depends on /cq_buffers/cq_buffer
var g_cq_frameset_id = "cq_frameset";
var g_cq_query_frame_id = "cq_queryFrame";
var g_cq_result_frame_id = "cq_resultFrame";
var g_cq_query_input = "/cq:query";
var g_cq_uri = "cqUri";
var g_cq_import_export_id = "cq_import_export";
var g_cq_query_form_id = "cq_form";
var g_cq_bufferlist_id = "cq_bufferlist";
var g_cq_buffers_area_id = "cq_buffers";
var g_cq_buffer_basename = "cq_buffer";
var g_cq_history_basename = "cq_history";
var g_cq_eval_list_id = "/cq:eval-in";
var g_cq_query_mime_type = "/cq:mime-type";
var g_cq_query_action = "cq-eval.xqy";
var g_cq_buffer_accesskey_text = "cq_buffer_accesskey_text";
var g_cq_buffer_tabs_node = "cq-buffer-tabs";
var g_cq_history_node = "/cq:history";
var g_cq_buffers_cookie = "cq_buffer_cookie_buffers";
var g_cq_history_cookie = "cq_buffer_cookie_history";
var g_cq_textarea_status = "cq_textarea_status";
var g_cq_debug_status_id = "/cq:debug"

// GLOBAL VARIABLES
var g_cq_buffer_tabs_current = null;
var g_cq_buffer_current = 0;
var g_cq_next_id = 0;
var g_cq_timeout = 100;
var g_cq_history_limit = 50;

var debug = new DebugClass();

// handy way to get the body element
function BodyClass() {
    this.node = document.body;
    if (this.node == null) {
        this.node = document.createElement("body");
        document.appendChild(body);
    }
    this.getNode = function() { return this.node; };
}

// define a debug class
function DebugClass(flag) {
    if (flag == null) {
        flag = false;
    }

    this.setEnabled = function(flag) { this.enabled = flag; };
    this.isEnabled = function() { return this.enabled };

    this.setEnabled(flag);

    this.print = function(message) {
        if (this.enabled != true) { return; }

        var id = "__debugNode";
        var debugNode = document.getElementById(id);
        if (debugNode == null) {
            // add as new child of the html body
            var debugNode = document.createElement("div");
            var bodyNode = new BodyClass();
            bodyNode.getNode().appendChild(debugNode);
        }

        var newNode = document.createElement("pre");
        // we want the pre to wrap: this is hard without CSS3
        // but we'll hack it for now.
        // don't use a class, so it's as self-contained as possible.
        newNode.setAttribute("style", ""
                             + "white-space: -moz-pre-wrap;"
                             // these seem to annoy firefox 1.5
                             // TODO check UA string?
                             //+ "white-space: -pre-wrap;"
                             //+ "white-space: -o-pre-wrap;"
                             //+ "white-space: pre-wrap;"
                             //+ "word-wrap: break-word;"
                             );
        newNode.appendChild(document.createTextNode("[" + new Date() + "] "
                                                    + message));
        debugNode.appendChild(newNode);
    };
}

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

var is = new BrowserIsClass();

// extend HTMLElement class
HTMLElement.prototype.removeChildNodes = function() {
    while (this.hasChildNodes()) {
        this.removeChild(this.firstChild);
    }
}

HTMLElement.prototype.hide = function() {
    this.style.display = 'none';
}

HTMLElement.prototype.show = function() {
    // TODO introspectively use block or inline
    this.style.display = 'block';
}

// Cookie functions
function setCookie(name, value, days) {
    if (name == null) {
        debug.print("setCookie: null name");
        return null;
    }
    if (value == null) {
        debug.print("setCookie: null value");
        return setCookie(name, "", days);
    }

    var path = "path=/";
    var expires = "";
    if (days != null && days) {
        var date = new Date();
        // expires in days-to-millis from now
        date.setTime( date.getTime() + (days * 24 * 3600 * 1000));
        var expires = "; expires=" + date.toGMTString();
    }

    document.cookie =
        name + "=" + encodeURIComponent(value) + expires + "; " + path;
    debug.print("setCookie: " + document.cookie);
    return null;
}

function getCookie(name) {
    if (name == null)
        return null;

    var nameEQ = name + "=";
    var ca = document.cookie.split(';');
    for (var i=0; i < ca.length; i++) {
        var c = ca[i];
        while (c.charAt(0) == ' ')
            c = c.substr(1, c.length);
        if (c.indexOf(nameEQ) == 0)
            return decodeURIComponent(c.substr(nameEQ.length, c.length));
    }
    return null;
}

function getCookiesStartingWith(name) {
    var cookies = new Array();
    var nameEQ;
    var ca = document.cookie.split(';');
    var c = null;
    var nvArray = null;
    for (var i=0; i < ca.length; i++) {
        c = ca[i];
        // skip if expires, path
        if (c.indexOf("expires=") == 0 || c.indexOf("path=") == 0) {
            continue;
        }
        // gobble whitespace
        while (c.charAt(0) == ' ')
            c = c.substr(1, c.length);
        // add matches to the array
        if (name == null || c.indexOf(name) == 0) {
            nvArray = c.split("=");
            cookies[nvArray[0]] = decodeURIComponent(nvArray[1]);
        }
    }

    return cookies;
}

function clearCookie(name) {
    // no value, and it expired yesterday
    setCookie(name, null, -1);
}

function recoverWorksheet() {
    // this approach won't work: cookies are limited to 4kB or so
    recoverQueryBuffers();
    recoverQueryHistory();
}

function recoverQueryBuffers() {
    // given a list of buffers, import them
    debug.print("recoverQueryBuffers: start");
    var bufCookie = getCookie(g_cq_buffers_cookie);
    if (bufCookie != null) {
        var buffersNode = document.getElementById(g_cq_buffers_area_id);
        debug.print("recoverQueryBuffers: " + bufCookie);
        if (! buffersNode) {
            debug.print("recoverQueryBuffers: null buffersNode");
            return;
        }
        buffersNode.innerHTML = bufCookie;
    }
}

function recoverQueryHistory() {
    // given a list of queries, put them in the history
    debug.print("recoverQueryHistory: start");
    var histCookie = getCookie(g_cq_history_cookie);
    if (histCookie != null) {
        var listNode = getQueryHistoryListNode(true);
        if (! listNode) {
            debug.print("recoverQueryHistory: null listNode");
            return;
        }
        listNode.innerHTML = histCookie;
    }
}

function cqOnLoad() {
    debug.print("cqOnLoad: begin");

    // check for debug
    var debugStatus = document.getElementById(g_cq_debug_status_id);
    if (debugStatus != null)
        debugStatus = debugStatus.value;
    if (debugStatus != null
        && debugStatus != "false" && debugStatus != "f" && debugStatus != "0") {
        debug.setEnabled(true);
    }

    //debug.print(navigator.userAgent.toLowerCase());

    // register for key-presses
    document.onkeypress = handleKeyPress;

    // recover current db from session cookie
    var currDatabase = getCookie(g_cq_eval_list_id);
    if (currDatabase != null) {
        debug.print("cqOnLoad: currDatabase = " + currDatabase);
        document.getElementById(g_cq_eval_list_id).value = currDatabase;
    }

    // recover worksheet (buffers and query history) from session cookie
    // won't work: cookies get too large
    //recoverWorksheet();

    // set the OS-specific instruction text
    setInstructionText();

    // expose the correct tabs
    refreshBufferTabs(0);

    // display the buffer list, exposing buffer 0, and focus
    refreshBufferList(0, "cqOnLoad");

    resizeFrameset();

} // cqOnLoad

function setInstructionText() {
    var instructionNode = document.getElementById(g_cq_buffer_accesskey_text);
    if (!instructionNode) {
        alert("no instruction text node!");
        return;
    }
    // if this is IE6, hide the text entirely (doesn't work)
    if (is.ie) {
        instructionNode.parentNode.hide();
        return;
    }
    var theText = "alt";
    // we only need to worry about X11 (see the comment in handleKeyPress)
    if (is.x11) {
        theText = "ctrl";
    }
    debug.print("setInstructionText: " + theText);
    instructionNode.removeChildNodes();
    instructionNode.appendChild(document.createTextNode(theText));
}

function getFrameset() {
    // get it from the parent document
    return parent.document.getElementById(g_cq_frameset_id);
}

function getQueryFrame() {
    // get it from the parent document
    return parent.document.getElementById(g_cq_query_frame_id);
} // getResultFrame

function getResultFrame() {
    // get it from the parent document
    return parent.document.getElementById(g_cq_result_frame_id);
} // getResultFrame

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
    var visible = document.getElementById(g_cq_query_form_id);
    if (visible == null) {
        // hackish
        var documentNode = window.frames[0].window.document;
        visible = documentNode.getElementById(g_cq_query_form_id);
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

function getBufferId(n) {
    if ( (! n) && (n != 0) )
        n = g_cq_buffer_current;
    return g_cq_buffer_basename + n;
}

function getBuffer(n) {
    if ( (! n) && (n != 0) )
        n = g_cq_buffer_current;
    return document.getElementById(getBufferId(n));
}

function focusQueryInput() {
    var t = getBuffer();
    if (!t)
        return;

    t.focus();
    setLineNumberStatus();
}

// normalize-space, in JavaScript
// warning: replace() isn't a regex function
// it's closer to 'tr' - character translation
function normalize(s) {
    if (s == null)
        return null;

    while (s.indexOf("\n") > -1)
        s = s.replace("\n", ' ');
    while (s.indexOf("\t") > -1)
        s = s.replace("\t", ' ');
    while (s.indexOf('  ') > -1)
        s = s.replace('  ', ' ');
    // TODO leading, trailing space? seems to work for leading, not trailing
    while (s.substr(0, 1) == " ")
        s = s.substr(1);
    while (s.length > 0 && s.substr(s.length - 1, 1) == " ")
        s = s.substr(0, s.length - 2);
    return s;
}

// create some whitespace for line breaking in the buffer labels
// TODO is there some *optional* linebreak character we could use?
// yes: should be "\A" (0x07), but that doesn't work!
function nudge(s) {
    var br = " ";
    //s = s.replace("(", "(" + br);
    //s = s.replace(")", br + ")");
    s = s.replace(",", "," + br);
    s = s.replace("=", "=" + br);
    //s = s.replace(":", ":" + br);
    //s = s.replace("/", "/" + br);
    return normalize(s);
}

function getLabel(n) {
    // get the label text for a buffer:
    var theNode = document.createElement('div');
    var theNum = null;
    var linkAction =
        "javascript:refreshBufferList(" + n + ", \"getLabel.linkAction\")";
    var linkFunction =
        function() { refreshBufferList(n, "getLabel.linkFunction") };
    var className = 'bufferlabel';
    if (g_cq_buffer_current != n) {
        // provide a link to load the buffer
        theNum = document.createElement('a');
        theNum.setAttribute('href', linkAction);
        // make the whole node active
        theNode.onclick = linkFunction;
        // set tooltip
        theNode.title = "Click to activate this query buffer.";
    } else {
        // show the current index in bold, with no link
        debug.print("getLabel: " + n + " == " + g_cq_buffer_current);
        theNum = document.createElement('b');
        className = 'bufferlabelactive';
        // set tooltip
        theNode.title = null;
    }
    theNum.appendChild(document.createTextNode("" + (1+n) + "."));
    theNode.appendChild(theNum);
    // make sure it doesn't break for huge strings
    // let the css handle text that's too large for the buffer
    // we shouldn't have to normalize spaces, but IE6 is broken
    // ...and so we have to hint word-breaks to both browsers...
    var theLabel = nudge(getBuffer(n).value.substr(0, 1024));
    // put a space here for formatting, so it won't be inside the link
    theNode.appendChild(document.createTextNode(" " + theLabel));

    // highlight the current buffer
    // IE6 doesn't like setAttribute here, but gecko accepts it
    theNode.className = className;

    // TODO mouseover for fully formatted text contents as tooltip?

    return theNode;
} // getLabel

function writeBufferLabel(parentNode, n) {
    if (! parentNode)
        return null;

    // parentNode is a table body
    var rowNode = document.createElement('tr');
    var cellNode = document.createElement('td');
    // set the text contents to label the new cell
    cellNode.appendChild(getLabel(n));

    rowNode.appendChild(cellNode);
    parentNode.appendChild(rowNode);
    return null;
}

function refreshBufferTabs(n) {
    if (n == null || n == g_cq_buffer_tabs_current)
        return;

    debug.print("refreshBufferTabs: " + n + ", " + g_cq_buffer_tabs_current);
    g_cq_buffer_tabs_current = n;

    var tabsNode = document.getElementById(g_cq_buffer_tabs_node);
    if (tabsNode == null) {
        debug.print("refreshBufferTabs: null tabsNode");
        return;
    }

    // check g_cq_buffer_tabs_current against each child span
    var buffersTitleNode =
        document.getElementById(g_cq_buffer_tabs_node + "-0");
    var historyTitleNode =
        document.getElementById(g_cq_buffer_tabs_node + "-1");
    if (!buffersTitleNode || ! historyTitleNode) {
        debug.print("refreshBufferTabs: null title node(s)");
        return;
    }

    var buffersNode = document.getElementById(g_cq_bufferlist_id);
    if (! buffersNode) {
        debug.print("refreshBufferTabs: null buffersNode");
        return;
    }

    var historyNode = document.getElementById(g_cq_history_node);
    if (! historyNode) {
        debug.print("refreshBufferTabs: null historyNode");
        return;
    }

    // simple for now: node 0 is buffer list, 1 is history
    // TODO move the instruction text too?
    if (g_cq_buffer_tabs_current == 0) {
        debug.print("refreshBufferTabs: displaying buffer list");
        // highlight the active tab
        buffersTitleNode.className = "buffer-tab-active";
        historyTitleNode.className = "buffer-tab";
        // hide and show the appropriate list
        buffersNode.show();
        historyNode.hide();
    } else {
        debug.print("refreshBufferTabs: displaying history");
        // highlight the active tab
        buffersTitleNode.className = "buffer-tab";
        historyTitleNode.className = "buffer-tab-active";

        // match the buffer height, to reduce frame-redraw
        debug.print("resizeBufferTabs: " + buffersNode.offsetTop + ", "
              + buffersNode.offsetHeight);
        historyNode.height = buffersNode.offsetHeight;

        // hide and show the appropriate list
        buffersNode.hide();
        historyNode.show();
    }
    return;
}

function refreshBufferList(n, src) {
    // display only the current buffer (textarea)
    // show labels for each buffer

    // short-circuit if the buffer doesn't exist
    if (getBuffer(n) == null)
        return;

    // labels are stored in divs in a table cell
    var labelsNode = document.getElementById(g_cq_bufferlist_id);
    labelsNode.removeChildNodes();
    // create an explicit tbody for the DOM (Mozilla needs this)
    var tableBody = document.createElement('tbody');
    labelsNode.appendChild(tableBody);

    // 0 will return false, will set to 0: ok
    if (n == null) {
        if (g_cq_buffer_current == null) {
            n = g_cq_buffer_current;
        } else {
            n = 0;
        }
    }

    g_cq_buffer_current = n;
    debug.print("refreshBufferList: from " + src + ", show " + g_cq_buffer_current);
    // parent of all the textareas
    var theParent = document.getElementById(g_cq_buffers_area_id);
    // childNodes.length will return some non-buffer elements, too!
    var theBuffer = null;
    for (var i = 0; i < theParent.childNodes.length; i++) {
        //debug.print("refreshBufferList: i = " + i + " of " + theParent.childNodes.length);
        theBuffer = getBuffer(i);
        // not there? skip it
        if (theBuffer != null) {
          writeBufferLabel(tableBody, i);
          theBuffer.hide();
          // set up handlers to update line-number display
          if (! theBuffer.onfocus)
              theBuffer.onfocus = setLineNumberStatus;
          if (! theBuffer.onclick)
              theBuffer.onclick = setLineNumberStatus;
          if (! theBuffer.onkeyup)
              theBuffer.onkeyup = setLineNumberStatus;
        }
    } // for buffers

    // show the current buffer only, and put the cursor there
    getBuffer().show();
    focusQueryInput();
} // refreshBufferList

// keycode support:
//   ctrl-ENTER for XML, alt-ENTER for HTML, shift-ENTER for text/plain
//   alt-1 to alt-0 exposes the corresponding buffer (really 0-9)
function handleKeyPress(e) {
    // handle both gecko and IE6 event models
    if (document.all) {
        e = window.event;
    }

    var theCode = e.keyCode;
    // see http://www.mozilla.org/editor/key-event-spec.html
    // for weird gecko behavior
    // see also: http://www.brainjar.com/dhtml/events/default4.asp
    if (e.charCode && e.charCode != 0) {
        theCode = e.charCode;
    }
    //var theChar = String.fromCharCode(theCode);
    var altKey = e['altKey'];
    var ctrlKey = e['ctrlKey'];
    var shiftKey = e['shiftKey'];
    var metaKey = e['metaKey'];

    // short-circuit if we obviously don't care about this keypress
    if (! (ctrlKey || altKey) ) {
        return true;
    }

    // in case we need debug info...
    var keyInfo =
        " win=" + is.win + " x11=" + is.x11 + " mac=" + is.mac + ", "
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
        var theBuffer = (theCode == 48) ? 9 : (theCode - 49);
        refreshBufferList( theBuffer, "handleKeyPress" );
        return false;
    }

    // treat ctrl-shift-s (83) and ctrl-shift-o (79) as save, load
    var theForm = document.getElementById(g_cq_query_form_id);
    if (shiftKey && ctrlKey && theCode == 83) {
        // save the buffers to the database
        cqExport(theForm);
        return false;
    }
    if (shiftKey && ctrlKey && theCode == 79) {
        // load the buffers from the database
        cqImport(theForm);
        return false;
    }
    // enter = 13
    if (theCode == 13) {
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

function setLineNumberStatus() {
    var lineStatus = document.getElementById(g_cq_textarea_status);
    if (lineStatus == null) {
        alert("null textarea_status!");
        return;
    }
    var buf = getBuffer();
    if (buf == null) {
        alert("null buffer!");
        return;
    }

    // must handle this differently for gecko vs IE6
    //debug.print("setLineNumberStatus: buf.selectionStart = "
    // + buf.selectionStart);
    if (!document.selection) {
        // gecko? is that you?
    } else {
        // set it up, using IE5+ API
        // http://msdn.microsoft.com/workshop/author/dhtml/reference/objects/obj_textrange.asp
        //debug.print("setLineNumberStatus: document.selection = "
        // + document.selection);
        if (document.selection){
            var range = document.selection.createRange();
            var storedRange = range.duplicate();
            storedRange.moveToElementText(buf);
            storedRange.setEndPoint('EndToEnd', range);
            debug.print("setLineNumberStatus: storedRange.text = '"
                        + storedRange.text + "'"
                        + " (" + storedRange.text.length
                        + "," + range.text.length
                        + "," + buf.value.length
                        + ")");
            // set start and end points, ala gecko
            buf.selectionStart = storedRange.text.length - range.text.length;
        } else {
            alert("setLineNumberStatus: no document.selection!");
            return;
        }
    }

    // now we can pretend to be gecko
    var start = buf.selectionStart;
    // figure out where start is, in the query
    var textToStart = buf.value.substr(0, start);
    var linesArray = textToStart.split(/\r\n|\r|\n/);
    var lineNumber = linesArray.length;
    // because of the earlier substr() call,
    // the last line ends at selectionStart
    var charPosition = linesArray[lineNumber - 1].length;
    // TODO: at the start of a line, firefox returns an empty string
    // meanwhile, IE6 swallows the whitespace...
    // seems to be in the selection-range API, not in split(),
    // so this workaround doesn't work!
    if (false && is.ie) {
        var start = textToStart.length - 1;
        debug.print("setLineNumberStatus: checking ie for split workaround: "
                    + start);
        var lastChar = textToStart.substr(start, 1);
        debug.print("setLineNumberStatus: checking ie for split workaround: '"
                    + lastChar + "'");
        if (lastChar == "\n") {
            lineNumber++;
            charPosition = 0;
            debug.print("setLineNumberStatus: corrected lineNumber = "
                        + lineNumber);
        }
    }
    debug.print("setLineNumberStatus:"
                + " selectionStart = " + buf.selectionStart
                + ", selectionEnd = " + buf.selectionEnd
                //+ ", textToStart = " + textToStart
                + ", lastLine = " + linesArray[lineNumber - 1]
                );
    lineStatus.innerHTML = "" + lineNumber + "," + charPosition;
}

function resizeBuffers(x, y) {
    debug.print("resizeBuffers: " + x + "," + y);
    // childNodes.length will return some non-buffer elements, too!
    var theBuffer = null;
    // parent of all the textareas
    var theParent = document.getElementById(g_cq_buffers_area_id);
    for (var i = 0; i < theParent.childNodes.length; i++) {
        theBuffer = getBuffer(i);
        // not there? skip it
        if (theBuffer != null) {
            //debug.print("resizeBuffers: " + theBuffer);
            theBuffer.cols += x;
            theBuffer.rows += y;
        }
    }
}

function disableButtons(flag) {
    // disable the form buttons
    debug.print("disableButtons: " + flag);
    var inputs = document.getElementsByTagName('INPUT');
    for (var i=0; i < inputs.length; i++) {
        if (inputs[i].type == "button") {
            debug.print("disableButtons: " + i + ": " + inputs[i].type);
            inputs[i].disabled = flag;
        }
    }
}

function submitForm(theForm, theInput, theMimeType) {
    if (! theForm) {
        alert("null form in submitForm!");
        return;
    }

    refreshBufferList(g_cq_buffer_current, "submitForm");

    // TODO would like to disable buttons during post
    // but it's too problematic for now
    if (false) {
        disableButtons(true);

        // set onload behavior to re-enable the buttons
        // TODO this works in gecko, but not IE6 - use onreadystatechange?
        // TODO how do we re-enable the buttons if the query is cancelled?
        // seems like onabort should work, but it doesn't
        // IE6 has onstop handler, but gecko doesn't
        var fSet = getFrameset();
        var qFrame = getQueryFrame();
        var rFrame = getResultFrame();
        if (!(rFrame && qFrame)) {
            debug.print("null queryFrame or resultFrame!");
        } else {
            var f = function () { disableButtons(false) };
            rFrame.onload = f;
            rFrame.onunload = f;
            rFrame.onabort = f;
            qFrame.onabort = f;
            fSet.onabort = f;
            debug.print("resultFrame.onload = " + rFrame.onload);
        }
    }

    // copy the selected eval-in args to the session cookie
    var currEval = document.getElementById(g_cq_eval_list_id).value;
    debug.print("submitForm: currEval = " + currEval);
    setCookie(g_cq_eval_list_id, currEval, 30);

    // copy current buffer to hidden element
    document.getElementById(g_cq_query_input).value = theInput;
    debug.print("submitForm: "+document.getElementById(g_cq_query_input).value);
    // set the mime type
    if (theMimeType != null) {
        debug.print("submitForm: mimeType = " + theMimeType);
        document.getElementById(g_cq_query_mime_type).value = theMimeType;
    }
    // post the form
    theForm.submit();
}

function cqExport(theForm) {
    // export store the buffer state into the value of form element g_cq_uri
    // if the g_cq_uri does not exist, we must create it in one XQuery,
    // then populate it in another
    // the simplest way is to create temporary form elements, and submit them

    // TODO export non-default options (rows, cols, etc), export them

    var theUri = document.getElementById(g_cq_uri).value;
    if (theUri) {
        var theQuery =
            'xdmp:document-insert("' + theUri + '",'
            + '<' + g_cq_buffers_area_id + ' id="' + g_cq_buffers_area_id + '">';
        // save buffers
        // childNodes.length will return some non-buffer elements, too!
        var buf = null;
        // parent of all the textareas
        var theParent = document.getElementById(g_cq_buffers_area_id);
        for (var i = 0; i < theParent.childNodes.length; i++) {
            buf = getBuffer(i);
            if (buf != null) {
                theQuery += '<' + g_cq_buffer_basename + '>'
                    // TODO xml-escape, instead?
                    + encodeURIComponent(getBuffer(i).value)
                    + '</' + g_cq_buffer_basename + '>'
                    + "\n";
            }
        }
        // save history too
        var listNode = getQueryHistoryListNode(false);
        if (!listNode) {
            debug.print("cqExport: null listNode");
        } else {
            var historyQueries = listNode.childNodes;
            var historyLength = historyQueries.length;
            for (var i = 0; i < historyLength; i++) {
                theQuery += '<' + g_cq_history_basename + '>'
                    // TODO xml-escape, instead?
                    + encodeURIComponent(historyQueries[i].firstChild.nodeValue)
                    + '</' + g_cq_history_basename + '>'
                    + "\n";
            }
        }
        theQuery += '</' + g_cq_buffers_area_id + '>)'
            + ', "exported ' + theUri + '"';
        // set the current database to null,
        // so we save to the default db?
        theDatabase = document.getElementById(g_cq_eval_list_id);
        oldDatabase = theDatabase.value;
        theDatabase.value = null;
        submitForm(theForm, theQuery, "text/html");

        debug.print("cqExport: preserving selected database " + oldDatabase);
        theDatabase.value = oldDatabase;
    } // if theUri
} // cqExport

// Submit XML Query
function submitXML(theForm) {
    submitFormWrapper(theForm, "text/xml");
}

// Submit HTML Query
function submitHTML(theForm) {
    submitFormWrapper(theForm, "text/html");
}

// Submit Text Query
function submitText(theForm) {
    submitFormWrapper(theForm, "text/plain");
}

function submitFormWrapper(theForm, mimeType) {
    debug.print("submitFormWrapper: " + theForm + " as " + mimeType);
    if (!theForm)
        return;

    var query = getBuffer().value;
    saveQueryHistory(query);

    // this approach won't work: cookie get too big
    //saveBuffersRecoveryPoint();

    submitForm(theForm, query, mimeType);
}

function clearQueryHistory() {
    var historyNode = document.getElementById(g_cq_history_node);
    if (! historyNode) {
        debug.print("clearQueryHistory: null historyNode");
        return;
    }

    historyNode.removeChildNodes();
}

function saveBuffersRecoveryPoint() {
    debug.print("saveBuffersRecoveryPoint: start");
    var buffersNode = document.getElementById(g_cq_buffers_area_id);
    debug.print("saveBuffersRecoveryPoint: " + buffersNode);
    debug.print("saveBuffersRecoveryPoint: " + buffersNode.innerHTML);

    if (! buffersNode) {
        debug.print("saveBuffersRecoveryPoint: null buffersNode");
        return;
    }

    setCookie(g_cq_buffers_cookie, buffersNode.innerHTML);
    debug.print("saveBuffersRecoveryPoint: " + getCookie(g_cq_buffers_cookie));
}

function getQueryHistoryListNode(bootstrapFlag) {
    var historyNode = document.getElementById(g_cq_history_node);
    if (! historyNode) {
        debug.print("saveQueryHistory: null historyNode");
        return null;
    }

    // history entries will be list-item elements in an ordered-list
    var listNode = historyNode.lastChild;
    if (!listNode && bootstrapFlag) {
        listNode = document.createElement("ol");
        historyNode.appendChild(listNode);
    }
    return listNode;
}

function saveQueryHistory(query, appendFlag, checkFlag) {
    if (appendFlag == null)
        appendFlag = false;
    // NOTE: if we know that there are no dups, don't check
    if (checkFlag == null)
        checkFlag = true;

    debug.print("saveQueryHistory: append=" + appendFlag
                + ", check=" + checkFlag + ": " + query.substr(0, 16));
    var listNode = getQueryHistoryListNode(true);

    // simple de-dupe check
    // abort when we see the first duplicate:
    // this is most likely to happen with the most recent query
    // also implements history limit...
    var listItems = listNode.childNodes;
    var normalizedQuery = normalize(query);
    if (query == null || query == "") {
        return;
    }

    if (checkFlag && listItems && listItems[0]) {
        debug.print("saveQueryHistory: dup-checking " + listItems.length);
        for (var i = 0; i < listItems.length; i++) {
            //debug.print("saveQueryHistory: " + i);
            if (normalize(listItems[i].childNodes[0].nodeValue)
                == normalizedQuery) {
                // we want to remove a node and then break
                listNode.removeChild(listItems[i]);
                debug.print("saveQueryHistory: " + i + " matched!");
                if (g_cq_history_limit != null && g_cq_history_limit > 0)
                    break;
            }
            if (g_cq_history_limit != null && i > g_cq_history_limit)
                listNode.removeChild(listItems[i]);
        }
    }

    var newItem = document.createElement("li");
    var queryNode = document.createElement("span");
    queryNode.appendChild(document.createTextNode(query));
    // onclick, copy to current textarea
    queryNode.onclick = function() {
         var buf = getBuffer();
         buf.value = this.childNodes[0].nodeValue;
         // don't refresh buffer list
         //refreshBufferList(g_cq_buffer_current, "saveQueryHistory");
    }
    // tool-tip
    queryNode.title = "Click here to copy this query into the current buffer.";
    newItem.appendChild(queryNode);

    // delete widget
    var deleteLink = document.createElement("span");
    deleteLink.className = "query-delete";
    deleteLink.onclick = function() {
        if (confirm("Are you sure you want to delete this history item?")) {
            this.parentNode.parentNode.removeChild(this.parentNode);
        }
        // this approach won't work: cookies get too big
        //setCookie(g_cq_history_cookie, this.parentNode.parentNode.innerHTML);
    };
    // tool-tip
    deleteLink.title = "Click here to delete this query from your history.";
    deleteLink.appendChild(document.createTextNode(" (x) "));
    newItem.appendChild(deleteLink);

    // spacing: css padding, margin don't seem to work with ol
    newItem.appendChild(document.createElement("hr"));

    // it's nice to have the most-recent at the top...
    if (listItems && listItems[0] && (!appendFlag)) {
        listNode.insertBefore(newItem, listItems[0]);
    } else {
        listNode.appendChild(newItem);
    }

    // finally, update the saved-queries cookie
    // this approach won't work: cookies get too big
    //setCookie(g_cq_history_cookie, listNode.innerHTML);

} // saveQueryHistory

// display a confirmation message
function finishImport() {
    debug.print('finishImport: checking for output');
    var theOutput = getResultFrame();
    debug.print("finishImport: theOutput = " + theOutput);
    if (theOutput == null)
        return;

    var theOutputDoc = theOutput.contentDocument;
    if (is.ie)
        theOutputDoc = theOutput.contentWindow.document;

    // no document? no results...
    if (theOutputDoc == null)
        return;

    // now check for buffers
    var theList = null;
    if (is.ie && theOutputDoc.XMLDocument) {
        debug.print("finishImport: ie, using XMLDocument");
        theList = theOutputDoc.XMLDocument.getElementsByTagName
            (g_cq_buffer_basename);
    } else {
        theList =
            theOutputDoc.getElementsByTagName(g_cq_buffer_basename);
    }

    // if we timed out, try again
    var theTimeout = null;
    if (theList == null || theList.length < 1) {
        debug.print("finishImport: no list: setting new timeout = "
                    + g_cq_timeout);
        theTimeout = setTimeout('finishImport();', g_cq_timeout);
        return;
    }
    clearTimeout(theTimeout);

    // TODO use rows, cols from imported worksheet, if present

    if (is.gecko) {
        // gecko has a problem with nodeValue longer than 4kB (encoded):
        // it creates multiple text-node children.
        // this is a DOM violation, but won't be fixed for some time.
        // see https://bugzilla.mozilla.org/show_bug.cgi?id=194231
        // workaround: call normalize() early
        debug.print("finishImport: normalizing for gecko workaround");
        theOutputDoc.normalize();
    }

    debug.print("finishImport: theList = " + theList.length);
    var theValue = null;
    for (var i = 0; i < theList.length; i++) {
        if (theList[i] == null || theList[i].firstChild == null)
            continue;

        // TODO remove decode if encode isn't needed?
        theValue = decodeURIComponent( (theList[i]).firstChild.nodeValue );
        debug.print("finishImport: buffer i = " + i + ", " + theValue.length
                    + ": " + theValue.substr(0, 16));
        getBuffer(i).value = theValue;
    } // for theList

    // import query history too, by appending
    //clearQueryHistory();
    var historyNode = document.getElementById(g_cq_history_node);
    if (! historyNode) {
        debug.print("finishImport: null historyNode");
    } else {
        var theList = theOutputDoc.getElementsByTagName(g_cq_history_basename);
        for (var i = 0; i < theList.length ; i++) {
            if (g_cq_history_limit != null && i > g_cq_history_limit)
                break;
            if (theList[i].firstChild == null)
                continue;
            // TODO remove decode if encode isn't needed?
            theValue = decodeURIComponent( (theList[i]).firstChild.nodeValue );
            saveQueryHistory(theValue, true, false);
        }
    }

    // leave the user in the same buffer
    refreshBufferList(g_cq_buffer_current, "finishImport");

    var theUri = document.getElementById(g_cq_uri).value;
    var theQuery = '<p>' + theUri + ' imported</p>';

    submitForm(document.getElementById(g_cq_query_form_id),
               theQuery, "text/html");
} // finishImport

function cqImport(theForm) {
    // load the buffer state from the uri stored in g_cq_uri
    var theUri = document.getElementById(g_cq_uri).value;
    if (! theUri)
        return;

    var theQuery = "doc('" + theUri + "')";
    var theOutput = getResultFrame();
    debug.print("cqImport: " + theQuery);
    // set the current database to null,
    // so we save to the default db
    var theDatabase = document.getElementById(g_cq_eval_list_id);
    var oldDatabase = theDatabase.value;
    theDatabase.value = null;
    submitForm(theForm, theQuery, "text/xml");
    theDatabase.value = oldDatabase;
    // read the output
    debug.print("setting import timeout to " + g_cq_timeout);
    var theTimeout = setTimeout("finishImport();", g_cq_timeout);
} // cqImport

function cqListDocuments() {
    // TODO link to display the document?
    var theForm = document.getElementById(g_cq_query_form_id);
    var theQuery =
        "let $est := xdmp:estimate(doc()) "
        + "where $est gt 1000 "
        + "return <p><b>first 1000 documents of {$est} total:</b></p>,"
        + "for $i in doc()[1 to 1000] return (base-uri($i), <br/>)";
    submitForm(theForm, theQuery, "text/html");
}

function cqListWorksheets() {
    // TODO link to load the worksheet?
    var theForm = document.getElementById(g_cq_query_form_id);
    var theQuery =
        "let $est := xdmp:estimate(/cq_buffers) "
        + "where $est gt 1000 "
        + "return <p><b>first 1000 worksheets of {$est} total:</b></p>,"
        + "for $i in (/cq_buffers)[1 to 1000] return (base-uri($i), <br/>)";
    submitForm(theForm, theQuery, "text/html");
}

// cq.js
