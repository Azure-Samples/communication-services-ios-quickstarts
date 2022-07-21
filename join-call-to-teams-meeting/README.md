---
page_type: sample
languages:
- swift
products:
- azure
- azure-communication-services
---

# Quickstart: Join your calling app to a Teams meeting

For full instructions on how to build this code sample from scratch, look at [Quickstart: Join your calling app to a Teams meeting](https://docs.microsoft.com/azure/communication-services/quickstarts/voice-video-calling/get-started-teams-interop?pivots=platform-ios)

## Prerequisites

To complete this tutorial, you’ll need the following prerequisites:

- A working [Communication Services calling iOS app](https://docs.microsoft.com/azure/communication-services/quickstarts/voice-video-calling/getting-started-with-calling). 
- A [Teams deployment](https://docs.microsoft.com/deployoffice/teams-install).



## Before running sample code

**Get the Teams meeting link**

The Teams meeting link can be retrieved using Graph APIs. This is detailed in [Graph documentation](https://docs.microsoft.com/graph/api/onlinemeeting-createorget?tabs=http&view=graph-rest-beta&preserve-view=true). The Communication Services Calling SDK accepts a full Teams meeting link. This link is returned as part of the **onlineMeeting** resource, accessible under the [joinWebUrl property](https://docs.microsoft.com/graph/api/resources/onlinemeeting?view=graph-rest-beta&preserve-view=true). You can also get the required meeting information from the **Join Meeting** URL in the Teams meeting invite itself.
  
## Run the sample

**Launch the app and join Teams meeting**

- You can build and run your app on iOS simulator by selecting Product > Run or by using the (⌘-R) keyboard shortcut.
