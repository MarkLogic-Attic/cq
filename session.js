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
//////////////////////////////////////////////////////////////////////////

// NOTE: to defeat IE6 caching, always use method=POST

// GLOBAL CONSTANTS: but IE6 doesn't support "const"
var gSessionIdCookie = "/cq:session-id";

// GLOBAL VARIABLES

// static functions
function reportError(req, resp) {
    var old = debug.isEnabled();
    debug.setEnabled(true);
    debug.print("reportError: req = " + req);
    debug.print("reportError: resp = " + resp);
    debug.setEnabled(old);
}

// SessionList class
function SessionList() {
    var deleteUrl = 'delete-session.xqy';
    var renameUrl = 'rename-session.xqy';

    this.newSession = function() {
        // start a new session and set the user cookie appropriately
        debug.print("newSession: start");
        // setting the session id to the string "NEW" signals
        // lib-controller.xqy to build a new session.
        setCookie(gSessionIdCookie, "NEW");
        // refresh should show the query view
        window.location.replace( "." );
    }

    this.resumeSession = function(sessionId) {
        debug.print("resumeSession: " + sessionId);
        // set cookie to the new id
        setCookie(gSessionIdCookie, sessionId);
        // refresh should show the query view
        if (debug.isEnabled()) {
            alert("will refresh now");
            window.location.replace( ".?debug=1");
        } else {
            window.location.replace( "." );
        }
    }

    this.deleteSession = function(id, context) {
        // delete the session
        debug.print("deleteSession: " + id);
        if (confirm("Are you sure you want to delete this session?")) {
            // call session-delete
            var req = new Ajax.Request(deleteUrl,
                {
                    method: 'post',
                    parameters: 'ID=' + id,
                    asynchronous: false,
                    onFailure: reportError
                });
            // delete the item from the DOM
            // context will be the button
            var row = context.parentNode.parentNode;
            if (null != row) {
                Element.remove(row);
            }
        }
    }

    this.renameSession = function(id, name) {
        debug.print("renameSession: " + id + " to " + name);
        // call the rename xqy
        var req = new Ajax.Request(renameUrl,
            {
                method: 'post',
                parameters: 'ID=' + id + '&NAME=' + name
                  + (debug.isEnabled() ? '&DEBUG=1' : ''),
                asynchronous: false,
                onFailure: reportError
            });
    }

} // SessionListClass

// this class is responsible for autosaving the session state
function SessionClass(tabs, id) {
    this.tabs = tabs;
    this.restoreId = id;
    this.sessionId = null;
    this.buffers = this.tabs.getBuffers();
    debug.print("SessionClass: buffers = " + this.buffers);
    this.history = this.tabs.getHistory();
    debug.print("SessionClass: history = " + this.history);
    this.lastSync = null;

    // enable sync if and only if we see a session id
    this.syncDisabled = true;

    this.autosave = null;

    var syncUrl = "update-session.xqy";

    this.restore = function() {
        var restore = $(this.restoreId);
        var label = "SessionClass.restore: ";
        debug.print(label + restore + " " + restore.hasChildNodes());
        //alert(label + restore + " " + restore.hasChildNodes());

        if (null == restore) {
          debug.print(label + "null restore");
          this.tabs.refresh();
          return;
        }

        // handle session id cookie
        this.sessionId = restore.getAttribute('session-id');
        if (null != this.sessionId) {
            this.syncDisabled = false;
            setCookie(gSessionIdCookie, this.sessionId);
            debug.print(label + "set session id cookie = " + this.sessionId);
        } else {
            debug.print(label + "missing session id!");
            this.syncDisabled = true;
        }

        // handle exposed tab
        var activeTab = restore.getAttribute('active-tab');
        this.tabs.refresh(activeTab);

        if (restore.hasChildNodes()) {
            var children = restore.childNodes;
            debug.print(label + "children = " + children);

            var queries = null;
            var query = null;
            var source = null;

            // first div is the buffers
            var buffers = children[0];
            debug.print(label + "buffers = " + buffers);
            // handle rows and cols (global)
            this.buffers.setRows(buffers.getAttribute('rows'));
            this.buffers.setCols(buffers.getAttribute('cols'));
            queries = buffers.childNodes;
            debug.print(label + "queries = " + queries);
            debug.print(label + "restoring buffers " + queries.length);
            for (var i = 0; i < queries.length; i++) {
                debug.print(label + "restoring " + i + queries[i]);
                query = queries[i].hasChildNodes()
                    ? queries[i].firstChild.nodeValue
                    : null;
                //debug.print(label + "restoring " + i + " " + query);
                // handle content-source (per buffer)
                source = queries[i].getAttribute('content-source');
                debug.print(label + "restoring " + i + " source = " + source);
                this.buffers.add(query, source);
            }
            // reactivate active buffer
            var active = buffers.getAttribute('active');
            debug.print(label + "buffers active = " + active);
            this.buffers.activate(active);

            // second div is the history
            var history = children[1];
            queries = history.childNodes;
            debug.print(label + "restoring history " + queries.length);
            // restore in reverse order
            for (var i = queries.length; i > 0; i--) {
                query = queries[ i - 1 ].firstChild.nodeValue;
                //debug.print(label + "restoring " + i + " " + query);
                this.history.add(query);
            }
        }
    }

    this.sync = function() {
        var label = "SessionClass.sync: ";
        if (this.syncDisabled || null == this.sessionId) {
            debug.print(label + "disabled");
            return false;
        }

        var lastModified = this.history.getLastModified();
        var lastLineStatus = this.buffers.getLastLineStatus();

        debug.print(label + lastModified + " ? " + this.lastSync);
        if (null != this.lastSync
            && lastModified < this.lastSync
            && lastLineStatus < this.lastSync)
        {
            // nothing has changed
            return false;
        }

        var buffers = encodeURIComponent(this.buffers.toXml());
        var history = encodeURIComponent(this.history.toXml());
        var tabs = encodeURIComponent(this.tabs.toXml());
        var params = ('ID=' + this.sessionId
                      + '&BUFFERS=' + buffers
                      + '&HISTORY=' + history
                      + '&TABS=' + tabs);
        debug.print(label + "" + params);

        var req = new Ajax.Request(syncUrl,
            {
                method: 'post',
                parameters: params,
                onFailure: reportError
            }
                                   );
        this.lastSync = new Date();

        return true;
    }

    this.setAutoSave = function(sec) {
        if (this.syncDisabled) {
          debug.print("SessionClass.setAutoSave: sync is disabled");
          return;
        }

        sec = Number(sec)
        sec = (null == sec || isNaN(sec)) ? 60 : sec;

        this.autosave = new PeriodicalExecuter(this.sync
                                               .bindAsEventListener(this),
                                               sec);
    }

} // SessionClass

// session.js
