// Copyright (c)2003, 2004 Mark Logic Corporation
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
// Copyright (c) 2003, 2004 Mark Logic Corporation. All rights reserved.
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
var g_cq_query_frame = "cq_queryFrame";
var g_cq_result_frame = "cq_resultFrame";
var g_cq_query_input = "queryInput";
var g_cq_uri = "cqUri";
var g_cq_import_export_id = "cq_import_export";
var g_cq_query_form = "cq_form";
var g_cq_autosave_id = "cq_autosave";
var g_cq_bufferlist_id = "cq_bufferlist";
var g_cq_buffers_id = "cq_buffers";
var g_cq_buffer_basename = "cq_buffer";
var g_cq_database_list = "/cq:database";
var g_cq_query_mime_type = "cq_mimeType";
var g_cq_query_action = "cq-eval.xqy";

// GLOBAL VARIABLES
var g_cq_buffer_current = 0;
var g_cq_buffers = 10;
var g_cq_next_id = 0;
var g_cq_autosave_incremental = false;
var g_cq_timeout = 250;

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

function getResultFrame() {
    var theFrame =
        // if the result frame is an iframe, get it from the current document
        //document.getElementById(g_cq_result_frame);
        // if the result frame is in a frameset, get it from the parent document
        parent.document.getElementById(g_cq_result_frame);
    return theFrame;
} // getResultFrame

function resizeResultFrame() {
    var theFrame = getResultFrame();
    var theBody     =       null;
    // try to set the iframe height to match the available space
    if (is.ie) {
        theBody = theFrame.document.body;
        theFrame.style.height =
            theBody.scrollHeight + (theBody.offsetHeight - theBody.clientHeight);
    } else {
        //alert("old frame = " + theFrame.height);
        // XXX how does gecko handle this?
        // XXX handle both XML and XHTML content...
        // seems to be stored in "Anonymous Content", which isn't in the DOM
        //theOutputDoc = theOutput.contentDocument;
        //var theList = theOutputDoc.getElementsByTagName(g_cq_buffer_basename);
        //theBody = theFrame.contentDocument.getElementById("top");
        //alert("body len = " + theBody);
        //theFrame.height =
        //theBody.scrollHeight + (theBody.offsetHeight - theBody.clientHeight);
        //alert("new = " + theFrame.style.height);
    } // is ie
} // resizeResultFrame

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

function normalize(s) {
    while (s.indexOf("\r") > -1)
        s = s.replace("\r", ' ');
    while (s.indexOf("\n") > -1)
        s = s.replace("\n", ' ');
    while (s.indexOf('  ') > -1)
        s = s.replace('  ', ' ');
    return s;
} // normalize

function getLabel(n) {
    // get the label text for a buffer:
    var theNode = document.createElement('span');
    theNode.setAttribute('class', 'code1');
    var theNum = null;
    if (g_cq_buffer_current != n) {
        // provide a link to load the buffer
        theNum = document.createElement('a');
        theNum.setAttribute('href', "javascript:refreshBufferList(" + n + ")");
        theNum.appendChild(document.createTextNode("" + (1+n) + "."));
    } else {
        // show the current index in bold
        //alert("getLabel: " + n + ", " + g_cq_buffer_current);
        theNum = document.createElement('b');
        theNum.appendChild(document.createTextNode("" + (1+n) + "."));
    }
    theNode.appendChild(theNum);
    // write the first 30 chars of the buffer to the label
    theNode.appendChild(document.createTextNode
                        (" " + normalize(getBuffer(n).value).substring(0, 29)));
    return theNode;
} // getLabel

function writeBufferLabel(n) {
    // labels are stored in a table, one per row
    var theTable = document.getElementById(g_cq_bufferlist_id);
    // make sure the table has a tbody
    if (theTable.childNodes.length < 1) {
        // create an explicit tbody for the DOM (Mozilla needs this)
        theTable.appendChild(document.createElement('tbody'));
    }
    if (theTable) {
        var theTableBody = theTable.firstChild;
        var theRow = theTable.rows[n];
        if (! theRow) {
            //alert("writeBufferLabel: appending at " + n);
            theRow = document.createElement('tr');
            theTableBody.appendChild(theRow);
        }
        //alert("writeBufferLabel("+n+"): was=" + theCell);
        while (theRow.hasChildNodes()) {
            theRow.removeChild(theRow.firstChild);
        }
        var theCell = document.createElement('td');
        while (theCell.hasChildNodes()) {
            theCell.removeChild(theCell.firstChild);
        }
        theRow.appendChild(theCell);
        // highlight the
        if (g_cq_buffer_current == n) {
            theCell.setAttribute('bgcolor', '#aaddff'); // gecko
            theCell.style.background = '#aaddff'; // ie
        }
        theCell.appendChild(getLabel(n));
    } // if theTable
} // writeBufferLabel

function refreshBufferList(n) {
    // display only the current buffer (textarea)
    // show labels for each buffer
    var theBuffer = null;
    var theParent = document.getElementById(g_cq_buffers_id);
    // 0 will return false, will set to 0: ok
    if (! n)
        n = 0;
    g_cq_buffer_current = n;
    //alert("refreshBufferList: " + g_cq_buffer_current);
    for (var i = 0; i < g_cq_buffers; i++) {
        //alert("refreshBufferList: i = " + i + " of " + g_cq_buffers);
        theBuffer = getBuffer(i);
        // not there? skip it
        if (theBuffer) {
          //alert("refreshBufferList: i = " + i + " fontFamily = " + theBuffer.style.fontFamily);
          writeBufferLabel(i);
          hide(theBuffer);
        }
    } // for buffers
    // show the current buffer only
    //alert("refreshBufferList: show " + g_cq_buffer_current);
    show(getBuffer());
    focusQueryInput();
} // refreshBufferList

function parseQuery(key) {
    var theIdx = location.href.indexOf('?');
    if (theIdx > -1) {
        var theQuery = location.href.substring(theIdx+1);
        //alert("parseQuery: " + key + ' from ' + theQuery);
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
            //alert("parseQuery: " + key + ' = ' + theValue);
            return unescape(theValue);
        } // if theIdx
    } // if theQuery
} // parseQuery

function cqOnLoad() {
    //alert("cqOnLoad");

    // register for key-presses
    document.onkeyup = handleKey;
    // focusing on the form doesn't seem to be necessary
    //var x = document.getElementById(g_cq_query_form);
    // display the buffer list, exposing buffer 0
    refreshBufferList(0);
} // cqOnLoad

// keycode support:
//   ctrl-ENTER for XML, alt-ENTER for HTML, shift-ENTER for text/plain
//   alt-1 to alt-0 exposes the corresponding buffer (really 0-9)
function handleKey(e) {
    if (!e)
      e = window.event;
    var keyInfo = String.fromCharCode(e.keyCode) + '\n';
    var theCode = e['keyCode'];
    var theForm = document.getElementById(g_cq_query_form);
    //alert("key=" + theCode + " shift=" + e['shiftKey'] + " alt=" + e['altKey'] + " ctrl=" + e['ctrlKey']);
    // treat ctrl-alt-s (83) and ctrl-alt-o (79) as save, load
    if (e['shiftKey'] && e['ctrlKey'] && theCode == 83) {
        // save the buffers to the database
        cqExport(theForm);
        return;
    }
    if (e['shiftKey'] && e['ctrlKey'] && theCode == 79) {
        // load the buffers from the database
        cqImport(theForm);
        return;
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
        return;
    } // if submitKey
    // 1 = 49, 9 = 57, 0 = 48
    if ( e['altKey'] && (theCode >= 49) && (theCode <= 57) ) {
        // expose the corresponding buffer: 0-8
        refreshBufferList(theCode - 49);
        return;
    } // if alt + 1-9
    if ( e['altKey'] && (theCode == 48) ) {
        // expose the corresponding buffer: 0 => 9
        refreshBufferList(9);
        return;
    } // alt + 0
    // ignore other keys
} // handleKey

function submitForm(theForm, theInput, theMimeType) {
    if (! theForm) {
        return;
    }
    refreshBufferList(g_cq_buffer_current);
    // copy current buffer to hidden element
    document.getElementById(g_cq_query_input).value = theInput;
    //alert("submitForm: "+document.getElementById(g_cq_query_input).value);
    // set the mime type
    if (theMimeType != null) {
        //alert("submitForm: mimeType = " + theMimeType);
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
        theDatabase = document.getElementById(g_cq_database_list);
        oldDatabase = theDatabase.value;
        theDatabase.value = null;
        submitForm(theForm, theQuery, "text/html");
        // TODO restore the user's chosen db
        //alert("cqExport: preserving selected database " + oldDatabase);
        theDatabase.value = oldDatabase;
    } // if theUri
} // cqExport

// XXX seems to be buggy, still
function cqAutoSave(n) {
    // use incremental updates if autosave form element is set
    // and the incremental flag is true (has already been exported)
    var theFlag = document.getElementById(g_cq_autosave_id);
    //alert("cqAutoSave: " + theFlag.checked);
    if (theFlag.checked) {
        if (! g_cq_autosave_incremental) {
            // this session hasn't been exported, as far as we know:
            // export it, then mark it ok for incremental
            cqExport(document.getElementById(g_cq_query_form));
            g_cq_autosave_incremental = true;
        } else {
            //alert("cqAutoSave: incremental");
            var theForm = document.getElementById(g_cq_query_form);
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
                //alert("cqAutoSave: " + theQuery);
                submitForm(theForm, theQuery, "text/html");
            } // theForm and theUri
        } // if incremental
    } // if autosave
} // cqAutoSave

// Submit XML Query
function submitXML(theForm) {
    //alert("submitXML");
    if (theForm) {
        //cqAutoSave();
        submitForm(theForm, getBuffer().value, "text/xml");
        //resizeResultFrame();
    }
} // submitXML

// Submit HTML Query
function submitHTML(theForm) {
    //alert("submitHTML");
    if (theForm) {
        //cqAutoSave();
        submitForm(theForm, getBuffer().value, "text/html");
        //resizeResultFrame();
    }
} // submitHTML

// Submit Text Query
function submitText(theForm) {
    //alert("submitText");
    if (theForm) {
        //cqAutoSave();
        submitForm(theForm, getBuffer().value, "text/plain");
        //resizeResultFrame();
    }
} // submitText

// display a confirmation message
function finishImport() {
    //alert('finishImport');
    var theOutput = getResultFrame();
    var theOutputDoc = null;
    //alert("theOutput = " + theOutput);
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

            //alert("theList = " + theList + ", length = " + theList.length);
            var theValue = null;
            for (var i = 0; i < theList.length; i++) {
                theValue = unescape( (theList[i]).firstChild.nodeValue );
                //alert("i = " + i + ", " + theValue);
                getBuffer(i).value = theValue;
            } // for theList

            // leave the user in the same buffer
            refreshBufferList(g_cq_buffer_current);
            //clearTimeout(theTimeout);
            var theUri = document.getElementById(g_cq_uri).value;
            var theQuery = '<p>' + theUri + ' imported</p>';
            submitForm(document.getElementById(g_cq_query_form),
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
    //alert("cqImport: " + theQuery);
    // set the current database to null,
    // so we save to the default db
    theDatabase = document.getElementById(g_cq_database_list);
    oldDatabase = theDatabase.value;
    theDatabase.value = null;
    submitForm(theForm, theQuery, "text/xml");
    theDatabase.value = oldDatabase;
    // read the output
    var theTimeout = setTimeout("finishImport();", g_cq_timeout);
} // cqImport

function cqListBuffers() {
    var theForm = document.getElementById(g_cq_query_form);
    var theQuery = "for $i in input() return (document-uri($i), <br/>)";
    submitForm(theForm, theQuery, "text/html");
} // cqListBuffers

// cq.js
