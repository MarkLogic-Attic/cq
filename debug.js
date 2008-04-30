// Copyright (c) 2003-2008 Mark Logic Corporation. All rights reserved.
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

var debug = new DebugClass(false);

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
    this.enabled = flag;

    this.setEnabled = function(flag) { this.enabled = flag; };
    this.isEnabled = function() { return this.enabled };

    this.setEnabled(flag);

    this.print = function(message) {
        if (this.enabled != true) { return; }

        var id = "__debugNode";
        var debugNode = $(id);
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

// debug.js
