from gui.elements.object import QObject
from gui.objects_map import wallet_names


class WalletAccountContextMenu(QObject):

    def __init__(self):
        super().__init__(wallet_names.walletAccountContextMenu)

        self.wallet_account_context_menu = QObject(wallet_names.walletAccountContextMenu)
        self.delete_from_wallet_account_context = QObject(wallet_names.contextMenuItem_Delete)
        self.edit_from_wallet_account_context = QObject(wallet_names.contextMenuItem_Edit)
        self.copy_address_from_wallet_account_context = QObject(wallet_names.contextMenuItem_Copy_Address)
        self.add_watched_address = QObject(wallet_names.addWatchedAddress)
        self.add_new_account = QObject(wallet_names.addNewAccount)