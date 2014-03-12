clearance = require './index'
async = require 'async'
americano = require 'americano'

Contact = americano.getModel 'Contact',
    fn            : String
    n             : String
    datapoints    : (x) -> x

module.exports = (options) ->

    sendMail = options.sendMail
    out = {}

    out.details = (req, res, next) ->
        async.parallel
            domain: (cb) -> req.doc.getPublicUrl cb
            self: (cb) -> cb null, req.doc.clearance
        , (err, result) ->
            return next err if err
            res.send result

    # add one rule
    # expect body = {email, contactid, autosend}
    out.add = (req, res, next) ->
        {email, contactid, autosend} = req.body

        clearance.add req.doc, 'r', {email, contactid}, (err, key) ->
            return next err if err
            if not autosend or autosend is 'false'
                res.send req.doc
            else
                req.body.key = key
                out.send req, res, next

    # revoke one rule
    # expect body = {key}
    out.revoke = (req, res, next) ->
        {key} = req.body
        clearance.revoke req.doc, {key}, (err) ->
            return next err if err
            res.send req.doc

    # send one mail
    # expect body = {key}
    out.send = (req, res, next) ->
        {key} = req.body
        sendMail req.params.type, req.doc, key, (err) ->
            return next err if err
            newrules = req.doc.clearance.map (rule) ->
                rule.sent = true if rule.key is key
                return rule

            req.doc.updateAttributes clearance: newrules, (err) ->
                return next err if err
                res.send req.doc

    # change the whole clearance object
    out.change = (req, res, next) ->
        {clearance} = req.body
        req.doc.updateAttributes clearance: clearance, (err) ->
            return next err if err
            res.send req.doc

    # send multiple mails
    # expect body = [<rule>]
    out.sendAll = (req, res, next) ->
        toSend = req.body
        sent = []
        async.each toSend, (rule, cb) ->
            sent.push rule.key
            sendMail req.params.type, req.doc, rule.key, cb
        , (err) ->
            return next err if err
            newClearance = req.doc.clearance.map (rule) ->
                rule.sent = true if rule.key in sent
                return rule

            req.doc.updateAttributes clearance: newClearance, (err) ->
                    return next err if err
                    res.send req.doc

    # contact list for autocomplete
    out.contactList = (req, res, next) ->
        Contact.request 'all', (err, contacts) ->
            return next err if err
            res.send contacts.map (contact) ->
                name = contact.fn or contact.n?.split(';')[0..1].join(' ')
                emails = contact.datapoints?.filter (dp) -> dp.name is 'email'
                emails = emails.map (dp) -> dp.value
                return simple =
                    id: contact.id
                    name: name or '?'
                    emails: emails or []

    return out
