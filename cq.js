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

// TODO mark incremental false on change to uri
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
var g_cq_eval_list_id = "/cq:eval-in";
var g_cq_query_mime_type = "/cq:mime-type";
var g_cq_query_action = "cq-eval.xqy";
var g_cq_buffer_accesskey_text = "cq_buffer_accesskey_text";
var g_cq_history_node = "/cq:history";

// GLOBAL VARIABLES
var g_cq_buffer_current = 0;
var g_cq_buffers = 10;
var g_cq_next_id = 0;
var g_cq_autosave_incremental = false;
var g_cq_timeout = 100;

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
    if (name == null)
        return null;
    if (value == null)
        return setCookie(name, "", days);

    var path = "path=/";
    var expires = "";
    if (days != null && days) {
        var date = new Date();
        // expires in days-to-millis from now
        date.setTime( date.getTime() + (days * 24 * 3600 * 1000));
        var expires = "; expires=" + date.toGMTString();
    }

    document.cookie = name + "=" + value + expires + "; " + path;
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
            return c.substring(nameEQ.length, c.length);
    }
    return null;
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
} // Is

var is = new Is();

function cqOnLoad() {
    debug("cqOnLoad: begin");

    // check for debug
    var queryDebug = parseQuery("debug");
    if (queryDebug && queryDebug != "false" && queryDebug != "0")
        DEBUG = true;

    //debug(navigator.userAgent.toLowerCase());

    // register for key-presses
    document.onkeypress = handleKey;

    // recover current db from session cookie
    var currDatabase = getCookie(g_cq_eval_list_id);
    if (currDatabase != null) {
        debug("cqOnLoad: currDatabase = " + currDatabase);
        document.getElementById(g_cq_eval_list_id).value = currDatabase;
    }

    // set the OS-specific instruction text
    setInstructionText();

    // display the buffer list, exposing buffer 0
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
    // we only need to worry about X11 (see the comment in handleKey)
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
} // getBufferId

function getBuffer(n) {
    if ( (! n) && (n != 0) )
        n = g_cq_buffer_current;
    return document.getElementById(getBufferId(n));
} // getBuffer

function focusQueryInput() {
    var t = getBuffer();
    if (t)
        t.focus();
} // focusQueryInput

// hide/show: generic functions so we always do it the same way
function hide(s) {
    if (s)
        s.style.display = "none";
} // hide

function show(s) {
    if (s)
        s.style.display = "block";
} // show

// normalize-space, in JavaScript
function normalize(s) {
    while (s.indexOf("\r") > -1)
        s = s.replace("\r", ' ');
    while (s.indexOf("\n") > -1)
        s = s.replace("\n", ' ');
    while (s.indexOf("\t") > -1)
        s = s.replace("\t", ' ');
    while (s.indexOf('  ') > -1)
        s = s.replace('  ', ' ');
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
        theIdx = theQuery.indexOf(key);
        if (theIdx > -1) {
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
function handleKey(e) {
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

    // in case we need debug info...
    var keyInfo =
        " win=" + is.win + " x11=" + is.x11 + " mac=" + is.mac + ", "
        + (metaKey ? "meta " : "")
        + (ctrlKey ? "ctrl " : "") + (shiftKey ? "shift " : "")
        + (altKey ? "alt " : "") + theCode;
    // short-circuit if we obviously don't care about this keypress
    if (! (ctrlKey || altKey)) {
        return true;
    }
    debug("handleKey: " + keyInfo);

    // handle buffers: 1 = 49, 9 = 57, 0 = 48
    // ick: firefox-linux decided to use alt 0-9 for tabs
    //   win32 uses ctrl, macos uses meta.
    // So we accept either ctrl or alt:
    // the browser will swallow anything that it doesn't want us to see.
    if ( (theCode >= 48) && (theCode <= 57) ) {
        // expose the corresponding buffer: 0-9
        var theBuffer = (theCode == 48) ? 9 : (theCode - 49);
        refreshBufferList( theBuffer, "handleKey" );
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

    // arrow keys, for textarea resize
    // 37=left, 38=up, 39=right, 40=down
    if (theCode >= 37 && theCode <= 40) {
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
} // handleKey

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

    // TODO too problematic for now
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
        for (var i = 0; i < g_cq_buffers; i++) {
            theQuery += '<' + g_cq_buffer_basename + '>'
                + escape(getBuffer(i).value)
                + '</' + g_cq_buffer_basename + '>'
                + "\n";
        } // for buffers
        theQuery += '</' + g_cq_buffers_id + '>)'
            + ', "exported ' + theUri + '"';
        // set the current database to null,
        // so we save to the default db
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
    submitForm(theForm, query, mimeType);
}

function saveQueryHistory(query) {
    debug("saveQueryHistory: " + query);
    var historyNode = document.getElementById(g_cq_history_node);
    if (! historyNode) {
        return;
    }

    // should this be a select list?
    // what about an iframe with a hide-show widget?
    // more room for full queries, that way... also delete widget
    // TODO save history as part of the worksheet?
    var selectNode = historyNode.lastChild;
    if (!selectNode) {
        historyNode.appendChild(document.createTextNode("history: "));
        selectNode = document.createElement("select");
        historyNode.appendChild(selectNode);
        selectNode.onchange = function() {
            // copy selected option to current textarea
            // note that this will overwrite the current query
            var buf = getBuffer();
            buf.value =
              selectNode.childNodes[selectNode.selectedIndex].value;
            refreshBufferList(g_cq_buffer_current, "saveQueryHistory");
        };
    }

    // simple de-dupe check
    // abort when we see the first duplicate:
    // this is most likely to happen with the most recent query
    var optionsList = selectNode.childNodes;
    if (optionsList && optionsList[0]) {
        debug("saveQueryHistory: checking " + optionsList.length);
        for (var i = 0; i < optionsList.length; i++) {
            debug("saveQueryHistory: " + i);
            if (optionsList[i].value == query) {
                // we want to remove a node and then break
                selectNode.removeChild(optionsList[i]);
                debug("saveQueryHistory: " + i + " matched!");
                break;
            }
        }
    }

    var newOption = document.createElement("option");
    newOption.value = query;

    // should we abbreviate the query somehow?
    newOption.appendChild(document.createTextNode(normalize(query)));

    // it's nice to have the most-recent at the top...
    if (optionsList && optionsList[0]) {
        selectNode.insertBefore(newOption, optionsList[0]);
    } else {
        selectNode.appendChild(newOption);
    }

    // select the topmost option: IE6 and gecko work a bit differently
    newOption.selected = true;
    selectNode.selectedIndex = 0;

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
                theValue = unescape( (theList[i]).firstChild.nodeValue );
                debug("i = " + i + ", " + theValue);
                getBuffer(i).value = theValue;
            } // for theList

            // leave the user in the same buffer
            refreshBufferList(g_cq_buffer_current, "finishImport");
            //clearTimeout(theTimeout);
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
    var theQuery = "for $i in input() return (document-uri($i), <br/>)";
    submitForm(theForm, theQuery, "text/html");
} // cqListBuffers

// cq.js
