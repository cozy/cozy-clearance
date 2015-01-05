# let's put this here for now
collection = new Backbone.Collection()
collection.url = 'clearance/contacts'

collection.model = class Contact extends Backbone.Model
    urlRoot: 'clearance/contacts'
    match: (filter) ->
        filter.test(@get('name')) or
        @get('emails').some (email) -> filter.test email

collection.fetch()
collection.handleRealtimeContactEvent = (event) ->
    {doctype, operation, id} = event
    return null unless doctype is 'contact'
    switch operation
        when 'create'
            model = new Contact(id: id)
            model.fetch success: (fetched) ->
                collection.add model
        when 'update'
            model = collection.get id
            model.fetch()
        when 'delete'
            model = collection.get id
            collection.remove model


module.exports = collection