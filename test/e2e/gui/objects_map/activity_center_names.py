from gui.objects_map.names import statusDesktop_mainWindow
from objectmaphelper import *

# Map for activity center

activityCenterPanel = {"container": statusDesktop_mainWindow, "objectName": "activityCenterPanel", "type": "ActivityCenterPanel", "visible": True}
activityCenterCloseButton = {"container": activityCenterPanel, "objectName": "closeButton", "type": "StatusFlatRoundButton", "visible": True}
activityCenterListView = {"container": activityCenterPanel, "objectName": "listView", "type": "StatusListView", "visible": True}
activityCenterListLoader = {"container": activityCenterListView, "index": 0, "type": "Loader", "unnamed": 1, "visible": True}
activityCenterNotificationCard = {"container": activityCenterListView, "objectName": "notificationCard", "type": "NotificationCard", "visible": True}
activityCenterQuickActions = {"container": activityCenterNotificationCard, "objectName": "quickActions", "type": "RowLayout", "visible": True}

notificationCardAcceptButton = {"container": activityCenterQuickActions, "objectName": "notificationAcceptBtn", "type": "StatusButton",}
notificationCardDeclineButton = {"container": activityCenterQuickActions, "objectName": "notificationDeclineBtn", "type": "StatusButton",}

activityCenterContactRequestMoreButton = {"container": activityCenterListLoader, "objectName": "moreBtn", "type": "StatusFlatRoundButton", "visible": True}
activityCenterContactRequestHeader = {"container": activityCenterNotificationCard, "type": "NotificationHeaderRow", "unnamed": 1, "visible": True}
activityCenterScrollView = {"container": statusDesktop_mainWindow, "type": "StatusScrollView", "unnamed": 1, "visible": True}
activityCenterGroupButton = {"container": activityCenterScrollView, "objectName": "activityCenterGroupButton", "type": "StatusFlatButton", "visible": True}
activityCenterNavigationButton = {"container": activityCenterPanel, "type": "StatusNavigationButton", "visible": True}