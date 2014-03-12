Modal = require "./modal"
contactTypeahead = require "./contact_autocomplete"

# find new clearances between now and old

randomString = (length=32) ->
    string = ""
    string += Math.random().toString(36).substr(2) while string.length < length
    string.substr 0, length

clearanceDiff = (now, old) ->
    if now is 'public'
        return []
    if old is 'public'
        return now
    # return only rules that did not exist in init state
    return now.filter (rule) -> not _.findWhere old, key: rule.key

module.exports = class CozyClearanceModal extends Modal

    template_content: require './modal_share_template'

    events: -> _.extend super,
        "click #share-public": "makePublic"
        "click #share-private": "makePrivate"
        'click #modal-dialog-share-save': 'onSave'
        'click .revoke': 'revoke'
        'click .show-link': 'showLink'

    initialize: (options) ->
        @cb = @onClose
        @model = options.model
        # keep the initState for cancellation
        @model.set 'clearance', @model.get('clearance') or []
        @initState = JSON.parse JSON.stringify @model.get 'clearance'
        @title = t 'sharing'
        @yes = t 'save'
        @no = t 'cancel'
        super

    makeURL: (key) =>
        url = @model.getPublicURL()
        url += '?key=' + key if key
        return url

    makePublic: ->
        return if @forcedPublic or @model.get('clearance') is 'public'
        @lastPrivate = @model.get('clearance')
        @model.set clearance:'public'
        @refresh()

    makePrivate: ->
        return if Array.isArray(@model.get('clearance'))
        @model.set clearance: @lastPrivate or []
        @refresh()

    afterRender: () ->
        clearance = @model.get('clearance') or []
        if @forcedPublic or clearance is 'public'
            @$('#share-public').addClass 'toggled'
        else
            @$('#share-private').addClass 'toggled'
            contactTypeahead @$('#share-input'), @onGuestAdded, @typeaheadFilter

    renderContent: -> $ '<p>Please wait</p>'

    typeaheadFilter: (item) =>
        not @existsEmail item.toString().split(';')[0]

    existsEmail: (email) ->
        @model.get('clearance').some (rule) -> rule.email is email


    refresh: (data) ->
        @model.set data if data
        @$('.modal-body').html @template_content
            type: @model.get('type')
            model: @model
            forcedPublic: @forcedPublic
            inherited: @inherited
            makeURL: @makeURL
            t: t
        @afterRender()

    onGuestAdded: (result) =>
        [email, contactid] = result.split ';'
        return null if @existsEmail email
        key = randomString()
        perm = 'r'

        @model.get('clearance').push {email, contactid, key, perm}
        @refresh()

    revoke: (event) =>
        clearance = @model.get('clearance')
            .filter (rule) -> rule.key isnt event.currentTarget.dataset.key

        @model.set clearance: clearance
        @refresh()

    onClose: (saving) =>
        console.log "HERE", saving
        if not saving
            @model.set clearance: @initState
        else
            newClearances = clearanceDiff @model.get('clearance'), @initState
            if newClearances.length
                text = t("send mails question") + newClearances
                    .map (rule) -> rule.email
                    .join ', '

                Modal.confirm t("modal send mails"), text, t("yes"), t("no"), (sendmail) =>
                    @doSave sendmail, newClearances
            else
                @doSave false

    showLink: (event) =>
        link = $(event.currentTarget)
        url = link.prop 'href'

        line = $('<div class="linkshow">')
        label = $('<label>').text(t 'copy paste link')
        urlField = $('<input type="text">')
            .val(url)
            .blur (e) ->
                line.remove()

        link.parents('li').append line.append label, urlField
        urlField.focus().select()
        event.preventDefault()
        return false


