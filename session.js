// Copyright (c) 2003-2010 Mark Logic Corporation. All rights reserved.
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
var gLocalStoreSessionsKey = "com.marklogic.cq.sessions";

// GLOBAL VARIABLES

// static functions

function reportError(resp, from) {
    var old = debug.isEnabled();
    debug.setEnabled(true);
    debug.print("session.js (reportError from " + from + "): "
                + "status = (" + resp.status + ") " + resp.statusText
                + ", response = " + resp.responseText
                + ", request.url = " + resp.request.url);
    debug.setEnabled(old);
}

// from http://stackoverflow.com/questions/105034/how-to-create-a-guid-uuid-in-javascript
function createUUID() {
    // http://www.ietf.org/rfc/rfc4122.txt
    var s = [];
    var hexDigits = "0123456789ABCDEF";
    for (var i = 0; i < 32; i++) {
        s[i] = hexDigits.substr(Math.floor(Math.random() * 0x10), 1);
    }
    s[12] = "4";  // bits 12-15 of the time_hi_and_version field to 0010
    s[16] = hexDigits.substr((s[16] & 0x3) | 0x8, 1);  // bits 6-7 of the clock_seq_hi_and_reserved to 01
    return s.join("");
}

// SessionList class
function SessionList() {
    this.cloneUrl = 'session-clone.xqy';
    this.deleteUrl = 'session-delete.xqy';
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

    this.exportServerSession = function(id, context) {
        var path = "session-export.xqy?id=" + id;
        window.location.href = path;
    };

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

    // only for local sessions
    this.sessionName = null;
    this.localSessionList = null;

    // only for remote sessions
    this.etag = null;

    this.buffers = this.tabs ? this.tabs.getBuffers() : null;
    debug.print("SessionClass: buffers = " + this.buffers);
    this.history = this.tabs ? this.tabs.getHistory() : null;
    debug.print("SessionClass: history = " + this.history);
    this.lastSync = null;

    // enable sync if and only if we see a session id
    this.syncDisabled = true;
    // handle for scheduled save task
    this.autosave = null;

    this.renameUrl = 'session-rename.xqy';
    this.updateSessionUrl = "session-update.xqy";
    this.updateSessionLockUrl = "session-lock-update.xqy";

    this.isSyncEnabled = function() { return ! this.syncDisabled };

    this.getId = function() { return this.sessionId }

    this.rename = function(name) {
        // used for local session rename
        this.sessionName = name;
        this.tabs.setSessionName();
        this.sync();
    };

    this.restore = function() {
        var restore = $(this.restoreId);
        var label = "SessionClass.restore: ";

        if (null == restore) {
            debug.print(label + "null restore from " + this.restoreId);
            this.syncDisabled = true;
            if (this.tabs) {
                this.tabs.refresh();
            }
            return;
        }

        debug.print(label + restore + " " + restore.hasChildNodes());

        // handle session id cookie
        this.sessionId = restore.getAttribute('session-id');
        // sessionId may be null, or empty string:
        // either disables sync unless local storage is available
        if (this.sessionId) {
            this.syncDisabled = false;
            setCookie(gSessionIdCookie, this.sessionId);
            debug.print(label + "set session id cookie = " + this.sessionId);
        } else {
            debug.print(label + "missing session id!");
            this.syncDisabled = true;
            // not fatal - keep restoring whatever the server gave us
        }
        debug.print(label + "syncDisabled = " + this.syncDisabled);

        this.restoreFromXML(restore);
    };

    this.restoreFromXML = function(restore) {
        var label = "SessionClass.restoreFromXML: ";

        var children = restore.childNodes;
        if (!children) {
            return;
        }

        debug.print(label + "children = " + children);

        // store the last-updated value
        this.etag = restore.getAttribute('etag');

        // handle exposed tab
        var activeTab = restore.getAttribute('active-tab');

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
            debug.print(label + "restoring " + i + " " + queries[i]);
            query = queries[i].hasChildNodes()
                ? queries[i].firstChild.nodeValue
                : null;
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
            this.history.add(query);
        }

        // this must happen last
        this.tabs.refresh(activeTab);
    };

    this.restoreFromObject = function(restore) {
        var label = "SessionClass.restoreFromXML: ";
        debug.print(label + "restoring " + restore);
        if (!restore.get) {
            debug.print(label + "restoring " + Object.toJSON(restore));
        }

        // instead of XML, we restore from a Prototype hash object
        this.sessionName = restore.get('name');
        if (!this.sessionName) {
            this.sessionName = "local";
        }
        var activeTab = restore.get('active-tab');
        var activeBuffer = restore.get('active-buffer');
        var rows = restore.get('rows');
        var cols = restore.get('cols');
        // array of hash
        var buffers = restore.get('buffers');
        // array of string
        var history = restore.get('history');

        // restore tabs, rows, and cols
        this.buffers.setRows(rows);
        this.buffers.setCols(cols);

        // restore buffers
        debug.print(label + "restoring buffers " + buffers.length);
        this.buffers.clear();
        var h;
        for (var i=0; i < buffers.length; i++) {
            h = $H(buffers[i]);
            this.buffers.add(h.get('query'), h.get('source'));
        }
        this.buffers.activate(activeBuffer);

        debug.print(label + "restoring history " + history.length);
        // restore in reverse order
        this.history.clear();
        var start = history.length - 1;
        for (var i=start; i >= 0; i--) {
            this.history.add(history[i]);
        }

        // this must happen last
        this.tabs.refresh(activeTab);
    };

    this.sync = function() {
        var label = "SessionClass.sync: ";
        if (this.syncDisabled) {
            debug.print(label + "disabled");
            return false;
        }

        if (null == this.sessionId) {
            debug.print(label + "no session");
            return false;
        }

        var historyLastModified = this.history.getLastModified();
        var lastLineStatus = this.buffers.getLastLineStatus();

        debug.print(label + this.sessionId
                    + ", etag=" + this.etag
                    + ", lastmodified=" + historyLastModified
                    + " ? lastsync=" + this.lastSync);
        if (null != this.lastSync
            && historyLastModified <= this.lastSync
            && lastLineStatus <= this.lastSync)
        {
            // nothing has changed - tickle the lock anyway
            this.updateLock();
            return false;
        }

        // this is not really thread-safe - attempt at critical section...
        // this seems to work ok, but we skip some syncs under duress
        this.syncDisabled = true;

        if (this.localSessionList) {
            debug.print(label + "local store");
            setCookie(gSessionIdCookie, "LOCAL");
            var syncHash = new Hash();
            syncHash.set('name', this.sessionName);
            syncHash.set('active-tab', this.tabs.getCurrent());
            syncHash.set('active-buffer', this.buffers.getActivePosition());
            syncHash.set('rows', this.buffers.getRows());
            syncHash.set('cols', this.buffers.getCols());
            syncHash.set('buffers', this.buffers.toArray());
            syncHash.set('history', this.history.toArray());
            this.localSessionList.put(this.sessionId, syncHash);
            // end of critical section
            this.syncDisabled = false;
            this.lastSync = new Date();
            return true;
        }

        // ajax technique, for server sessions
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
        var failureHandler = function(resp) {
            var old = debug.isEnabled();
            debug.setEnabled(true);
            debug.print("Session.sync failure:"
                        + " status = (" + resp.status + ") " + resp.statusText
                        + ", response = " + resp.responseText
                        + ", request.url = " + resp.request.url);
            debug.setEnabled(old);

            // ask the user if we should fall back to local session storage.
            if (!confirm("This session could not be written to server."
                         + " Use browser local storage instead?")) {
                alert("Changes to this session may not be saved."
                      + " You may wish to copy the current query,"
                      + " and refresh cq.");
                return;
            }

            // fall back to local browser storage
            session.localSessionList = new SessionListLocal();

            // re-enable session sync
            session.syncDisabled = false;

            // schedule the next attempt immediately
            setTimeout(function() { session.rename("new local session");
                }.bindAsEventListener(this),
                1000 / 32);
        };
        var successHandler = function(resp) {
            var label = "successHandler: ";

            // no resp means the update was canceled by the user
            if (!resp) {
                debug.print(label + "empty response");
                return;
            }

            if (resp.status == 0) {
                // actually this was an error (blank page)
                return failureHandler(resp);
            }

            // don't overwrite the old etag unless we have a new one
            var newTag = resp.getResponseHeader("etag");
            debug.print(label + "old = " + session.etag + ", new = " + newTag);
            if (newTag) {
                session.etag = newTag;
                debug.print(label + "new = " + session.etag);
            }

            // re-enable sync
            session.syncDisabled = false;
        };
        var req = new Ajax.Request(this.updateSessionUrl, {
                method: 'post',
                parameters: params,
                requestHeaders: { 'If-Match': this.etag },
                // workaround, to avoid appending charset info
                encoding: null,
                onSuccess: successHandler,
                onFailure: failureHandler
            } );
        // synchronous, so we should have the response now

        this.lastSync = new Date();
        return true;
    }

    this.updateLock = function() {
        var label = "SessionClass.updateLock: ";

        if (this.syncDisabled || null == this.sessionId) {
            debug.print(label + "disabled");
            return false;
        }

        if (this.localSessionList) {
            debug.print(label + "using local store");
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
            } );
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
    };

    this.useLocal = function (sessionList) {
        var label = "SessionClass.useLocal: ";
        if (! sessionList) {
            debug.print(label + "null sessionList");
            return;
        }

        // is there a local session to restore? do we want it?
        var key = sessionList.length() ? sessionList.keyAt(0) : null;
        var isNewLocal = (key == "NEW");
        this.localSessionList = sessionList;
        debug.print(label + "count = " + this.localSessionList.length()
                    + ", " + isNewLocal);

        if (isNewLocal || 1 > this.localSessionList.length()) {
            debug.print(label + "creating new local session");
            // no session, or the session is explicitly "NEW"
            // keep the already-restored server session,
            // but ensure that we have a session id for sync
            if (isNewLocal) {
                this.localSessionList.remove("NEW");
            }
            this.sessionId = createUUID();
            this.sessionName = "new local session "
                + (1 + this.localSessionList.length());
        } else {
            debug.print(label + "restoring from local session " + key);
            this.sessionId = key;
            this.restoreFromObject($H(this.localSessionList.get(key)));
        }

        // activate sessions
        this.syncDisabled = false;

        if (isNewLocal || this.localSessionList.length() < 1) {
            debug.print(label + "saving new session " + this.sessionId);
            this.sync();
        }
    };

} // SessionClass

// SessionListLocal class
function SessionListLocal() {

    // prohibit cookie store since it will be too small (4-kB limit)
    Persist.remove('cookie');

    this.store = new Persist.Store("MarkLogic cq");
    this.sessionsList = new Array();
    this.label = "SessionListLocal.init: ";

    // for event callback access
    var that = this;

    // populate the session list
    this.store.get(gLocalStoreSessionsKey,
                   function(ok, val) {
                       if (ok) {
                           try {
                               that.sessionsList = ("" + val).evalJSON(true);
                           } catch (ex) {
                               debug.print(label + ex.message);
                               alert(label + ex.message);
                           }
                           if (null == that.sessionsList) {
                               that.sessionsList = new Array();
                           }
                           debug.print(that.label
                                       + "setting sessions = "
                                       + that.sessionsList.length);
                       }
                   });

    debug.print(this.label + "sessions = " + this.sessionsList.length);

    // private
    this.key = function(id) {
        // would like to use '/', but IE objects
        // so we continue in a java-like vein
        return gLocalStoreSessionsKey + "." + id;
    };

    this.first = function() {
        return this.get(this.keyAt[0]);
    };

    this.keys = function() {
        return this.sessionsList;
    };

    this.keyAt = function(i) {
        return this.sessionsList[i];
    };

    this.length = function() {
        return this.sessionsList.length;
    };

    this.get = function(id) {
        var label = "SessionListLocal.get: ";
        var result = null;
        this.store.get(this.key(id),
                       function(ok, val) {
                           if (ok) {
                               try {
                                   result = ("" + val).evalJSON(true);
                               } catch (ex) {
                                   debug.print(label + ex.message);
                                   alert(label + ex.message);
                               }
                           }
                       });
        return result;
    };

    this.put = function(id, value) {
        var label = "SessionListLocal.put: ";
        var jValue = Object.toJSON(value);
        debug.print(label + id);

        this.queue(id);
        this.store.set(this.key(id), jValue);
    };

    this.queue = function(id) {
        var label = "SessionListLocal.queue: ";
        // re-order the sessions by most recent use
        var newArray = new Array();
        newArray[0] = id;
        for (var i=0; i<this.sessionsList.length; i++) {
            if (id != this.sessionsList[i]) {
                newArray[newArray.length] = this.sessionsList[i];
            }
        }
        debug.print(label + newArray.length + " = " + newArray[0]);
        this.sessionsList = newArray;
        this.store.set(gLocalStoreSessionsKey,
                       Object.toJSON(this.sessionsList));

    };

    this.remove = function(id) {
        var label = "SessionListLocal.remove: ";
        // re-order the sessions by most recent use
        var newArray = new Array();
        for (var i=0; i<this.sessionsList.length; i++) {
            if (id != this.sessionsList[i]) {
                newArray[newArray.length] = this.sessionsList[i];
            }
        }
        debug.print(label + newArray.length + " = " + newArray[0]);
        this.sessionsList = newArray;
        this.store.set(gLocalStoreSessionsKey,
                       Object.toJSON(this.sessionsList));

        this.store.remove(id);
    };

    this.clone = function(id) {
        var session = $H(this.get(id));
        session.set('name', "copy of " + session.get('name'));
        this.put(createUUID(), session);
    };

    this.refresh = function() {
        if (debug.isEnabled()) {
            alert("DEBUG: will refresh now");
            window.location.replace( ".?debug=1");
        } else {
            window.location.replace( "." );
        }
    };

}

function sessionsOnLoad() {
    var label = "sessionsOnLoad: ";
    var sessionList = new SessionListLocal();
    if (sessionList.length() < 0) {
        return;
    }

    var out = $("sessions-local");
    var table = new Element("table");
    // IE insists on having a tbody or thead
    var tbody = new Element('tbody');
    table.appendChild(tbody);

    if (sessionList.length() < 1) {
        var row = new Element('tr');
        row.appendChild(new Element('td', {
                    // IE is too dumb to parse class as a symbol
                    "class": "instruction"})
            .update("No sessions found"));
        tbody.appendChild(row);
    } else {
        for (var i=0; i<sessionList.length(); i++) {
            var key = sessionList.keyAt(i);
            debug.print(label + i + " " + key);
            var session = $H(sessionList.get(key));
            var sessionName = session.get('name');
            debug.print(label + i + " " + key + " " + sessionName);
            var row = document.createElement('tr');

            row.appendChild(new Element('td').update(sessionName));

            var cell = new Element('td');
            var button;

            // resume local session
            button = new Element('input', {
                    type: 'button',
                    value: 'Resume' + (debug.isEnabled() ? (' ' + key) : ''),
                    title: 'resume this session ' + key});
            // extra function to create proper scope
            button.observe('click', function(k) {
                    return function() {
                        sessionList.queue(k);
                        // setting the session id to "LOCAL" signals
                        // query.xqy and lib-controller.xqy
                        // to use the local information.
                        setCookie(gSessionIdCookie, "LOCAL");
                        sessionList.refresh();
                    }
                }(key));
            cell.appendChild(button);

            // clone local session
            button = new Element('input', {
                    type: 'button',
                    value: 'Clone' + (debug.isEnabled() ? (' ' + key) : ''),
                    title: 'clone this session ' + key});
            // extra function to create proper scope
            button.observe('click', function(k) {
                    return function() {
                        sessionList.clone(k);
                        window.location.reload();
                    }
                }(key));
            cell.appendChild(button);

            // TODO export local session to xml file

            // delete local session
            button = new Element('input', {
                    type: 'button',
                    value: 'Delete' + (debug.isEnabled() ? (' ' + key) : ''),
                    title: 'permanently delete this session ' + key});
            // extra function to create proper scope
            button.observe('click', function(k) {
                    return function() {
                        if (!confirm("Are you sure you want to remove"
                                     + " this session?"
                                     + " This cannot be undone!")) {
                            return;
                        }
                        sessionList.remove(k);
                        window.location.reload();
                    }
                }(key));
            cell.appendChild(button);
            row.appendChild(cell);

            tbody.appendChild(row);
        }
    }

    out.appendChild(table);

    // button for new local session
    button = new Element('input', {
            type: 'button',
            value: 'New Local Session'});
    button.observe('click', function() {
        // setting the session id to the string "LOCAL" signals
        // query.xqy and lib-controller.xqy to use the local information.
        setCookie(gSessionIdCookie, "LOCAL");
        // signal that we want a new local session on refresh
        sessionList.queue("NEW");
        sessionList.refresh();
        });
    out.appendChild(button);
    out.appendChild(new Element('p'));
    out.appendChild(new Element('hr'));

    // activate display
    out.className = "";
    Element.show(out);
}

function sessionImportLocal() {
    var label = "sessionImportLocal: ";
    debug.print(label + "begin");

    // set up the UI objects
    var bufferList = new QueryBufferListClass("query",
                                              "eval",
                                              "buffer-list",
                                              "textarea-status");
    var history = new QueryHistoryClass("history", bufferList);
    var bufferTabs = new BufferTabsClass("buffer-tabs",
                                         "buffer-accesskey-text",
                                         bufferList,
                                         history);
    var session = new SessionClass(bufferTabs, "session-restore");

    // restore from the server-supplied XML, ie from the import file
    debug.print(label + "restoring");
    session.restore();

    // signal that we want a new local session
    var sessionList = new SessionListLocal();
    sessionList.queue("NEW");
    session.useLocal(sessionList);

    // redirect to session.xqy
    window.location.href = "session.xqy";
}

// session.js
