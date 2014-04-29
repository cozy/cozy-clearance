# let's put this here for now
collection = new Backbone.Collection()
collection.url = 'clearance/contacts'

collection.model = class Contact extends Backbone.Model
    match: (filter) ->
        filter.test(@get('name')) or
        @get('emails').some (email) -> filter.test email

collection.fetch()

module.exports = collection