from gui.objects_map.names import statusDesktop_mainWindow

# Map for home screens, views locators

# HomePage Container
home_container = {"container": statusDesktop_mainWindow, "objectName": "homeContainer", "type": "HomePage", "visible": True}
home_search_field = {"container": statusDesktop_mainWindow, "objectName": "homeSearchField", "type": "HomePageSearchField", "visible": True}

# HomePage Grid
home_grid = {"container": home_container, "objectName": "homeGrid", "type": "HomePageGrid", "visible": True}
home_grid_item = {"container": home_grid, "type": "HomePageGridItem", "visible": True}
home_grid_item_pin_button = {"container": home_grid_item, "type": "HomePageToolButton", "visible": True}

# HomePage Grid Context Menu
home_grid_item_context_menu = {"type": "StatusMenu", "visible": True}
home_grid_item_pin_menu_action = {"container": home_grid_item_context_menu, "text": "Pin", "type": "StatusMenuItem", "visible": True}
home_grid_item_unpin_menu_action = {"container": home_grid_item_context_menu, "text": "Unpin", "type": "StatusMenuItem", "visible": True}

# HomePage Dock
home_dock = {"container": statusDesktop_mainWindow, "type": "ListView", "visible": True}
home_profile = {"checkable": True, "container": statusDesktop_mainWindow, "objectName": "homeProfileButton", "type": "ProfileButton", "visible": True}

# Regular Dock Buttons
home_regular_dock_button_wallet = {"container": statusDesktop_mainWindow, "objectName": "regularDockButtonWallet", "type": "HomePageDockButton", "visible": True}
home_regular_dock_button_market = {"container": statusDesktop_mainWindow, "objectName": "regularDockButtonMarket", "type": "HomePageDockButton", "visible": True}
home_regular_dock_button_messages = {"container": statusDesktop_mainWindow, "objectName": "regularDockButtonMessages", "type": "HomePageDockButton", "visible": True}
home_regular_dock_button_communities = {"container": statusDesktop_mainWindow, "objectName": "regularDockButtonCommunities Portal", "type": "HomePageDockButton", "visible": True}
home_regular_dock_button_settings = {"container": statusDesktop_mainWindow, "objectName": "regularDockButtonSettings", "type": "HomePageDockButton", "visible": True}

# TODO: Methods for pinned dock buttons https://github.com/status-im/status-app/issues/18239
home_pinned_dock_button_ = {"container": statusDesktop_mainWindow, "objectName": "pinnedDockButton", "type": "HomePageDockButton", "visible": True}

# Generic Dock Button Locators
home_any_regular_dock_button = {"container": statusDesktop_mainWindow, "type": "HomePageDockButton", "pinned": False, "visible": True}
home_any_pinned_dock_button = {"container": statusDesktop_mainWindow, "type": "HomePageDockButton", "pinned": True, "visible": True}
home_pinned_dock_button = {"container": statusDesktop_mainWindow, "type": "HomePageDockButton", "pinned": True, "visible": True}
home_generic_dock_button = {"container": statusDesktop_mainWindow, "type": "HomePageDockButton", "visible": True}

# Dock Button Context Menu
home_dock_button_context_menu = {"type": "StatusMenu", "visible": True}
home_dock_button_unpin_menu_action = {"container": home_dock_button_context_menu, "text": "Unpin", "type": "StatusAction", "visible": True}
home_dock_button_disconnect_menu_action = {"container": home_dock_button_context_menu, "text": "Disconnect", "type": "StatusAction", "visible": True}
