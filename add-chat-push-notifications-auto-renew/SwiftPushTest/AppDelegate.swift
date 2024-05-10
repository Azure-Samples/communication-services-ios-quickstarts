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
import BackgroundTasks

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    private (set) var appSettings = AppSettings()
    private var tokenRefresher: ((@escaping (String?, Error?) -> Void) -> Void)?
    private var userTokenClient: UserTokenClient!
    private var chatClient: ChatClient?
    var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    var notificationPresentationCompletionHandler: ((UNNotificationPresentationOptions) -> Void)?
    var notificationResponseCompletionHandler: (() -> Void)?
    

    // MARK: App Launch
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Setup user token client and chat client
        setupUserTokenClient()
        setupChatClient()
        
        // Register for services
        registerForPushNotifications()
        registerBackgroundTasks()
        
        return true
    }
    
    // MARK: - Setup Methods
    
    /// Sets up the UserTokenClient with token refresh logic.
    private func setupUserTokenClient() {
        userTokenClient = UserTokenClient(acsUserId: appSettings.acsUserId, tokenIssuerURL: appSettings.tokenIssuerURL!)

        tokenRefresher = { tokenCompletionHandler in
            self.userTokenClient.getTokenForAcsUserId { success, error in
                if success, let token = self.userTokenClient.getUserToken {
                    tokenCompletionHandler(token, nil)
                } else {
                    tokenCompletionHandler(nil, error)
                }
            }
        }
    }
        
    /// Initializes and configures the ChatClient with token credential.
    private func setupChatClient() {
        guard let tokenRefresher = self.tokenRefresher else {
            //Token refresher is not set up
            return
        }

        do {
            let refreshOptions = CommunicationTokenRefreshOptions(
                initialToken: appSettings.initialToken,
                refreshProactively: true,
                tokenRefresher: tokenRefresher
            )
            let credential = try CommunicationTokenCredential(withOptions: refreshOptions)
            let options = AzureCommunicationChatClientOptions()
            chatClient = try ChatClient(endpoint: appSettings.acsEndpoint, credential: credential, withOptions: options)
        } catch {
            //TODO: Add the code to do things when you failed to set up ChatClient
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
            guard granted else { return }
            self?.getNotificationSettings { _ in
            }
            UNUserNotificationCenter.current().delegate = self
        }
    }

    func getNotificationSettings(completion: @escaping (_ success: Bool) -> Void) {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                guard settings.authorizationStatus == .authorized else {
                    completion(false)
                    return
                }
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    completion(true)
                }
            }
        }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
            processDeviceToken(deviceToken) { success in
                if success {
                    // TODO: Add the code to do things when you successfully processed device token and started notifications
                } else {
                    // TODO: Add the code to do things when you failed to process device token or start notifications
                }
                self.endBackgroundTask()
            }
        }
    
    private func processDeviceToken(_ deviceToken: Data, completion: @escaping (_ success: Bool) -> Void) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        UserDefaults.standard.set(token, forKey: "APNSToken")
        
        guard let apnsToken = UserDefaults.standard.string(forKey: "APNSToken") else {
            completion(false)
            return
        }

        let appGroupId = "group.microsoft.contoso"
        let keyTag = "PNKey"

        guard let appGroupPushNotificationKeyStorage = try? AppGroupPushNotificationKeyStorage(appGroupId: appGroupId, keyTag: keyTag) else {
            completion(false)
            return
        }

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self, let chatClient = self.chatClient else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            chatClient.pushNotificationKeyStorage = appGroupPushNotificationKeyStorage

            chatClient.startPushNotifications(deviceToken: apnsToken) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        // TODO: Add the code to do things when you successfully started push notification
                        completion(true)
                    case .failure(let error):
                        // TODO: Add the code to do things when you Failed to start push notification
                        completion(false)
                    }
                }
            }
        }
    }
   
    // MARK: Schedule background task after the app enters the background
    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleAppRefresh()
    }

    func scheduleAppRefresh() {
        let request = BGProcessingTaskRequest(identifier: "com.contoso.app.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 1 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
    
    // MARK: Register Background Tasks
    private func registerBackgroundTasks() {
        // Registers a background task with the system. The identifier "com.contoso.app.refresh" is unique to this task.
        // It specifies the kind of background task this is, in this case, intended for app refreshes.
        // The `using` parameter allows specifying a queue for the task to run on, nil means it'll use a default queue.
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.contoso.app.refresh", using: nil) { task in
            // This closure is the entry point for the background task. It's called when iOS decides to launch the app in the background and execute this task.
            self.handleAppRefresh(task: task as! BGProcessingTask)
        }
    }
    
    func handleAppRefresh(task: BGProcessingTask) {
        // This is a clean-up block to ensure the task is marked as completed and any resources are released.
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
            self.endBackgroundTask()
        }

        extendBackgroundRunningTime()

        getNotificationSettings { success in
            guard success else {
                task.setTaskCompleted(success: false)
                self.endBackgroundTask()
                return
            }
        }
    }
    
    private func extendBackgroundRunningTime() {
        // Checks if a background task is already running. If so, there's no need to request more time.
        if backgroundTask != .invalid {
            return
        }
        
        // Requests additional time for the app to continue running in the background.
        // This is useful for operations that might take more time than the standard background execution time allows.
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "FetchData") {
            // This block is called when the background time is about to expire.
            // Use this as an opportunity to clean up and end the background task.
            self.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        // Ensures there's a background task to end.
        guard backgroundTask != .invalid else {
            return
        }
        
        // Ends the background task and resets its identifier, freeing up system resources and preventing the app from being terminated.
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        //TODO: Add the code to do things when you failed to register for Push Notification with APNS
    }
}





