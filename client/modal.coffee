class Modal extends Backbone.View

    id:'modal-dialog'
    className:'modal fade'

    initialize: (options) ->
        @title ?= options.title
        @content ?= options.content
        @yes ?= options.yes or 'ok'
        @no ?= options.no or 'cancel'
        @cb ?= options.cb or ->
        @render()
        @saving = false
        @$el.modal 'show'
        @$el.one 'hide.bs.modal', =>
            setTimeout (=> @remove()), 1000
            @cb @saving

    events: ->
        "click #modal-dialog-no"  : =>
            @$el.modal 'hide'
        "click #modal-dialog-yes" : =>
            @saving = true
            @$el.modal 'hide'

    render: ->
        close = $('<button class="close" type="button" data-dismiss="modal" aria-hidden="true">×</button>')
        title = $('<h4 class="model-title">').text @title
        head  = $('<div class="modal-header">').append close, title
        body  = $('<div class="modal-body">').append @renderContent()
        yesBtn= $('<button id="modal-dialog-yes" class="btn btn-cozy">').text @yes
        foot  = $('<div class="modal-footer">').append yesBtn

        foot.prepend $('<button id="modal-dialog-no" class="btn btn-link">').text(@no) if @no

        container = $('<div class="modal-content">').append head, body, foot
        container = $('<div class="modal-dialog">').append container
        $("body").append @$el.append container

    renderContent: -> @content

Modal.alert = (title, content, cb) ->
    new Modal {title, content, yes: 'ok', no: null, cb}

Modal.confirm = (title, content, yesMsg, noMsg, cb) ->
    new Modal {title, content, yes: yesMsg, no:noMsg, cb}

Modal.error = (text, cb) ->
    new ModalView t("modal error"), text, t("modal ok"), false, cb


module.exports = Modal