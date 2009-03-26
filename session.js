// Copyright (c) 2003-2009 Mark Logic Corporation. All rights reserved.
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
function reportError(req) {
    var old = debug.isEnabled();
    debug.setEnabled(true);
    debug.print("reportError: status = " + req.status);
    debug.print("reportError: req = " + req.responseText);
    debug.setEnabled(old);
}

// SessionList class
function SessionList() {
    this.cloneUrl = 'clone-session.xqy';
    this.deleteUrl = 'delete-session.xqy';
    this.currentSession = null;

    this.setCurrentSession = function(s) {
        this.currentSession = s;
    }

    this.refresh = function() {
        if (debug.isEnabled()) {
            alert("DEBUG: will refresh now");
            window.location.replace( ".?debug=1");
        } else {
            window.location.replace( "." );
        }
    }

    this.newSession = function() {
        // start a new session and set the user cookie appropriately
        debug.print("newSession: start");
        // setting the session id to the string "NEW" signals
        // lib-controller.xqy to build a new session.
        setCookie(gSessionIdCookie, "NEW");
        // refresh should show the query view
        this.refresh();
    }

    this.resumeSession = function(sessionId) {
        debug.print("resumeSession: " + sessionId);
        // set cookie to the new id
        setCookie(gSessionIdCookie, sessionId);
        // refresh should show the query view
        this.refresh();
    }

    this.buildNamedQueryString = function(id, name) {
        return 'ID=' + id + '&NAME=' + escape(name)
          + (debug.isEnabled() ? '&DEBUG=1' : '')
    }

    this.cloneSession = function(id, context) {
        // clone the session
        var name = prompt("Name of cloned session:", "new session");
        debug.print("cloneSession: " + id + " to " + name);
        if (! name) {
            return;
        }
        // call session-clone
        var closure = this;
        var newId = null;
        var opts = {
            method: 'post',
            // workaround, to avoid appending charset info
            encoding: null,
            parameters: this.buildNamedQueryString(id, name),
            asynchronous: false,
            onFailure: reportError,
            onSuccess: function(resp) {
                // refresh page to show new session
                newId = resp.responseText;
            }
        };
        var req = new Ajax.Request(this.cloneUrl, opts);
        // synchronous, so we should have the response here
        debug.print("cloneSession: newId = " + newId);
        closure.resumeSession(newId);
    }

    this.deleteSession = function(id, context) {
        // delete the session
        debug.print("deleteSession: " + id);
        if (! confirm("Are you sure you want to delete this session?")) {
            return;
        }
        // call session-delete
        var opts = {
            method: 'post',
            // workaround, to avoid appending charset info
            encoding: null,
            parameters: 'ID=' + id,
            asynchronous: false,
            onFailure: reportError
        };
        var req = new Ajax.Request(this.deleteUrl, opts);

        // delete the item from the DOM
        // context will be the button
        var row = context.parentNode.parentNode;
        if (null != row) {
            Element.remove(row);
        }
    }

} // SessionListClass

// this class is responsible for autosaving the session state
function SessionClass(tabs, id) {
    this.tabs = tabs;
    this.restoreId = id;
    this.sessionId = null;
    this.etag = null;
    this.buffers = this.tabs.getBuffers();
    debug.print("SessionClass: buffers = " + this.buffers);
    this.history = this.tabs.getHistory();
    debug.print("SessionClass: history = " + this.history);
    this.lastSync = null;

    // enable sync if and only if we see a session id
    this.syncDisabled = true;

    this.autosave = null;

    this.renameUrl = 'rename-session.xqy';
    this.updateSessionUrl = "update-session.xqy";
    this.updateSessionLockUrl = "update-session-lock.xqy";

    this.getId = function() { return this.sessionId }

    this.restore = function() {
        var restore = $(this.restoreId);
        var label = "SessionClass.restore: ";
        debug.print(label + restore + " " + restore.hasChildNodes());

        if (null == restore) {
            debug.print(label + "null restore");
            this.syncDisabled = true;
            this.tabs.refresh();
            return;
        }

        // handle session id cookie
        this.sessionId = restore.getAttribute('session-id');
        // sessionId may be null, or empty string - this disables sync
        if (this.sessionId) {
            this.syncDisabled = false;
            setCookie(gSessionIdCookie, this.sessionId);
            debug.print(label + "set session id cookie = " + this.sessionId);
        } else {
            debug.print(label + "missing session id! disabling sync");
            this.syncDisabled = true;
            // not fatal - keep restoring
        }

        // store the last-updated value
        this.etag = restore.getAttribute('etag');

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

        var historyLastModified = this.history.getLastModified();
        var lastLineStatus = this.buffers.getLastLineStatus();

        debug.print(label + this.sessionId
                    + " " + this.etag
                    + " " + historyLastModified + " ? " + this.lastSync);
        if (null != this.lastSync
            && historyLastModified <= this.lastSync
            && lastLineStatus <= this.lastSync)
        {
            // nothing has changed - tickle the lock anyway
            this.updateLock();
            return false;
        }

        var buffers = this.buffers.toXml();
        var history = this.history.toXml();
        var tabs = this.tabs.toXml();
        var params = {
            DEBUG: debug.isEnabled() ? true : false,
            ID: this.sessionId,
            BUFFERS: buffers,
            HISTORY: history,
            TABS: tabs
        };

        debug.print(label + "" + params);

        // wrap current session in a closure
        var session = this;
        // TODO use a Mutex class here?
        var successHandler = function(resp) { session.updateEtag(resp) };
        var req = new Ajax.Request(this.updateSessionUrl,
            {
                method: 'post',
                // we don't want async because it will causes races...
                // especially with manual vs automatic sync!
                asynchronous: false,
                parameters: params,
                requestHeaders: { 'If-Match': this.etag },
                // workaround, to avoid appending charset info
                encoding: null,
                onSuccess: successHandler,
                onFailure: reportError
            }
                                   );
        this.lastSync = new Date();

        return true;
    }

    this.updateEtag = function(resp) {
        debug.print("successHandler: old = " + this.etag);
        debug.print("successHandler: resp etag = "
                    + resp.getResponseHeader("etag"));
        this.etag = resp.getResponseHeader("etag");
        debug.print("successHandler: new = " + this.etag);
    }

    this.updateLock = function() {
        var label = "SessionClass.updateLock: ";
        if (this.syncDisabled || null == this.sessionId) {
            debug.print(label + "disabled");
            return false;
        }

        var params = {
            DEBUG: debug.isEnabled() ? true : false,
            ID: this.sessionId
        };

        debug.print(label + "" + params);

        var req = new Ajax.Request(this.updateSessionLockUrl,
            {
                method: 'post',
                parameters: params,
                // workaround, to avoid appending charset info
                encoding: null,
                onFailure: reportError
            }
                                   );
    };

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
