# Quickstart: Add 1 on 1 video calling to your app
In this quickstart we are going to get started with Azure Communication Services by using the Communication Services calling client library to add 1 on 1 video calling to your app. You'll learn how to start and answer a video call using the Azure Communication Services Calling client library for iOS.

## Prerequisites
- Obtain an Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/en-us/free/?WT.mc_id=A261C142F).
- A Mac running [Xcode](https://developer.apple.com/xcode/), along with a valid developer certificate installed into your Keychain.
- Create an active Communication Services resource. [Create a Communication Services resource](https://docs.microsoft.com/en-gb/azure/communication-services/quickstarts/create-communication-resource?tabs=windows&pivots=platform-azp).
- Create a User Access Token to instantiate the call client. [Learn how to create and manage user access tokens](https://docs.microsoft.com/en-gb/azure/communication-services/quickstarts/access-tokens?pivots=programming-language-csharp).

## Setting up
### Swift package Manager 
Please use this guide to [install CocoaPods](https://guides.cocoapods.org/using/getting-started.html) on your Mac. 

### Install the package using Xcode

Open your project in Xcode (Xcode 11 or later)
1. Add the package dependency:

Select File > Add Packages... (or File > Swift Packages > Add Package Dependency... in older Xcode versions)

2. Enter the repository URL:

   https://github.com/Azure/SwiftPM-AzureCommunicationCalling.git

3. Set the version rule:
For the Dependency Rule, choose your preferred option:
Exact Version: 2.17.0-beta.3 (for the specific beta version)
Click Add Package

4. Select the target. 

### Install the package using Swift Package Manager 
If you're building a Swift Package, add this to your Package.swift file: 
```
dependencies: [
        .package(
            name: "AzureCommunicationCalling",
            url: "https://github.com/Azure/SwiftPM-AzureCommunicationCalling.git",
            from: "1.0.0"
        )
    ]
```

## Run the code
Before running the sample, you need to replace the "<USER ACCESS TOKEN>" with the User Access Token you created in prerequisites.
You can build an run your app on iOS simulator by selecting Product > Run or by using the (⌘-R) keyboard shortcut. 
