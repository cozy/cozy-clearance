Modal = require "./modal"
contactTypeahead = require "./contact_autocomplete"
contactCollection = require "./contact_collection"

## Helpers

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
    return now.filter (rule) ->
        not _.findWhere old, key: rule.key


# convenient method for json requests
request = (method, url, data, options) ->
    params =
        method: method
        url: url
        dataType: 'json'
        data: JSON.stringify(data)
        contentType: 'application/json; charset=utf-8'
    $.ajax _.extend params, options


## Modal

# Modal to allow users to manage clearance on given model. A clearance object
# is set as a model attribute.
# A clearance is set to
# * 'public' if there is a single link to share with any contacts
# * an empty array or null if the model is in a private state (no one except
#   the cozy owner can access to the mode.
# * an array of object describing the clearance: one for for every people with
#   whom the model is shared. Object fields: contact id, email, access key,
#   and permissions ('r' or 'rw').
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

    # Permissions are read only by default.
    permissions: ->
        'r': t('r')

    initialize: (options) ->
        @cb = @onClose
        @model = options.model
        @model.set 'clearance', @model.get('clearance') or []
        # keep the initState for cancellation
        @initState = JSON.parse JSON.stringify @model.get 'clearance'
        @title = t 'sharing'
        @yes = t 'save'
        @no = t 'cancel'
        super

    ## Render

    getRenderData: =>
        type: @model.get('type')
        model: @model
        clearance: @getClearanceWithContacts()
        makeURL: @makeURL
        possible_permissions: @permissions()
        t: t

    # TODO: find why it isn't displayed.
    render: ->
        super()
        $('.email-hint').remove()
        $('.modal-footer').prepend $("<span class='pull-left email-hint'>#{t 'send email hint'}</span>")

    # This method is aimed to be overrriden.
    renderContent: ->
        $ '<p>Please wait</p>'

    # Performs several operations:
    # * Change the toggled button state.
    # * Configure the contact field autocomplete type ahead.
    # * Focus on the url or contact field depending on the configuration.
    afterRender: ->
        clearance = @model.get('clearance') or []

        @_checkToggleButtonState clearance
        @_configureTypeAhead clearance
        @_firstFocus clearance

        if @isPublicClearance()
            @$('.public-url').show()
            $('.email-hint').hide()
        else
            @$('.public-url').hide()
            if @isPrivateClearance()
                $('.email-hint').hide()
            else
                $('.email-hint').show()

    # Change the toggled button state depending on current clearance.
    _checkToggleButtonState: (clearance) ->
        if typeof(clearance) is "object" and clearance.length is 0
            @$('#share-private').addClass 'toggled'
        else
            @$('#share-public').addClass 'toggled'

    # Configure the contact field autocomplete type ahead.
    _configureTypeAhead: (clearance) ->
        if typeof(clearance) isnt "object" or clearance.length > 0
            input = @$('#share-input')
            contactTypeahead input, @onGuestAdded, @typeaheadFilter

    # Focus on the url or contact field depending on the configuration.
    _firstFocus: (clearance) ->
        setTimeout =>
            if @isPublicClearance()
                @$('#public-url').focus().select()
            else if clearance.length > 0
                @$('input#share-input').select()
        , 200

    # Rebuild render data and rerender the modal body.
    refresh: ->
        @$('.modal-body').html @template_content @getRenderData()
        @afterRender()

    ## Modes

    # Display the modal public mode.
    makePublic: ->
        if @lastClearance?
            @model.set clearance: @lastClearance
        else
            @model.set clearance:'public'
        @refresh()

    # Display the modal private mode.
    makePrivate: ->
        if (@model.get 'clearance' is 'public')
            @lastClearance = @model.get 'clearance'
            @model.set clearance: []
            @refresh()

    ## Helpers

    # Build a clearance url for given key. Key is passed as a query parameter.
    # If no key is given, no parameter is set on the URL.
    makeURL: (key) =>
        url = @model.getPublicURL()
        url += '?key=' + key if key
        return url

    # Display contact in the autocmplete combo only his email is not in the
    # current contact list.
    typeaheadFilter: (item) =>
        not @existsEmail item.toString().split(';')[0]

    # True if the mail is not the current clearance contact list.
    existsEmail: (email) =>
        _.some @model.get('clearance'), (rule) ->
            rule.email is email

    # For each clearance object (rule), it checks if a Cozy Contact is linked
    # to it. It adds a field pointing on it in that case.
    # Warning clearance is wrongly typed. In public mode, clearance is a
    # string. In other modes, it's an array of objects.
    getClearanceWithContacts: (clearance) =>
        unless clearance?
            clearance = @model.get('clearance') or []

        if typeof(clearance) is "object"
            clearance = clearance.map (rule) ->
                out = _.clone rule
                if out.contactid
                    out.contact = contactCollection.get rule.contactid
                out
        return clearance

    # Save changes to server and send mail to guests if needed.
    doSave: (sendmail, clearances) ->
        request 'PUT', "clearance/#{@model.id}", @saveData(),
            error: -> Modal.error(t 'server error occured')
            success: (data) =>
                # force rerender of the view because this request
                # doesn't trigger the set
                @model.trigger 'change', @model
                if not sendmail then @$el.modal 'hide'
                else
                    request 'POST', "clearance/#{@model.id}/send", clearances,
                        error: -> Modal.error(t 'mail not send')
                        success: (data) => @$el.modal 'hide'

    # Returns data to save.
    saveData: ->
        clearance: @model.get('clearance')

    # Display link widget for given contact in the guest list.
    showLink: (event) ->
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

    # Returns true clearance is set as public
    isPublicClearance: ->
        @model.get('clearance') is 'public'

    # Returns true clearance is set as public
    isPrivateClearance: ->
        clearance = @model.get('clearance')
        typeof(clearance) is "object" and clearance.length is 0

    ## Events

    onAddClicked: ->
        @onGuestAdded @$('#share-input').val()


    # When a guest is added, it adds a new rule to the current model clearance
    # list.
    onGuestAdded: (result) =>
        [email, contactid] = result.split ';'
        isEmailEmpty = email is '' or email.indexOf('@') < 1

        unless @existsEmail(email) or isEmailEmpty
            key = randomString()
            perm = 'r'

            if @isPublicClearance()
                clearance = []
            else
                clearance = @model.get('clearance')
            clearance.push {contactid, email, key, perm}
            @model.set clearance: clearance
            @refresh()
        else
            return null

    # Remove a rule from current model clearance list.
    revoke: (event) =>
        clearance = @model.get('clearance')
            .filter (rule) -> rule.key isnt event.currentTarget.dataset.key


        if clearance.length is 0
            @model.set clearance: 'public'
        else
            @model.set clearance: clearance
        @refresh()

    # Change permission for given contact. Contact is find via the click
    # event give in parameter.
    changePerm: (event) ->
        select = event.currentTarget
        @model.get('clearance')
            .filter((rule) -> rule.key is select.dataset.key)[0]
            .perm = select.options[select.selectedIndex].value
        @refresh()

    # When modal is closed, changes are discarded. A confirmation is requested
    # to the user.
    onNo: =>
        clearance = @model.get('clearance')
        diffNews = clearanceDiff(clearance, @initState).length isnt 0
        diffLength = clearance.length isnt @initState.length

        hasChanged = diffNews or diffLength

        if hasChanged
            Modal.confirm t("confirm"), t('share confirm save'), \
                t("yes"), t("no"), (confirmed) =>
                    super if confirmed
        else
            super

    onYes: =>
        clearance = @model.get('clearance')
        diffNews = clearanceDiff(clearance, @initState).length isnt 0
        if @$('#share-input').val() and not diffNews
            # nothing new and share-input is filled
            # may be the user forgot to click add / press enter
            Modal.confirm t("confirm"), t('share forgot add'), \
                t("no forgot"), t("yes forgot"), (confirmed) =>
                    super if confirmed
        else
            super

    onClose: (saving) =>
        if not saving
            @model.set clearance: @initState
        else
            newClearances = clearanceDiff @model.get('clearance'), @initState
            if newClearances.length
                text = t("send mails question") + newClearances
                    .map (rule) -> rule.email
                    .join ', '

                Modal.confirm t("modal send mails"), text, \
                    t("yes"), t("no"), (sendmail) =>
                        @doSave sendmail, newClearances

            else
                @doSave false

