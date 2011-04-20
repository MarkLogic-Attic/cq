// Copyright (c) 2011 MarkLogic Corporation. All rights reserved.
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

// widget expand-collapse code
function toggleXmlTree(e)
{
    // "this" should be an xw element
    // find the first following xe
    // find the ul
    // if hidden, show it
    // if shown, hide it
    var n = this.next('xe', 0).down('ul', 0);
    n.toggle();
    // change the glyph as needed
    this.update(n.visible() ? "—" : "+");
    // TODO also toggle the following xe?
    //this.next('xe', 1).toggle();
}

// onload handler
function xmlTreeInit()
{
    var list = document.getElementsByTagName("xw");
    //alert("init: " + list.length);
    for (var i = 0; i< list.length; i++) {
        Event.observe(list[i], "click", toggleXmlTree);
    }
}

// xml-tree.js
