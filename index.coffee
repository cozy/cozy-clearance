# [perm] in 'r', 'w', 'rw'

# a model clearance can be any of
# 'private', only the owner can readwrite it
# public:[perm], anyone can readwrite it
# an array of object
# {key: secretKey, perm:[perm], ...}


randomString = (length=32) ->
    string = ""
    string += Math.random().toString(36).substr(2) while string.length < length
    string.substr 0, length


exports.check = (model, permission, req, callback) ->

    if not model.clearance or model.clearance.length is 0
        return callback null, false

    if model.clearance is 'public'
        return callback null, true

    unless Array.isArray(model.clearance)
        return callback new Error('malformed clearance'), false

    key = req.query.key

    clearance = model.clearance.filter (clearance) ->
        clearance.key is key and
        -1 isnt clearance.perm.indexOf permission

    callback null, clearance[0] or false

exports.make = (model, permission, details) ->
    details ?= {}

    clearance = perm: permission
    clearance[property] = value for own property, value of details
    clearance.key = randomString()

    return clearance

exports.add = (model, permission, details, callback) ->
    [details, callback] = [{}, details] unless callback?
    rule = exports.make model, permission, details

    clearance = model.clearance or []
    clearance = clearance.concat rule

    model.updateAttributes clearance: clearance, (err) ->
        callback err, rule.key

exports.revoke = (model, details, callback) ->

    dontMatch = (clearance) ->
        for own property, value of details
            return true if clearance[property] isnt value
        return false

    clearance = model.clearance.filter(dontMatch)
    model.updateAttributes clearance: clearance, callback

exports.replace = (model, newclearance, callback) ->
    model.updateAttributes clearance: newclearance, callback


exports.controller = require './controller'