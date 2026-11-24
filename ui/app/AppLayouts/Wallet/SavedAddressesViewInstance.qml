import utils

import "views"

SavedAddressesView {
    onSendToAddressRequested: address => Global.sendToRecipientRequested(address)
}
