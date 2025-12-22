from scripts.global_names import *

# Main:
navBarListView_Communities_Portal_navbar_PrimaryNavSidebarButton = {"checkable": True, "container": mainWindow_navBarListView_ListView, "objectName": "Communities Portal-navbar", "type": "PrimaryNavSidebarButton", "visible": True}
mainWindow_communitiesPortalLayoutContainer_CommunitiesPortalLayout = {"container": statusDesktop_mainWindow, "objectName": "communitiesPortalLayout", "type": "CommunitiesPortalLayout"}
communitiesPortalLayoutContainer_createCommunityButton_StatusButton = {"container": mainWindow_communitiesPortalLayoutContainer_CommunitiesPortalLayout, "objectName": "createCommunityButton", "type": "StatusButton", "visible": True}
navBarListView_All_Community_Buttons = {"checkable": True, "container": mainWindow_communityNavBarListView_ListView, "objectName": "CommunityNavBarButton", "type": "PrimaryNavSidebarButton"}

# Create community intermediate popup:
createCommunity_banner = {"container": statusDesktop_mainWindow_overlay, "objectName": "createCommunityBanner", "type": "BannerPanel", "visible": True}
createCommunity_bannerButton = {"container": createCommunity_banner, "objectName": "communityBannerButton", "type": "StatusButton", "visible": True}

# Create community popup:
createCommunityNameInput_TextEdit = {"container": statusDesktop_mainWindow_overlay, "objectName": "communityNameInput", "type": "TextEdit", "visible": True}
createCommunityDescriptionInput_TextEdit = {"container": statusDesktop_mainWindow_overlay, "objectName": "communityDescriptionInput", "type": "TextEdit", "visible": True}
createCommunityIntroMessageInput_TextEdit = {"container": statusDesktop_mainWindow_overlay, "objectName": "createCommunityIntroMessageInput", "type": "TextEdit", "visible": True}
createCommunityOutroMessageInput_TextEdit = {"container": statusDesktop_mainWindow_overlay, "objectName": "createCommunityOutroMessageInput", "type": "TextEdit", "visible": True}
createCommunityNextBtn_StatusButton = {"container": statusDesktop_mainWindow_overlay, "objectName": "createCommunityNextBtn", "type": "StatusButton", "visible": True}
createCommunityFinalBtn_StatusButton = {"container": statusDesktop_mainWindow_overlay, "objectName": "createCommunityFinalBtn", "type": "StatusButton", "visible": True}
