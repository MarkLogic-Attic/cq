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

// TODO to support incremental autosave

// GLOBAL CONSTANTS: but IE6 doesn't support "const"
var g_cq_frameset_id = "cq_frameset";
var g_cq_query_frame_id = "cq_queryFrame";
var g_cq_result_frame_id = "cq_resultFrame";
var g_cq_query_input = "/cq:query";
var g_cq_uri = "cqUri";
var g_cq_import_export_id = "cq_import_export";
var g_cq_query_form_id = "cq_form";
var g_cq_autosave_id = "cq_autosave";
var g_cq_bufferlist_id = "cq_bufferlist";
var g_cq_buffers_id = "cq_buffers";
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

// GLOBAL VARIABLES
var g_cq_buffer_tabs_current = null;
var g_cq_buffer_current = 0;
var g_cq_buffers = 10;
var g_cq_next_id = 0;
var g_cq_autosave_incremental = false;
var g_cq_timeout = 100;
var g_cq_history_limit = 50;

var DEBUG = false;

function debug(message) {
    if (! DEBUG)
        return;

    var id = "__debugNode";
    var debugNode = document.getElementById(id);
    if (debugNode == null) {
        var debugNode = document.createElement("div");
        var bodyNode = document.body;
        if (bodyNode == null) {
            bodyNode = document.createElement("body");
            document.appendChild(body);
        }
        bodyNode.appendChild(debugNode);
    }

    var newNode = document.createElement("pre");
    // we want the pre to wrap: this is hard until CSS3
    // but we'll hack it for now.
    // don't use a class: be as self-contained as possible.
    newNode.setAttribute("style",
                         "white-space: -moz-pre-wrap;"
                         + "word-wrap: break-word;"
                         + "white-space: -pre-wrap;"
                         + "white-space: -o-pre-wrap;"
                         + "white-space: pre-wrap;"
                         );
    newNode.appendChild(document.createTextNode(message));
    debugNode.appendChild(newNode);
    // just in case debugNode was present but hidden
    debugNode.style.display = "block";
}

function removeChildNodes(node) {
    while (node.hasChildNodes()) {
        node.removeChild(node.firstChild);
    }
}

function setCookie(name, value, days) {
    if (name == null) {
        debug("setCookie: null name");
        return null;
    }
    if (value == null) {
        debug("setCookie: null value");
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

    document.cookie = name + "=" + escape(value) + expires + "; " + path;
    debug("setCookie: " + document.cookie);
}

function getCookie(name) {
    if (name == null)
        return null;

    var nameEQ = name + "=";
    var ca = document.cookie.split(';');
    for (var i=0; i < ca.length; i++) {
        var c = ca[i];
        while (c.charAt(0) == ' ')
            c = c.substring(1, c.length);
        if (c.indexOf(nameEQ) == 0)
            return unescape(c.substring(nameEQ.length, c.length));
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
            c = c.substring(1, c.length);
        // add matches to the array
        if (name == null || c.indexOf(name) == 0) {
            nvArray = c.split("=");
            cookies[nvArray[0]] = unescape(nvArray[1]);
        }
    }

    return cookies;
}

function clearCookie(name) {
    // no value, and it expired yesterday
    setCookie(name, null, -1);
}


function Is () {
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

var is = new Is();

function recoverWorksheet() {
    // this approach won't work: cookies are limited to 4kB or so
    recoverQueryBuffers();
    recoverQueryHistory();
}

function recoverQueryBuffers() {
    // given a list of buffers, import them
    debug("recoverQueryBuffers: start");
    var bufCookie = getCookie(g_cq_buffers_cookie);
    if (bufCookie != null) {
        var buffersNode = document.getElementById(g_cq_buffers_id);
        debug("recoverQueryBuffers: " + bufCookie);
        if (! buffersNode) {
            debug("recoverQueryBuffers: null buffersNode");
            return;
        }
        buffersNode.innerHTML = bufCookie;
    }
}

function recoverQueryHistory() {
    // given a list of queries, put them in the history
    debug("recoverQueryHistory: start");
    var histCookie = getCookie(g_cq_history_cookie);
    if (histCookie != null) {
        var listNode = getQueryHistoryListNode(true);
        if (! listNode) {
            debug("recoverQueryHistory: null listNode");
            return;
        }
        listNode.innerHTML = histCookie;
    }
}

function cqOnLoad() {
    debug("cqOnLoad: begin");

    // check for debug
    var queryDebug = parseQuery("debug");
    if (queryDebug && queryDebug != "false" && queryDebug != "0")
        DEBUG = true;

    //debug(navigator.userAgent.toLowerCase());

    // register for key-presses
    document.onkeypress = handleKeyPress;

    // recover current db from session cookie
    var currDatabase = getCookie(g_cq_eval_list_id);
    if (currDatabase != null) {
        debug("cqOnLoad: currDatabase = " + currDatabase);
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
        hide(instructionNode.parentNode);
        return;
    }
    var theText = "alt";
    // we only need to worry about X11 (see the comment in handleKeyPress)
    if (is.x11) {
        theText = "ctrl";
    }
    debug("setInstructionText: " + theText);
    removeChildNodes(instructionNode);
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
        debug("resizeFrameset: null frameset");
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
        debug("nothing to resize from!");
        return;
    }

    debug("resizeFrameset: visible " + visible
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

// hide/show: generic functions so we always do it the same way
function hide(s) {
    if (!s)
        return;

    s.style.display = "none";
}

function show(s) {
    if (!s)
        return;

    s.style.display = "block";
}

// normalize-space, in JavaScript
// warning: replace() isn't a regex function
// it's closer to 'tr' - character translation
function normalize(s) {
    while (s.indexOf("\n") > -1)
        s = s.replace("\n", ' ');
    while (s.indexOf("\t") > -1)
        s = s.replace("\t", ' ');
    while (s.indexOf('  ') > -1)
        s = s.replace('  ', ' ');
    // TODO leading, trailing space? seems to work for leading, not trailing
    while (s.substring(0, 1) == " ")
        s = s.substring(1);
    while (s.length > 0 && s.substring(s.length - 1, 1) == " ")
        s = s.substring(0, s.length - 2);
    return s;
} // normalize

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
        // TODO set the access key and focus handler
        // doesn't seem to work: forget about it?
        //theNum.tabindex = 10 + n;
        //theNum.accesskey = n;
        //theNum.onfocus = linkFunction;
    } else {
        // show the current index in bold, with no link
        debug("getLabel: " + n + " == " + g_cq_buffer_current);
        theNum = document.createElement('b');
        className = 'bufferlabelactive';
    }
    theNum.appendChild(document.createTextNode("" + (1+n) + "."));
    theNode.appendChild(theNum);
    // make sure it doesn't break for huge strings
    // let the css handle text that's too large for the buffer
    // we shouldn't have to normalize spaces, but IE6 is broken
    // ...and so we have to hint word-breaks to both browsers...
    var theLabel = nudge(getBuffer(n).value.substring(0, 4096));
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
}

function refreshBufferTabs(n) {
    if (n == null || n == g_cq_buffer_tabs_current)
        return;

    debug("refreshBufferTabs: " + n + ", " + g_cq_buffer_tabs_current);
    g_cq_buffer_tabs_current = n;

    var tabsNode = document.getElementById(g_cq_buffer_tabs_node);
    if (tabsNode == null) {
        debug("refreshBufferTabs: null tabsNode");
        return;
    }

    // check g_cq_buffer_tabs_current against each child span
    var buffersTitleNode = document.getElementById(g_cq_buffer_tabs_node + "-0");
    var historyTitleNode = document.getElementById(g_cq_buffer_tabs_node + "-1");
    if (!buffersTitleNode || ! historyTitleNode) {
        debug("refreshBufferTabs: null title node(s)");
        return;
    }

    var buffersNode = document.getElementById(g_cq_bufferlist_id);
    if (! buffersNode) {
        debug("refreshBufferTabs: null buffersNode");
        return;
    }

    var historyNode = document.getElementById(g_cq_history_node);
    if (! historyNode) {
        debug("refreshBufferTabs: null historyNode");
        return;
    }

    // simple for now: node 0 is buffer list, 1 is history
    // TODO move the instruction text too?
    if (g_cq_buffer_tabs_current == 0) {
        debug("refreshBufferTabs: displaying buffer list");
        // highlight the active tab
        buffersTitleNode.className = "buffer-tab-active";
        historyTitleNode.className = "buffer-tab";
        // hide and show the appropriate list
        show(buffersNode);
        hide(historyNode);
    } else {
        debug("refreshBufferTabs: displaying history");
        // highlight the active tab
        buffersTitleNode.className = "buffer-tab";
        historyTitleNode.className = "buffer-tab-active";

        // match the buffer height, to reduce frame-redraw
        debug("resizeBufferTabs: " + buffersNode.offsetTop + ", " + buffersNode.offsetHeight);
        historyNode.height = buffersNode.offsetHeight;

        // hide and show the appropriate list
        hide(buffersNode);
        show(historyNode);
    }
}

function refreshBufferList(n, src) {
    // display only the current buffer (textarea)
    // show labels for each buffer
    var theBuffer = null;
    var theParent = document.getElementById(g_cq_buffers_id);
    // labels are stored in divs in a table cell
    var labelsNode = document.getElementById(g_cq_bufferlist_id);
    removeChildNodes(labelsNode);
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
    debug("refreshBufferList: from " + src + ", show " + g_cq_buffer_current);
    for (var i = 0; i < g_cq_buffers; i++) {
        //debug("refreshBufferList: i = " + i + " of " + g_cq_buffers);
        theBuffer = getBuffer(i);
        // not there? skip it
        if (theBuffer) {
          writeBufferLabel(tableBody, i);
          hide(theBuffer);
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
    show(getBuffer());
    focusQueryInput();
} // refreshBufferList

function parseQuery(key) {
    var theIdx = location.href.indexOf('?');
    if (theIdx > -1) {
        var theQuery = location.href.substring(theIdx+1);
        debug("parseQuery: " + key + ' from ' + theQuery);
        theIdx = theQuery.indexOf(key);        if (theIdx > -1) {
            // parse past the key and the '='
            var theValue = theQuery.substring(theIdx + key.length + 1);
            // stop at the terminating ';' or '&', if present
            theIdx = theValue.indexOf('&');
            if (theIdx > -1) {
                theValue = theValue.substring(0, theIdx);
            }
            theIdx = theValue.indexOf(';');
            if (theIdx > -1) {
                theValue = theValue.substring(0, theIdx);
            }
            debug("parseQuery: " + key + ' = ' + theValue);
            return unescape(theValue);
        } // if theIdx
    } // if theQuery
} // parseQuery

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
    debug("handleKeyPress: " + keyInfo);


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

    // TODO keys for textarea resize
    if (false) {
        var x = 0;
        var y = 0;
        if (theCode == 37) {
            x = -1;
        } else if (theCode == 38) {
            y = 1;
        } else if (theCode == 39) {
            x = 1;
        } else {
            // (theCode == 40)
            y = -1;
        }
        resizeBuffers(x, y);
        if (y != 0) {
            resizeFrameset();
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
    //debug("setLineNumberStatus: buf.selectionStart = " + buf.selectionStart);
    if (!document.selection) {
        // gecko? is that you?
    } else {
        // set it up, using IE5+ API
        // http://msdn.microsoft.com/workshop/author/dhtml/reference/objects/obj_textrange.asp
        //debug("setLineNumberStatus: document.selection = " + document.selection);
        if (document.selection){
            var range = document.selection.createRange();
            var storedRange = range.duplicate();
            storedRange.moveToElementText(buf);
            storedRange.setEndPoint('EndToEnd', range);
            debug("setLineNumberStatus: storedRange.text = '" + storedRange.text + "'");
            debug("setLineNumberStatus: storedRange.text.length = " + storedRange.text.length
                  + ", range.text.length=" + range.text.length
                  + ", buf.value.length = " + buf.value.length);
            // set start and end points, ala gecko
            buf.selectionStart = storedRange.text.length - range.text.length;
            //buf.selectionEnd = buf.selectionStart + range.text.length;
        } else {
            alert("setLineNumberStatus: no selectionStart or document.selection!");
            return;
        }
    }

    // now we can pretend to be gecko
    var start = buf.selectionStart;
    // figure out where start is, in the query
    var textToStart = buf.value.substr(0, start);
    var linesArray = textToStart.split(/\r\n|\r|\n/);
    var lineNumber = linesArray.length;
    // because of the earlier substring() call,
    // the last line ends at selectionStart
    var charPosition = linesArray[lineNumber - 1].length;
    // TODO: at the start of a line, firefox returns an empty string
    // meanwhile, IE6 swallows the whitespace...
    // seems to be in the selection-range API, not in split(),
    // so this workaround doesn't work!
    if (false && is.ie) {
        var start = textToStart.length - 1;
        debug("setLineNumberStatus: checking ie for split workaround: " + start);
        var lastChar = textToStart.substr(start, 10);
        debug("setLineNumberStatus: checking ie for split workaround: '" + lastChar + "'");
        if (lastChar == "\n") {
            lineNumber++;
            charPosition = 0;
            debug("setLineNumberStatus: corrected lineNumber = " + lineNumber);
        }
    }
    debug("setLineNumberStatus:"
          + " selectionStart = " + buf.selectionStart
          + ", selectionEnd = " + buf.selectionEnd
          + ", textToStart = " + textToStart
          + ", lastLine = " + linesArray[lineNumber - 1]
          );
    lineStatus.innerHTML = "" + lineNumber + "," + charPosition;
}

function resizeBuffers(x, y) {
    debug("resizeBuffers: " + x + "," + y);
    for (var i = 0; i < g_cq_buffers; i++) {
        theBuffer = getBuffer(i);
        // not there? skip it
        if (theBuffer) {
            //debug("resizeBuffers: " + theBuffer);
            theBuffer.cols += x;
            theBuffer.rows += y;
        }
    }
}

function disableButtons(flag) {
    // disable the form buttons
    debug("disableButtons: " + flag);
    var inputs = document.getElementsByTagName('INPUT');
    for (var i=0; i < inputs.length; i++) {
        if (inputs[i].type == "button") {
            debug("disableButtons: " + i + ": " + inputs[i].type);
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
            debug("null queryFrame or resultFrame!");
        } else {
            var f = function () { disableButtons(false) };
            rFrame.onload = f;
            rFrame.onunload = f;
            rFrame.onabort = f;
            qFrame.onabort = f;
            fSet.onabort = f;
            debug("resultFrame.onload = " + rFrame.onload);
        }
    }

    // copy the selected eval-in args to the session cookie
    var currEval = document.getElementById(g_cq_eval_list_id).value;
    debug("submitForm: currEval = " + currEval);
    setCookie(g_cq_eval_list_id, currEval, 30);

    // copy current buffer to hidden element
    document.getElementById(g_cq_query_input).value = theInput;
    debug("submitForm: "+document.getElementById(g_cq_query_input).value);
    // set the mime type
    if (theMimeType != null) {
        debug("submitForm: mimeType = " + theMimeType);
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
    var theUri = document.getElementById(g_cq_uri).value;
    if (theUri) {
        var theQuery =
            'xdmp:document-insert("' + theUri + '",'
            + '<' + g_cq_buffers_id + ' id="' + g_cq_buffers_id + '">';
        // save buffers
        for (var i = 0; i < g_cq_buffers; i++) {
            theQuery += '<' + g_cq_buffer_basename + '>'
                + escape(getBuffer(i).value)
                + '</' + g_cq_buffer_basename + '>'
                + "\n";
        }
        // save history too
        var listNode = getQueryHistoryListNode(false);
        if (!listNode) {
            debug("cqExport: null listNode");
        } else {
            var historyQueries = listNode.childNodes;
            var historyLength = historyQueries.length;
            for (var i = 0; i < historyLength; i++) {
                theQuery += '<' + g_cq_history_basename + '>'
                    + escape(historyQueries[i].firstChild.nodeValue)
                    + '</' + g_cq_history_basename + '>'
                    + "\n";
            }
        }
        theQuery += '</' + g_cq_buffers_id + '>)'
            + ', "exported ' + theUri + '"';
        // set the current database to null,
        // so we save to the default db?
        theDatabase = document.getElementById(g_cq_eval_list_id);
        oldDatabase = theDatabase.value;
        theDatabase.value = null;
        submitForm(theForm, theQuery, "text/html");

        debug("cqExport: preserving selected database " + oldDatabase);
        theDatabase.value = oldDatabase;
    } // if theUri
} // cqExport

// TODO seems to be buggy, still
function cqAutoSave(n) {
    // use incremental updates if autosave form element is set
    // and the incremental flag is true (has already been exported)
    var theFlag = document.getElementById(g_cq_autosave_id);
    debug("cqAutoSave: " + theFlag.checked);
    if (theFlag.checked) {
        if (! g_cq_autosave_incremental) {
            // this session hasn't been exported, as far as we know:
            // export it, then mark it ok for incremental
            cqExport(document.getElementById(g_cq_query_form_id));
            g_cq_autosave_incremental = true;
        } else {
            debug("cqAutoSave: incremental");
            var theForm = document.getElementById(g_cq_query_form_id);
            var theUri = document.getElementById(g_cq_uri).value;
            if (theForm && theUri) {
                // default to current buffer
                if ( (!n) && (n != 0) )
                    n = g_cq_buffer_current;
                var theQuery =
                    'xdmp:node-replace((doc("' + theUri + '")/'
                    // path to buffer n
                    + g_cq_buffers_id + '/'
                    // XPath starts at 1, not 0
                    + g_cq_buffer_basename + ')[' + (1+n) + "],\n"
                    // new value
                    + '<' + g_cq_buffer_basename + '>'
                    + escape(getBuffer(n).value)
                    + '</' + g_cq_buffer_basename + '>'
                    + '), "updated"';
                debug("cqAutoSave: " + theQuery);
                submitForm(theForm, theQuery, "text/html");
            } // theForm and theUri
        } // if incremental
    } // if autosave
} // cqAutoSave

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
    debug("submitFormWrapper: " + theForm + " as " + mimeType);
    if (!theForm)
        return;

    //cqAutoSave();
    var query = getBuffer().value;
    saveQueryHistory(query);

    // this approach won't work: cookie get too big
    //saveBuffersRecoveryPoint();

    submitForm(theForm, query, mimeType);
}

function clearQueryHistory() {
    var historyNode = document.getElementById(g_cq_history_node);
    if (! historyNode) {
        debug("clearQueryHistory: null historyNode");
        return;
    }

    removeChildNodes(historyNode);
}

function saveBuffersRecoveryPoint() {
    debug("saveBuffersRecoveryPoint: start");
    var buffersNode = document.getElementById(g_cq_buffers_id);
    debug("saveBuffersRecoveryPoint: " + buffersNode);
    debug("saveBuffersRecoveryPoint: " + buffersNode.innerHTML);

    if (! buffersNode) {
        debug("saveBuffersRecoveryPoint: null buffersNode");
        return;
    }

    setCookie(g_cq_buffers_cookie, buffersNode.innerHTML);
    debug("saveBuffersRecoveryPoint: " + getCookie(g_cq_buffers_cookie));
}

function getQueryHistoryListNode(bootstrapFlag) {
    var historyNode = document.getElementById(g_cq_history_node);
    if (! historyNode) {
        debug("saveQueryHistory: null historyNode");
        return;
    }

    // history entries will be list-item elements in an ordered-list
    var listNode = historyNode.lastChild;
    if (!listNode && bootstrapFlag) {
        listNode = document.createElement("ol");
        historyNode.appendChild(listNode);
    }
    return listNode;
}

function saveQueryHistory(query, appendFlag) {
    debug("saveQueryHistory: " + query);
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

    if (listItems && listItems[0]) {
        debug("saveQueryHistory: checking " + listItems.length);
        for (var i = 0; i < listItems.length; i++) {
            debug("saveQueryHistory: " + i);
            if (normalize(listItems[i].childNodes[0].nodeValue) == normalizedQuery) {
                // we want to remove a node and then break
                listNode.removeChild(listItems[i]);
                debug("saveQueryHistory: " + i + " matched!");
                if (g_cq_history_limit != null && g_cq_history_limit > 0)
                    break;
            }
            if (g_cq_history_limit != null && i > g_cq_history_limit)
                listNode.removeChild(listItems[i]);
        }
    }

    var newItem = document.createElement("li");
    newItem.appendChild(document.createTextNode(query));
    // onclick, copy to current textarea
    newItem.onclick = function() {
         var buf = getBuffer();
         buf.value = this.childNodes[0].nodeValue;
         // don't refresh buffer list
         //refreshBufferList(g_cq_buffer_current, "saveQueryHistory");
    }

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
    debug('finishImport');
    var theOutput = getResultFrame();
    var theOutputDoc = null;
    debug("theOutput = " + theOutput);
    if (theOutput) {
        if (is.ie) {
            theOutputDoc = theOutput.contentWindow.document;
        } else {
            theOutputDoc = theOutput.contentDocument;
        }

        if (theOutputDoc) {
            var theList =
                theOutputDoc.getElementsByTagName(g_cq_buffer_basename);
            if (is.ie && theOutputDoc.XMLDocument) {
                theList = theOutputDoc.XMLDocument.getElementsByTagName
                    (g_cq_buffer_basename);
            } // is.ie
            var theTimeout = null;
            // if we timed out, try again
            if (theList.length < 1) {
              debug("no list: setting new timeout " + g_cq_timeout);
              theTimeout = setTimeout('finishImport();', g_cq_timeout);
              return null;
            }
            clearTimeout(theTimeout);

            debug("theList = " + theList + ", length = " + theList.length);
            var theValue = null;
            for (var i = 0; i < theList.length; i++) {
                if (theList[i].firstChild == null)
                    continue;
                theValue = unescape( (theList[i]).firstChild.nodeValue );
                debug("i = " + i + ", " + theValue);
                getBuffer(i).value = theValue;
            } // for theList

            // import query history too, by appending
            //clearQueryHistory();
            var historyNode = document.getElementById(g_cq_history_node);
            if (! historyNode) {
                debug("cqImport: null historyNode");
            } else {
                var list = theOutputDoc.getElementsByTagName(g_cq_history_basename);
                for (var i = 0; i < list.length ; i++) {
                  if (g_cq_history_limit != null && i > g_cq_history_limit)
                      break;
                  if (list[i].firstChild == null)
                      continue;
                  theValue = unescape( (list[i]).firstChild.nodeValue );
                  saveQueryHistory(theValue, true);
                }
            }

            // leave the user in the same buffer
            refreshBufferList(g_cq_buffer_current, "finishImport");

            var theUri = document.getElementById(g_cq_uri).value;
            var theQuery = '<p>' + theUri + ' imported</p>';
            submitForm(document.getElementById(g_cq_query_form_id),
                       theQuery, "text/html");
        } // if theOutputDoc
    } // if theOutput
} // finishImport

function cqImport(theForm) {
    // load the buffer state from the uri stored in g_cq_uri
    var theUri = document.getElementById(g_cq_uri).value;
    if (! theUri)
        return;

    var theQuery = "doc('" + theUri + "')";
    var theOutput = getResultFrame();
    debug("cqImport: " + theQuery);
    // set the current database to null,
    // so we save to the default db
    theDatabase = document.getElementById(g_cq_eval_list_id);
    oldDatabase = theDatabase.value;
    theDatabase.value = null;
    submitForm(theForm, theQuery, "text/xml");
    theDatabase.value = oldDatabase;
    // read the output
    debug("setting import timeout to " + g_cq_timeout);
    var theTimeout = setTimeout("finishImport();", g_cq_timeout);
} // cqImport

function cqListBuffers() {
    var theForm = document.getElementById(g_cq_query_form_id);
    var theQuery =
        "let $est := xdmp:estimate(doc()) "
        + "where $est gt 1000 "
        + "return <p><b>first 1000 documents of {$est} total:</b></p>,"
        + "for $i in input()[1 to 1000] return (base-uri($i), <br/>)";
    submitForm(theForm, theQuery, "text/html");
} // cqListBuffers

// cq.js
