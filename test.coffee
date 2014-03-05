should = require 'should'
clearance = require './index'
americano = require 'americano-cozy'

model = null
rule = null
secretkey = null
janekey = null
stevekey = null

describe 'Basics', ->

    it "cozy-clearance exports the functions", ->
        should.exist clearance.check
        should.exist clearance.make
        should.exist clearance.add
        should.exist clearance.revoke
        return

    it "it works on americano-cozy models", (done) ->
        Model = americano.getModel 'test',
            name: String
            clearance: (x) -> x

        Model.create name: 'testdoc', (err, created) ->
            model = created
            done(err)
        return

describe 'The clearance object', ->

    it "cozy-clearance allows to make a clearance object", ->

        arbitraryIdentifiers =
            'email': 'john@example.com'
            'contactid': '3615'

        rule = clearance.make model, 'r', arbitraryIdentifiers
        return

    it "and this clearance have identifiers, perm and a secret key", ->

        rule.should.have.property 'perm', 'r'
        rule.should.have.property 'email', 'john@example.com'
        rule.should.have.property 'contactid', '3615'
        rule.should.have.property 'key'
        return

describe 'Adding clearance to a model', ->

    it "cozy-clearance allows to directly add clearance to an object", (done) ->

        arbitraryIdentifiers =
            'email': 'john@example.com'
            'contactid': '3615'

        clearance.add model, 'r', arbitraryIdentifiers, (err, key) ->
            should.exist key
            secretkey = key
            done err

        return

    it "the rules are stored as an array of rules", ->

        model.clearance.should.have.property 'length', 1

        rule = model.clearance[0]

        rule.should.have.property 'perm', 'r'
        rule.should.have.property 'email', 'john@example.com'
        rule.should.have.property 'contactid', '3615'
        rule.should.have.property 'key'
        return

    it "so we can add multiple clearances", (done) ->

        jane = email: 'jane@example.com'
        steve = email: 'steve@example.com'

        clearance.add model, 'rw', jane, (err, key) ->
            return done err if err
            janekey = key
            clearance.add model, 'w', steve, (err, key) ->
                stevekey = key

                model.clearance.should.have.length 3

                done err

        return

describe 'Checking clearances', ->

    it "cozy-clearance allows to check clearance for a request", ->

        req = query: key: secretkey

        clearance.check model, 'r', req, (err, rule) ->
            rule.should.be.ok
            rule.should.have.property 'perm', 'r'
            rule.should.have.property 'email', 'john@example.com'
            rule.should.have.property 'key'
        return

    it "if the key is wrong, rule will be false", ->

        req = query: key: "not a key"

        clearance.check model, 'r', req, (err, rule) ->
            rule.should.not.be.ok
        return

    it "if the perm is wrong, rule will be false", ->

        req = query: key: secretkey

        clearance.check model, 'w', req, (err, rule) ->
            rule.should.not.be.ok

        return

    it "retrieve correct rule for a given key", (done) ->
        req = query: key: janekey
        clearance.check model, 'r', req, (err, rule) ->
            rule.should.have.property 'email', 'jane@example.com'
            done err

        return

    it "'rw' perm allows both read and write", (done) ->
        req = query: key: janekey
        clearance.check model, 'w', req, (err, rule) ->
            rule.should.have.property 'email', 'jane@example.com'
            done err

        return

describe 'Revoking a clearance', ->

    it "cozy-clearance allows to revoke a rule", ->
        clearance.revoke model, email: 'jane@example.com', (err) ->
            done err

        return

    it "then I can't use this key anymore", (done) ->
        req = query: key: janekey
        clearance.check model, 'r', req, (err, rule) ->
            rule.should.be.false
            done err

        return


