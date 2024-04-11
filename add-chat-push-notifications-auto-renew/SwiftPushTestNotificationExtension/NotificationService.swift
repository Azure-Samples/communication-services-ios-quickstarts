//
//  NotificationService.swift
//  SwiftPushTestNotificationExtension
//

import UserNotifications
import AzureCommunicationChat
import AzureCommunicationCommon
import SwiftUI
import CryptoKit

//This is required when you implement an Advanced Version of Push Notification.
class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        if let bestAttemptContent = bestAttemptContent {
            // Set default title and body
            bestAttemptContent.title = "New Message"
            bestAttemptContent.body = "Please tap here to see the message."
            
            do{
                let data = bestAttemptContent.userInfo
                
                /*
                   As the SDK user, you are supposed to generate the push notification key storage on your end.
                   In this sample app, we use the default AppGroupPushNotificationKeyStorage class provided by chat SDK to generate a key storage.
                 */
                let appGroupId = "group.microsoft.contoso"
                let keyTag = "PNKey"
                guard let keyStorage = try AppGroupPushNotificationKeyStorage(appGroupId: appGroupId, keyTag: keyTag) else {
                    contentHandler(bestAttemptContent)
                    return
                }
                
                // Call decryptPayload(notification:) function provided by chat SDK to decrypt notification payload
                let pushNotificationEvent = try keyStorage.decryptPayload(notification: data)
                
                // You will get an enum which only contains one type - ".chatMessageReceivedEvent".
                // Get all the useful information from the enum and customize the content in alert banner
                switch pushNotificationEvent {
                    case let .chatMessageReceivedEvent(chatMessageReceivedEvent):
                    
                    // Customize the title
                    let senderDisplayName = chatMessageReceivedEvent.senderDisplayName
                    if senderDisplayName != nil {
                        bestAttemptContent.title = "\(senderDisplayName!) sends a message"
                    }
                    
                    // Customize the content
                    let messageBody = chatMessageReceivedEvent.message
                    bestAttemptContent.body = messageBody
                }
                
                // Call contentHandler after switch to ensure it's called in all cases
                contentHandler(bestAttemptContent)
            } catch {
                /*
                 If the decryption failed, the app will not be able to customize "Title" or "Message Body"
                 Default "Message Title" and "Message Body" will be displayed to the user:
                 "Message Title": "New Message"
                 "Message Body": "Please tap here to see the message."
                 */
                contentHandler(bestAttemptContent)
            }
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
