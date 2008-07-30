// Copyright (c) 2006 Kazuki Ohta (ohta _at_ uei.co.jp)
//
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

var Resizable = Class.create();
Resizable.prototype = {
  /*
   * Initializer
   */
  initialize: function(id, options) {
    this.element = $(id);
    this.options = options;
    this.is_vertical   = options['is_vertical']   && true;
    this.is_horizontal = options['is_horizontal'] && true;
    this.onResizeStart = options['onResizeStart'];
    this.onResizeEnd   = options['onResizeEnd'];
    // start Michael Blakeley 2008-07-29
    this.isTextArea = (this.element.tagName.toLowerCase() == 'textarea')
    // end Michael Blakeley 2008-07-29

    if (!this.is_vertical && !this.is_horizontal)
      return;

    this.handler = this.createHandler();
    this.wrapper = this.createWrapper();

    this.handler.onmousedown = this.onmousedown.bindAsEventListener(this);
    this.eventMouseUp        = this.onmouseup.bindAsEventListener(this);
    this.eventMouseMove      = this.onmousemove.bindAsEventListener(this);

    this.setStyleNormal(this.element, this.wrapper);
  },
  createHandler: function() {
    var handler = document.createElement('div');
    if (!handler)
      return null;

    this.setStyleHandler(handler);
    this.setWidth(handler, this.element.offsetWidth);

    return handler;
  },
  createWrapper: function() {
    var container = this.element;
    var parent    = container.parentNode;
    var wrapper   = document.createElement('div');
    var handler   = this.handler;
    if (!parent || !wrapper || !handler)
      return;

    this.setWidth(wrapper, container.offsetWidth);

    parent.insertBefore(wrapper, container);
    wrapper.appendChild(container);
    wrapper.appendChild(handler);

    return wrapper;
  },

  /*
   * Event Handling
   */
  onmousedown: function(e) {
    this.setStyleDragging(this.element, this.wrapper);

    this.startX = e.clientX;
    this.startY = e.clientY;
    this.startW = this.element.offsetWidth;
    this.startH = this.element.offsetHeight;

    Event.observe(document, "mouseup", this.eventMouseUp);
    Event.observe(document, "mousemove", this.eventMouseMove);

    if (this.onResizeStart)
      this.onResizeStart();

    Event.stop(e);
  },
  onmouseup: function(e) {
    this.setStyleNormal(this.element, this.wrapper);

    Event.stopObserving(document, "mouseup", this.eventMouseUp);
    Event.stopObserving(document, "mousemove", this.eventMouseMove);

    if (this.onResizeEnd)
      this.onResizeEnd();

    Event.stop(e);
  },
  onmousemove: function(e) {
    var x = this.startX;
    var y = this.startY;
    var w = this.startW;
    var h = this.startH;

    // start Michael Blakeley 2008-07-29
    var x1 = x;
    var y1 = y;
    // end Michael Blakeley 2008-07-29

    if (this.is_vertical) {
        // start Michael Blakeley 2008-07-29
        //this.setHeight(this.element, Math.max(50, h + e.clientY - y));
        y1 = Math.max(50, h + e.clientY - y);
        // end Michael Blakeley 2008-07-29
    }
    if (this.is_horizontal) {
        // start Michael Blakeley 2008-07-29
        //var width = Math.max(100, w + e.clientX - x);
        x1 = Math.max(100, w + e.clientX - x);
        //this.setWidth(this.element, width);
        //this.setWidth(this.handler, width);
        //this.setWidth(this.wrapper, width);
        // end Michael Blakeley 2008-07-29
    }

    // start Michael Blakeley 2008-07-29
    if (this.isTextArea) {
        // approximate the height as rows
        var tries = 100;
        if (y1 > y) {
            while (tries > 0 && this.element.offsetHeight < y1) {
                this.element.rows += 1;
                tries--;
            }
        } else {
            while (tries > 0 && this.element.offsetHeight > y1) {
                this.element.rows -= 1;
                tries--;
            }
        }
        // always snap down
        if (this.element.offsetHeight > y1) {
            this.element.rows -= 1;
        }
        // honor minimum rows
        if (this.element.rows < 1) {
            this.element.rows = 1;
        }
        // set wrapper height to match
        // TODO we might need to apply this to the whole ancestor axis
        this.setHeight(this.wrapper, '');
        this.setHeight(this.wrapper.getOffsetParent(), '');

        // approximate the width as cols
        var tries = 100;
        if (x1 > x) {
            while (tries > 0 && this.element.offsetWidth < x1) {
                this.element.cols += 1;
                tries--;
            }
        } else {
            while (tries > 0 && this.element.offsetWidth > x1) {
                this.element.cols -= 1;
                tries--;
            }
        }
        // always snap down
        if (this.element.offsetWidth > x1) {
            this.element.cols -= 1;
        }
        // honor minimum rows
        if (this.element.cols < 1) {
            this.element.cols = 1;
        }
    } else {
        this.setHeight(this.element, y1);
        this.setWidth(this.element, x1);
    }

    this.setWidth(this.handler, this.element.offsetWidth);
    this.setWidth(this.wrapper, this.element.offsetWidth);
    // end Michael Blakeley 2008-07-29

    Event.stop(e);
  },

  /*
   * Style
   */
  setWidth: function(element, width) {
    Element.setStyle(element, {width: width + 'px'});
  },
  setHeight: function(element, height) {
    Element.setStyle(element, {height: height + 'px'});
  },
  setStyleHandler: function(handler) {
    var hstyles = {};

    hstyles['height']      = '10px';
    hstyles['font-size']   = '10px';
    hstyles['line-height'] = '10px';
    hstyles['background-color'] = '#E0E0E0';
    hstyles['border'] = '1px solid #B0B0B0';

    if (this.is_vertical && this.is_horizontal)
      hstyles['cursor'] = 'se-resize';
    else if (this.is_vertical)
      hstyles['cursor'] = 's-resize';
    else if (this.is_horizontal)
      hstyles['cursor'] = 'e-resize';

    // start Michael Blakeley 2008-07-29
    // http://www.w3.org/TR/DOM-Level-2-Style/css.html
    hstyles['backgroundColor'] = '';
    hstyles['border'] = '0px';
    hstyles['backgroundImage'] = 'url("resizable-handle.gif")';
    hstyles['backgroundRepeat'] = 'no-repeat';
    hstyles['backgroundPosition'] = '100% 100%';
    hstyles['height'] = '12px';
    hstyles['fontSize']   = '';
    hstyles['lineHeight'] = '';
    // display the handle at the bottom of the resizable object
    hstyles['position'] = 'relative';
    hstyles['top'] = '-13px';
    hstyles['marginBottom'] = '-13px';
    hstyles['padding'] = '0 0 0 0';
    hstyles['zIndex'] = 100;
    // end Michael Blakeley 2008-07-29

    Element.setStyle(handler, hstyles);
  },
  setStyleNormal: function(element, wrapper) {
    var estyles = {};
    var wstyles = {};

    estyles['background-color'] = '';

    // start Michael Blakeley 2008-07-29
    // http://www.w3.org/TR/DOM-Level-2-Style/css.html
    estyles['backgroundColor'] = '';
    wstyles['border'] = '0px';
    // end Michael Blakeley 2008-07-29

    Element.setStyle(element, estyles);
    Element.setStyle(wrapper, wstyles);
  },
  setStyleDragging: function(element, wrapper) {
    var estyles = {};
    var wstyles = {};

    estyles['background-color'] = '#eeeeee';
    wstyles['border'] = '1px dashed #808080';
    // start Michael Blakeley 2008-07-29
    // http://www.w3.org/TR/DOM-Level-2-Style/css.html
    estyles['backgroundColor'] = '#eeeeee';
    // end Michael Blakeley 2008-07-29

    Element.setStyle(element, estyles);
    Element.setStyle(wrapper, wstyles);
  }
};

