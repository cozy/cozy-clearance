cozy-clearance
=========

Helper package to manage clearances in cozy. This package include two parts:
- server side
- client side


## Usage : Server Side

### Base Module
[documentation](http://aenario.github.io/cozy-clearance/)
```coffee
clearance = require 'cozy-clearance'

details  = {email:"steve@exemple.com", contactid:"3615", any:"other field"}
details2 = {email:"jane@exemple.com", contactid:"3616", any:"other field"}
```

The clearance.add function allows you to add a rule to a model
```coffee
clearance.add someModel, 'rw', details, (err) ->
    clearance.add someModel, 'r', details2, (err) ->
        console.log someModel.clearance
# [
#     {email:"steve@exemple.com", contactid:"3615", any:"other field", key:"secret", perm:"rw"}
#     {email:"jane@exemple.com", contactid:"3616", any:"other field", key:"secret2", perm:"rw"}
# ]
```

The clearance.check function allows you to check a request against the model.
It looks for the key in the request's querystring
The callback is called with the matching rule if found, false otherwise
```coffee
req.query.key = "secret"
clearance.check someModel, 'r', req, (err, rule) ->
    # rule == {email:"steve@exemple.com", contactid:"3615", any:"other field", key:"secret", perm:"rw"}

clearance.check someModel, 'w', req, (err, rule) ->
    # rule == false, steve doesn't have the 'w' permission
```

The clearance.revoke function allows you to revoke a rule for the model.
All rules matching the given object will be revoked
```coffee
clearance.revoke someModel, {email:"steve@exemple.com"}, (err) ->
    console.log someModel.clearance
    # [{email:"jane@exemple.com", contactid:"3616", any:"other field", key:"secret2", perm:"rw"}]

# or

clearance.revoke someModel, {any:"other field"}, (err) ->
    console.log someModel.clearance
    # []
```

### Controller :

To use the client side of cozy-clearance, you will need to expose some of the controller's routes.
```coffee
# in routes.coffee
clearance = require 'cozy-clearance'

# use mailSubject & mailTemplate functions to customize the sent mail.
clearanceCtl = clearance.controller
    mailSubject: (options) -> # options.doc , options.url
    mailTemplate: (options) -> # options.doc , options.url

'docid':
    param: # fetch and save in req.doc
'clearance/contacts':
    get: clearanceCtl.contactList
'clearance/:docid'
    put: clearanceCtl.change
'clearance/:docid/send':
    post: clearanceCtl.sendAll

```


## Usage : Client Side

Your client side environement should include the following :
- a global  `require & require.define`, following the commonjs convention (like brunch)
- a global `t` function that handles translations

Include the file `client-build.js` or `client-build.min.js` in your
vendor/scripts folder and use it like this :

```coffee
CozyClearanceModal = require 'cozy-clearance/modal_share_view'
new CozyClearanceModal model: someModel
```
You can override some methods :
```coffee
class YourModalView extends CozyClearanceModal

    # change the permissions method to add possible permissions
    permissions: ->
        'r': 'see this'
        'rw': 'see and edit'
        'rwy': 'see, edit and do Y'
        'rwz': 'see, edit and do Z'
        # note : list all possible combinations, here, you can't have both Y & Z permissions

```
See [cozy-files](https://github.com/mycozycloud/cozy-files/blob/master/client/app/views/modal_share.coffee) for heavy customization.

## Contribute

Use [coffeegulp](https://github.com/minibikini/coffeegulp) to build the client
side.

Use npm run build to build the server side

use npm test to run tests