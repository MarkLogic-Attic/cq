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
    if (name == null) {
        return null;
    }

    if (document.cookie == null) {
        return null;
    }

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

// cookie.js
