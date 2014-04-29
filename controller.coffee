clearance = require './index'
async = require 'async'

americano = require 'americano-cozy'
Contact = americano.getModel 'Contact',
    fn            : String
    n             : String
    _attachments  : (x) -> x
    datapoints    : (x) -> x

# find the cozy adapter
CozyAdapter = try require 'americano-cozy/node_modules/jugglingdb-cozy-adapter'
catch e then require 'jugglingdb-cozy-adapter'


module.exports = (options) ->

    out = {}

    mailSubject = options.mailSubject
    mailTemplate = options.mailTemplate

    # send a share mail
    sendMail = (doc, key, cb) ->
        rule = doc.clearance.filter((rule) -> rule.key is key)[0]

        doc.getPublicURL (err, url) =>
            return cb err if err

            url += '?key=' + rule.key

            mailOptions =
                to: rule.email
                subject: mailSubject {doc, url}
                content: url
                html: mailTemplate {doc, url}

            CozyAdapter.sendMailFromUser mailOptions, cb

    # # add one rule
    # # expect body = {email, contactid, autosend, perm}
    # out.add = (req, res, next) ->
    #     {email, contactid, autosend, perm} = req.body

    #     perm ?= 'r'

    #     clearance.add req.doc, perm, {email, contactid}, (err, key) ->
    #         return next err if err
    #         if not autosend or autosend is 'false'
    #             res.send req.doc
    #         else
    #             req.body.key = key
    #             out.send req, res, next

    # # revoke one rule
    # # expect body = {key}
    # out.revoke = (req, res, next) ->
    #     {key} = req.body
    #     clearance.revoke req.doc, {key}, (err) ->
    #         return next err if err
    #         res.send req.doc

    # # send one mail
    # # expect body = {key}
    # out.send = (req, res, next) ->
    #     {key} = req.body
    #     sendMail req.doc, key, (err) ->
    #         return next err if err
    #         newrules = req.doc.clearance.map (rule) ->
    #             rule.sent = true if rule.key is key
    #             return rule

    #         req.doc.updateAttributes clearance: newrules, (err) ->
    #             return next err if err
    #             res.send req.doc

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
            sendMail req.doc, rule.key, cb
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
                    hasPicture: contact._attachments?.picture?
                    name: name or '?'
                    emails: emails or []

    out.contactPicture = (req, res, next) ->
        Contact.find req.params.contactid, (err, contact) ->
            return next err if err

            unless contact._attachments?.picture
                err = new Error('not found')
                err.status = 404
                return next err

            stream = contact.getFile 'picture', (err) ->
                return res.error 500, "File fetching failed.", err if err
            stream.pipe res

    return out
