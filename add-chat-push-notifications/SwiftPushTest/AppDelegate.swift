// --------------------------------------------------------------------------
//
// Copyright (c) Microsoft Corporation. All rights reserved.
//
// The MIT License (MIT)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the ""Software""), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED *AS IS*, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.
//
// --------------------------------------------------------------------------
import UIKit
import CryptoKit
import UserNotifications
import AzureCommunicationChat
import AzureCommunicationCommon

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    private (set) var appSettings: AppSettings!
    private var chatClient: ChatClient?

    var notificationPresentationCompletionHandler: ((UNNotificationPresentationOptions) -> Void)?
    var notificationResponseCompletionHandler: (() -> Void)?

    // MARK: App Launch
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        do{
            appSettings = AppSettings()
            let credential = try CommunicationTokenCredential(token: appSettings.token)
            let options = AzureCommunicationChatClientOptions()
            chatClient = try ChatClient(endpoint: appSettings.endpoint, credential: credential, withOptions: options)
            registerForPushNotifications()
            return true
        } catch {
            print("Failed to initialize chat client")
            return false
        }
    }


    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    // MARK: Register for Push Notifications after the launch of App
    func registerForPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            print("Permission granted: \(granted)")
            guard granted else { return }
            self?.getNotificationSettings()
            UNUserNotificationCenter.current().delegate = self

        }
    }

    func getNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("Notification settings: \(settings)")
            guard settings.authorizationStatus == .authorized else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    // MARK: Tells the delegate that the app successfully registered with Apple Push Notification service
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Get APNS device token
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("Device Token: \(token)")
        UserDefaults.standard.set(token, forKey: "APNSToken")
        guard let apnsToken = UserDefaults.standard.string(forKey: "APNSToken") else {
            print("Failed to get APNS token")
            return
        }
        
        // Please copy the below line if you want to implement an Advanced Version of PushNotification
        let appGroupId = "group.microsoft.contoso"
        // Please copy the below line if you want to implement an Advanced Version of PushNotification
        let keyTag = "PNKey"
        
        do{
            /*
               Please copy the below line of code if you want to implement an Advanced Version of PushNotification.
               As the SDK user, you are supposed to generate the push notification key handler on your end.
               In this sample app, we use the default AppGroupPushNotificationKeyHandler class provided by chat SDK to generate a key handler.
             */
            let appGroupPushNotificationKeyHandler: PushNotificationKeyHandler? = try AppGroupPushNotificationKeyHandler(appGroupId: appGroupId, keyTag: keyTag)
            
            let semaphore = DispatchSemaphore(value: 0)
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else { return }
                guard let chatClient = self.chatClient else { return }
                
                /* Please copy the below line of code if you want to implement an Advanced Version of PushNotification.
                   As the SDK user, you are supposed to set the key handler on your end.
                 */
                chatClient.pushNotificationKeyHandler = appGroupPushNotificationKeyHandler
                
                // Enable Push Notification by registering device token
                chatClient.startPushNotifications(deviceToken: apnsToken) { result in
                    switch result {
                    case .success:
                        print("Started Push Notifications")
                    case let .failure(error):
                        print("Failed To Start Push Notifications: \(error)")
                    }
                    semaphore.signal()
                }
                semaphore.wait()
            }
        }catch {
            print("Failed to init PushNotificationKeyHandler")
            return
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register: \(error)")
    }
}




