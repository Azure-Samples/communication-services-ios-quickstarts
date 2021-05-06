---
page_type: sample
languages:
- swift
products:
- azure
- azure-communication-services
---

# Quickstart: Add Chat to your App

For full instructions on how to build this code sample from scratch, look at [Quickstart: Add Chat to your App](https://docs.microsoft.com/azure/communication-services/quickstarts/chat/get-started?pivots=programming-language-swift)

## Prerequisites

To complete this tutorial, you’ll need the following prerequisites:

- An Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free/?WT.mc_id=A261C142F). 
- Install [Xcode](https://developer.apple.com/xcode/) and [CocoaPods](https://cocoapods.org/). You use Xcode to create an iOS application for the quickstart, and CocoaPods to install dependencies.
- A deployed Communication Services resource. [Create a Communication Services resource](https://docs.microsoft.com/azure/communication-services/quickstarts/create-communication-resource).
- Create two users in Azure Communication Services, and issue them a [user access token](https://docs.microsoft.com/azure/communication-services/quickstarts/access-tokens). Be sure to set the scope to chat, and note the token string as well as the userId string. In this quickstart, you create a thread with an initial participant, and then add a second participant to the thread.


## Before running sample code

1. Open an instance of PowerShell, Windows Terminal, Command Prompt or equivalent and navigate to the directory that you'd like to clone the sample to.
2. `git clone https://github.com/Azure-Samples/Communication-Services-ios-quickstarts.git`
3. With the `Access Token` procured in pre-requisites, add it to the **ChatQuickstart/ViewController.swift** file. Assign your access token in line 25:
   ```let credential =try CommunicationTokenCredential(token: "<ACCESS_TOKEN>")```
4. With the `End point` procured in pre-requisites, add it to the **ChatQuickstart/ViewController.swift** file. Assign end point in line 22:
   ```let endpoint = "<ACS_RESOURCE_ENDPOINT>"```
5. With the `Communication Services user ID` procured in pre-requisites, add it to the **ChatQuickstart/ViewController.swift** file. Assign first user ID in line 40.
  
6. With the `Communication Services user ID` procured in pre-requisites, add it to the **ChatQuickstart/ViewController.swift** file. Assign second user ID in line 131.

## Run the sample

- In Xcode hit the Run button to build and run the project. In the console you can view the output from the code and the logger output from the ChatClient.
