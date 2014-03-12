# let's put this here for now
contactCollection = new Backbone.Collection()
contactCollection.url = 'contacts'
contactCollection.model = class Contact extends Backbone.Model
    match: (filter) ->
        filter.test(@get('name')) or
        @get('emails').some (email) -> filter.test email
contactCollection.fetch()

module.exports = (input, onGuestAdded, extrafilter) ->

    extrafilter ?= -> true

    # email not in contact
    input.on 'keyup', (event) =>
        if event.which is 13 and not input.data('typeahead').shown
            onGuestAdded input.val()
            input.val ''
            event.preventDefault()

    # contact typeahead
    input.typeahead
        source: (query) ->
            regexp = new RegExp(query);
            contacts = contactCollection.filter((contact) -> contact.match regexp)
            items = []
            contacts.forEach (contact) ->
                contact.get('emails').forEach (email) ->
                    items.push
                        id: contact.id
                        display: "#{contact.get 'name'} &lt;#{email}&gt;"
                        toString: -> "#{email};#{contact.id}"

            items = items.filter extrafilter

            return items
        matcher: (contact) ->
            old = $.fn.typeahead.Constructor::matcher
            return old.call this, contact.display
        sorter: (contacts) ->
            beginswith = []
            caseSensitive = []
            caseInsensitive = []

            while (contact = contacts.shift())
                item = contact.display
                if !item.toLowerCase().indexOf this.query.toLowerCase()
                    beginswith.push contact
                else if ~item.indexOf this.query then caseSensitive.push contact
                else caseInsensitive.push contact

            return beginswith.concat caseSensitive, caseInsensitive

        highlighter: (contact) ->
            old = $.fn.typeahead.Constructor::highlighter
            return old.call this, contact.display

        updater: (value) =>
            onGuestAdded value
            return ""