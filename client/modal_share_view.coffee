Modal = require "./modal"
contactTypeahead = require "./contact_autocomplete"
contactCollection = require "./contact_collection"

# randomString for immediate key generation
randomString = (length=32) ->
    string = ""
    string += Math.random().toString(36).substr(2) while string.length < length
    string.substr 0, length

# find new clearances between now and old
clearanceDiff = (now, old) ->
    if now is 'public'
        return []
    if old is 'public'
        return now
    # return only rules that did not exist in init state
    return now.filter (rule) -> not _.findWhere old, key: rule.key

# convenient method for json requests
request = (method, url, data, options) ->
    params = {
        method: method,
        url: url,
        dataType: 'json'
        data: JSON.stringify(data)
        contentType: 'application/json; charset=utf-8'
    }
    $.ajax _.extend params, options

module.exports = class CozyClearanceModal extends Modal

    id: 'cozy-clearance-modal'
    template_content: require './modal_share_template'

    events: -> _.extend super,
        "click #share-public": "makePublic"
        "click #share-private": "makePrivate"
        'click #modal-dialog-share-save': 'onSave'
        'click .revoke': 'revoke'
        'click .show-link': 'showLink'
        'click #add-contact': 'onAddClicked'
        'change select.changeperm': 'changePerm'

    permissions: ->
        'r': t('r')

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
        return if @model.get('clearance') is 'public'
        @lastPrivate = @model.get('clearance')
        @model.set clearance:'public'
        @refresh()

    makePrivate: ->
        return if Array.isArray(@model.get('clearance'))
        @model.set clearance: @lastPrivate or []
        @refresh()

    afterRender: () ->
        clearance = @model.get('clearance') or []
        if clearance is 'public'
            @$('#share-public').addClass 'toggled'
            @$('input.form-control').focus().select()
        else
            @$('input#share-input').select()
            @$('#share-private').addClass 'toggled'
            contactTypeahead @$('#share-input'), @onGuestAdded, @typeaheadFilter

    renderContent: -> $ '<p>Please wait</p>'

    typeaheadFilter: (item) =>
        not @existsEmail item.toString().split(';')[0]

    existsEmail: (email) ->
        @model.get('clearance').some (rule) -> rule.email is email

    getRenderData: =>
        type: @model.get('type')
        model: @model
        clearance: @getClearanceWithContacts()
        makeURL: @makeURL
        possible_permissions: @permissions()
        t: t

    getClearanceWithContacts: =>
        clearance = @model.get('clearance') or []
        return 'public' if clearance is 'public'

        clearance.map (rule) ->
            out = _.clone rule
            if out.contactid
                out.contact = contactCollection.get rule.contactid

            return out

    refresh: ->
        @$('.modal-body').html @template_content @getRenderData()
        @afterRender()

    onAddClicked: ->
        @onGuestAdded @$('#share-input').val()

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

    changePerm: (event) ->
        select = event.currentTarget
        @model.get('clearance')
            .filter((rule) -> rule.key is select.dataset.key)[0]
            .perm = select.options[select.selectedIndex].value
        @refresh()

    onClose: (saving) =>
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

    doSave: (sendmail, clearances) ->
        request 'PUT', "clearance/#{@model.id}", @saveData(),
            error: -> Modal.error 'server error occured'
            success: (data) =>
                # force rerender of the view because this request
                # doesn't trigger the set
                @model.trigger 'change'
                if not sendmail then @$el.modal 'hide'
                else
                    request 'POST', "clearance/#{@model.id}/send", clearances,
                        error: -> Modal.error 'mail not send'
                        success: (data) => @$el.modal 'hide'

    saveData: -> clearance: @model.get('clearance')

    showLink: (event) =>
        line = $(event.target).parents('li')
        if line.find('.linkshow').length is 0
            link = $(event.currentTarget)
            url = link.prop 'href'

            line = $('<div class="linkshow">')
            label = $('<label>').text(t 'copy paste link')
            urlField = $('<input type="text">')
                .val(url)

            link.parents('li').append line.append label, urlField
            urlField.focus().select()
            event.preventDefault()
        else
           line.find('.linkshow').remove()

        return false
