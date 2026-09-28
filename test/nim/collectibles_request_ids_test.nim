import unittest
import nimqml
from seaqt/qcoreapplication import QCoreApplication, create

import app/core/eventemitter
import app/modules/main/profile_section/contacts/module as contacts_module
import app/modules/main/profile_section/wallet/accounts/module as accounts_module

discard QCoreApplication.create()

suite "collectibles request ids":
  test "profile accounts and contacts showcase don't share a collectibles request id":
    let events = createEventEmitter()
    let accounts = accounts_module.newModule(nil, events, nil, nil)
    let contacts = contacts_module.newModule(nil, events, nil, nil, nil)
    contacts.delete()
    accounts.delete()
