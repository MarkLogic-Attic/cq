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
var g_cq_database_list_id = "/cq:database";
var g_cq_query_mime_type = "/cq:mime-type";
var g_cq_query_action = "cq-eval.xqy";

// GLOBAL VARIABLES
var g_cq_buffer_current = 0;
var g_cq_buffers = 10;
var g_cq_next_id = 0;
var g_cq_autosave_incremental = false;
var g_cq_timeout = 750;

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
    var agt=navigator.userAgent.toLowerCase();

    this.major = parseInt(navigator.appVersion);
    this.minor = parseFloat(navigator.appVersion);

    this.nav  = ((agt.indexOf('mozilla') != -1)
                 && ((agt.indexOf('spoofer') == -1)
                     &&  (agt.indexOf('compatible') == -1)));

    this.gecko = (this.nav
                  && (agt.indexOf('gecko') != -1));

    this.ie   = (agt.indexOf("msie") != -1);
} // Is

var is = new Is();

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
    // add a smidgen for fudge-factor:
    // 15px is enough for gecko, but IE6 wants 20px
    rows = 20 + visible.offsetTop + visible.offsetHeight;
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
    var linkAction = "javascript:refreshBufferList(" + n + ")";
    if (g_cq_buffer_current != n) {
        // provide a link to load the buffer
        theNum = document.createElement('a');
        theNum.setAttribute('href', linkAction);
    } else {
        // show the current index in bold, with no link
        debug("getLabel: " + n + ", " + g_cq_buffer_current);
        theNum = document.createElement('b');
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
    var className = 'bufferlabel';
    if (g_cq_buffer_current == n) {
        className = 'bufferlabelactive';
    }
    // IE6 doesn't like setAttribute here, but gecko accepts it
    theNode.className = className;

    // TODO mouseover for fully formatted text contents as tooltip?

    // make the whole thing active
    // TODO doesn't work in IE6!
    theNode.setAttribute('onclick', linkAction);

    return theNode;
} // getLabel

function writeBufferLabel(parentNode, n) {
    if (! parentNode)
        return null;

    // parentNode is a table
    var rowNode = document.createElement('tr');
    var cellNode = document.createElement('td');
    // set the text contents to label the new cell
    cellNode.appendChild(getLabel(n));

    rowNode.appendChild(cellNode);
    parentNode.appendChild(rowNode);
} // writeBufferLabel

function refreshBufferList(n) {
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
    if (! n)
        n = 0;
    g_cq_buffer_current = n;
    debug("refreshBufferList: " + g_cq_buffer_current);
    for (var i = 0; i < g_cq_buffers; i++) {
        debug("refreshBufferList: i = " + i + " of " + g_cq_buffers);
        theBuffer = getBuffer(i);
        // not there? skip it
        if (theBuffer) {
          writeBufferLabel(tableBody, i);
          hide(theBuffer);
        }
    } // for buffers
    // show the current buffer only
    debug("refreshBufferList: show " + g_cq_buffer_current);
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

function cqOnLoad() {
    debug("cqOnLoad: begin");

    // register for key-presses
    document.onkeypress = handleKey;

    // focusing on the form doesn't seem to be necessary
    //var x = document.getElementById(g_cq_query_form_id);
    // display the buffer list, exposing buffer 0

    // recover current db from session cookie
    var currDatabase = getCookie(g_cq_database_list_id);
    if (currDatabase != null) {
        debug("cqOnLoad: currDatabase = " + currDatabase);
        document.getElementById(g_cq_database_list_id).value = currDatabase;
    }

    refreshBufferList(0);

    resizeFrameset();

} // cqOnLoad

// keycode support:
//   ctrl-ENTER for XML, alt-ENTER for HTML, shift-ENTER for text/plain
//   alt-1 to alt-0 exposes the corresponding buffer (really 0-9)
function handleKey(e) {
    // handle both gecko and IE6
    if (!e)
      e = window.event;
    var keyInfo = String.fromCharCode(e.keyCode) + '\n';
    var theCode = e['keyCode'];
    var theForm = document.getElementById(g_cq_query_form_id);
    // treat ctrl-alt-s (83) and ctrl-alt-o (79) as save, load
    if (e['shiftKey'] && e['ctrlKey'] && theCode == 83) {
        // save the buffers to the database
        cqExport(theForm);
        return false;
    }
    if (e['shiftKey'] && e['ctrlKey'] && theCode == 79) {
        // load the buffers from the database
        cqImport(theForm);
        return false;
    }
    // enter = 13
    if (theCode == 13 && (e['ctrlKey'] || e['altKey'] || e['shiftKey']) ) {
        if (e['ctrlKey'] && e['shiftKey']) {
            submitText(theForm);
        } else if (e['altKey']) {
            submitHTML(theForm);
        } else {
            // must be ctrl
            submitXML(theForm);
        }
        return false;
    }

    // 1 = 49, 9 = 57, 0 = 48
    if ( e['altKey'] && (theCode >= 49) && (theCode <= 57) ) {
        // expose the corresponding buffer: 0-8
        refreshBufferList(theCode - 49);
        return false;
    }
    if ( e['altKey'] && (theCode == 48) ) {
        // expose the corresponding buffer: 0 => 9
        refreshBufferList(9);
        return false;
    }

    // ignore other keys
    return true;
} // handleKey

function submitForm(theForm, theInput, theMimeType) {
    if (! theForm)
        return;

    refreshBufferList(g_cq_buffer_current);

    // copy the selected database to the session cookie
    var currDatabase = document.getElementById(g_cq_database_list_id).value;
    debug("submitForm: currDatabase = " + currDatabase);
    setCookie(g_cq_database_list_id, currDatabase, 30);

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
    return;
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
        theDatabase = document.getElementById(g_cq_database_list_id);
        oldDatabase = theDatabase.value;
        theDatabase.value = null;
        submitForm(theForm, theQuery, "text/html");
        // TODO restore the user's chosen db
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
    debug("submitXML");
    if (theForm) {
        //cqAutoSave();
        submitForm(theForm, getBuffer().value, "text/xml");
    }
} // submitXML

// Submit HTML Query
function submitHTML(theForm) {
    debug("submitHTML");
    if (theForm) {
        //cqAutoSave();
        submitForm(theForm, getBuffer().value, "text/html");
    }
} // submitHTML

// Submit Text Query
function submitText(theForm) {
    debug("submitText");
    if (theForm) {
        //cqAutoSave();
        submitForm(theForm, getBuffer().value, "text/plain");
    }
} // submitText

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
            if (theList.length < 1)
                theTimeout = setTimeout('finishImport();', g_cq_timeout);
            clearTimeout(theTimeout);

            debug("theList = " + theList + ", length = " + theList.length);
            var theValue = null;
            for (var i = 0; i < theList.length; i++) {
                theValue = unescape( (theList[i]).firstChild.nodeValue );
                debug("i = " + i + ", " + theValue);
                getBuffer(i).value = theValue;
            } // for theList

            // leave the user in the same buffer
            refreshBufferList(g_cq_buffer_current);
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
    theDatabase = document.getElementById(g_cq_database_list_id);
    oldDatabase = theDatabase.value;
    theDatabase.value = null;
    submitForm(theForm, theQuery, "text/xml");
    theDatabase.value = oldDatabase;
    // read the output
    var theTimeout = setTimeout("finishImport();", g_cq_timeout);
} // cqImport

function cqListBuffers() {
    var theForm = document.getElementById(g_cq_query_form_id);
    var theQuery = "for $i in input() return (document-uri($i), <br/>)";
    submitForm(theForm, theQuery, "text/html");
} // cqListBuffers

// cq.js
