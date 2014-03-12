cozy-clearance
=========

Helper package to manage clearances in cozy. This package include two parts:
- server side
- client side


## Server Side

Base Module : [documentation](http://aenario.github.io/cozy-clearance/)

Controller :
```coffee
# dans routes.coffee
clearance = require 'cozy-clearance'

clearanceCtl = clearance.controller
    sendMail: helpers.sendMail

'docid':
    param: # fetch and save in req.doc
'share/:docid':
    put: clearanceCtl.change
'share/:type/:shareid/send':
    post: clearanceCtl.sendAll

```


## Client Side

Your client side environement should include the following :
- a global require & require.define, following the commonjs convention (like brunch)
- a global `t` function that handles translations

Include the file `client-build.js` or `client-build.min.js` in your
vendor/scripts folder and use it like this :

```coffee
ClearanceModal = require 'cozy-clearance/modal_share_view'
class YourModalView extends ClearanceModal
  type: 'docType'
  doSave: (sendmail, newClearances) =>
    client.put "share/#{@model.id}", clearance: @model.get('clearance'),
        error: -> ModalView.error 'server error occured'
        success: (data) =>
            if not sendmail
                @$el.modal 'hide'
            else
                client.post "share/#{@model.id}/send", newClearances,
                    error: -> ModalView.error 'mail not send'
                    success: (data) =>
                        @$el.modal 'hide'
```

## Contribute

Use [coffeegulp](https://github.com/minibikini/coffeegulp) to build the client
side.

Use npm run build to build the server side

use npm test to run tests