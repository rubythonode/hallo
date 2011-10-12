#     Hallo - a rich text editing jQuery UI widget
#     (c) 2011 Henri Bergius, IKS Consortium
#     Hallo may be freely distributed under the MIT license
((jQuery) ->
    # Hallo provides a jQuery UI widget `hallo`. Usage:
    #
    #     jQuery('p').hallo();
    #
    # Getting out of the editing state:
    #
    #     jQuery('p').hallo({editable: false});
    #
    # When content is in editable state, users can just click on
    # an editable element in order to start modifying it. This
    # relies on browser having support for the HTML5 contentEditable
    # functionality, which means that some mobile browsers are not
    # supported.
    #
    # If plugins providing toolbar buttons have been enabled for
    # Hallo, then a floating editing toolbar will be rendered above
    # the editable contents when an area is active.
    #
    # ## Options
    #
    # Change from floating mode to relative positioning with using
    # the offset to position the toolbar where you want it:
    #
    #    jQuery('selector').hallo({
    #       floating: true,
    #       offset: {
    #         'x' : 0,
    #         'y' : 0
    #       }
    #    });
    #
    # Force the toolbar to be shown at all times when a contenteditable
    # element is focused:
    #
    #    jQuery('selector').hallo({
    #       showAlways: true
    #    });
    #
    # showAlways is false by default
    #
    # ## Events
    #
    # The Hallo editor provides several jQuery events that web
    # applications can use for integration:
    #
    # ### Activated
    #
    # When user activates an editable (usually by clicking or tabbing
    # to an editable element), a `halloactivated` event will be fired.
    #
    #     jQuery('p').bind('halloactivated', function() {
    #         console.log("Activated");
    #     });
    #
    # ### Deactivated
    #
    # When user gets out of an editable element, a `hallodeactivated`
    # event will be fired.
    #
    #     jQuery('p').bind('hallodeactivated', function() {
    #         console.log("Deactivated");
    #     });
    #
    # ### Modified
    #
    # When contents in an editable have been modified, a
    # `hallomodified` event will be fired.
    #
    #     jQuery('p').bind('hallomodified', function(event, data) {
    #         console.log("New contents are " + data.content);
    #     });
    #
    jQuery.widget "IKS.hallo",
        toolbar: null
        bound: false
        originalContent: ""
        uuid: ""
        selection: null

        options:
            editable: true
            plugins: {}
            floating: true
            offset: {x:0,y:0}
            showAlways: false
            activated: ->
            deactivated: ->
            selected: ->
            unselected: ->

        _create: ->
            @originalContent = @getContents()
            @id = @_generateUUID()
            @_prepareToolbar()

            for plugin, options of @options.plugins
                if not jQuery.isPlainObject options
                    options = {}
                options["editable"] = this
                options["toolbar"] = @toolbar
                options["uuid"] = @id
                jQuery(@element)[plugin] options

        _init: ->
            if @options.editable
                @enable()
            else
                @disable()

        # Disable an editable
        disable: ->
            @element.attr "contentEditable", false
            @element.unbind "focus", @_activated
            @element.unbind "blur", @_deactivated
            @element.unbind "keyup paste change", this, @_checkModified
            @element.unbind "keyup mouseup", this, @_checkSelection
            @bound = false

        # Enable an editable
        enable: ->
            @element.attr "contentEditable", true

            if not @bound
                @element.bind "focus", this, @_activated
                # Only add the blur event when showAlways is set to true
                if not @options.showAlways
                    @element.bind "blur", this, @_deactivated
                @element.bind "keyup paste change", this, @_checkModified
                @element.bind "keyup mouseup", this, @_checkSelection
                widget = this
                @bound = true

        # Activate an editable for editing
        activate: ->
            @element.focus()

        # Only supports one range for now (i.e. no multiselection)
        getSelection: ->
            if ( jQuery.browser.msie )
                range = document.selection.createRange()
            else
                if ( window.getSelection )
                    userSelection = window.getSelection()
                else if (document.selection) #opera
                    userSelection = document.selection.createRange()
                else
                    throw "Your browser does not support selection handling"

                if ( userSelection.getRangeAt )
                    range = userSelection.getRangeAt(0)
                else
                    range = userSelection

            return range

        restoreSelection: (range) ->
            if ( jQuery.browser.msie )
                range.select()
            else
                window.getSelection().removeAllRanges()
                window.getSelection().addRange(range)

        replaceSelection: (cb) ->
            if ( jQuery.browser.msie )
                t = document.selection.createRange().text;
                r = document.selection.createRange()
                r.pasteHTML(cb(t))
            else
                sel = window.getSelection();
                range = sel.getRangeAt(0);
                newTextNode = document.createTextNode(cb(range.extractContents()));
                range.insertNode(newTextNode);
                range.setStartAfter(newTextNode);
                sel.removeAllRanges();
                sel.addRange(range);

        removeAllSelections: () ->
            if ( jQuery.browser.msie )
                range.empty()
            else
                window.getSelection().removeAllRanges()

        # Get contents of an editable as HTML string
        getContents: ->
           @element.html()

        # Check whether the editable has been modified
        isModified: ->
           @originalContent isnt @getContents()

        # Set the editable as unmodified
        setUnmodified: ->
           @originalContent = @getContents()

        # Restore the content original
        restoreOriginalContent: ->
            @element.html(@originalContent)

        # Execute a contentEditable command
        execute: (command, value) ->
            if document.execCommand command, false, value
                @element.trigger "change"

        _generateUUID: ->
            S4 = ->
                ((1 + Math.random()) * 0x10000|0).toString(16).substring 1
            "#{S4()}#{S4()}-#{S4()}-#{S4()}-#{S4()}-#{S4()}#{S4()}#{S4()}"

        _getToolbarPosition: (event, selection) ->
            if @options.floating
                if event.originalEvent instanceof MouseEvent
                    return { top: event.pageY, left: event.pageX }
                else
                    return this._getCaretPosition(selection)
            else
                top: @element.offset().top - this.toolbar.outerHeight()
                left: @element.offset().left

        _getCaretPosition: (range) ->
            tmpSpan = jQuery "<span/>"
            newRange = document.createRange()
            newRange.setStart range.endContainer, range.endOffset
            newRange.insertNode tmpSpan.get 0

            position = {top: tmpSpan.offset().top, left: tmpSpan.offset().left}
            tmpSpan.remove()
            return position

        _prepareToolbar: ->
            that = @
            @toolbar = jQuery('<div></div>').addClass('halloToolbar').hide()
            @toolbar.css "position", "absolute"
            @toolbar.css "top", @element.offset().top - 20
            @toolbar.css "left", @element.offset().left
            jQuery('body').append(@toolbar)
            @toolbar.bind "mousedown", (event) ->
                event.preventDefault()

            if !@options.floating
                @element.bind "halloactivated", (event, data) ->
                    that._updateToolbarPosition that._getToolbarPosition()
                    that.toolbar.show()

                @element.bind "hallodeactivated", (event, data) ->
                    that.toolbar.hide()

                jQuery(window).resize (event) ->
                    that._updateToolbarPosition that._getToolbarPosition()

            else
                @element.bind "halloselected", (event, data) ->
                    widget = data.editable
                    position = widget._getToolbarPosition data.originalEvent, data.selection
                    if position
                        that._updateToolbarPosition position
                        that.toolbar.show()

                @element.bind "hallounselected", (event, data) ->
                    if not that.options.showAlways
                        data.editable.toolbar.hide()

                jQuery(window).resize (event) ->
                    that.toolbar.hide()

        _updateToolbarPosition: (position) ->
            this.toolbar.css "top", position.top
            this.toolbar.css "left", position.left

        _checkModified: (event) ->
            widget = event.data
            if widget.isModified()
                widget._trigger "modified", null,
                    editable: widget
                    content: widget.getContents()

        _keys: (event) ->
            widget = event.data
            if event.keyCode == 27
                this.disable # TODO: Why doesnt this work? (neither does widget.disable)

        _rangesEqual: (r1, r2) ->
            r1.startContainer is r2.startContainer and r1.startOffset is r2.startOffset and r1.endContainer is r2.endContainer and r1.endOffset is r2.endOffset

        # Check if some text is selected, and if this selection has changed. If it changed,
        # trigger the "halloselected" event
        _checkSelection: (event) ->
            widget = event.data
            sel = widget.getSelection()

            if sel.collapsed is true
                if widget.selection
                    widget.selection = null
                    widget._trigger "unselected", null,
                        editable: widget
                        originalEvent: event
                return

            if !widget.selection or not widget._rangesEqual sel, widget.selection
                widget.selection = sel.cloneRange();
                widget._trigger "selected", null,
                    editable: widget
                    selection: widget.selection
                    ranges: [widget.selection]
                    originalEvent: event

        _activated: (event) ->
            widget = event.data
            jQuery(@).addClass 'inEditMode'
            widget.toolbar.css "width", jQuery(@).width()+26
            widget._trigger "activated", event

        _deactivated: (event) ->
            widget = event.data
            widget.toolbar.hide()
            jQuery(widget.element).removeClass 'inEditMode'
            widget._trigger "deactivated", event

)(jQuery)
