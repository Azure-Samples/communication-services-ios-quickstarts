//
//  ViewController.swift
//  ChatQuickstart
//
//  Created by Akansha Gaur on 30/04/21.
//

import UIKit
import AzureCommunication
import AzureCommunicationChat

class ViewController: UIViewController {

    override func viewDidLoad() {
            super.viewDidLoad()
            // Do any additional setup after loading the view.

            let semaphore = DispatchSemaphore(value: 0)
            DispatchQueue.global(qos: .background).async {
                do {
                    // <CREATE A CHAT CLIENT>
                    let endpoint = "<ACS_RESOURCE_ENDPOINT>"
                    let credential =
                    try CommunicationTokenCredential(
                        token: "<ACCESS_TOKEN>"
                    )
                    let options = AzureCommunicationChatClientOptions()

                    let chatClient = try ChatClient(
                        endpoint: endpoint,
                        credential: credential,
                        withOptions: options
                    )
                    
                    // <CREATE A CHAT THREAD>
                    let request = CreateChatThreadRequest(
                        topic: "Quickstart",
                        participants: [
                            ChatParticipant(
                                id: CommunicationUserIdentifier("<USER_ID>"),
                                displayName: "Jack"
                            )
                        ]
                    )

                    var threadId: String?
                    chatClient.create(thread: request) { result, _ in
                        switch result {
                        case let .success(result):
                            threadId = result.chatThread?.id

                        case .failure:
                            fatalError("Failed to create thread.")
                        }
                        semaphore.signal()
                    }
                    semaphore.wait()

                    // <LIST ALL CHAT THREADS>
                    chatClient.listThreads { result, _ in
                        switch result {
                        case let .success(chatThreadItems):
                            var iterator = chatThreadItems.syncIterator
                                while let chatThreadItem = iterator.next() {
                                    print("Thread id: \(chatThreadItem.id)")
                                }
                        case .failure:
                            print("Failed to list threads")
                        }
                        semaphore.signal()
                    }
                    semaphore.wait()

                    // <GET A CHAT THREAD CLIENT>
                    let chatThreadClient = try chatClient.createClient(forThread: threadId!)

                    // <SEND A MESSAGE>
                    let message = SendChatMessageRequest(
                        content: "Hello!",
                        senderDisplayName: "Jack"
                    )

                    var messageId: String?

                    chatThreadClient.send(message: message) { result, _ in
                        switch result {
                        case let .success(result):
                            print("Message sent, message id: \(result.id)")
                            messageId = result.id
                        case .failure:
                            print("Failed to send message")
                        }
                        semaphore.signal()
                    }
                    semaphore.wait()

                    // <SEND A READ RECEIPT >
                    if let id = messageId {
                        chatThreadClient.sendReadReceipt(forMessage: id) { result, _ in
                            switch result {
                            case .success:
                                print("Read receipt sent")
                            case .failure:
                                print("Failed to send read receipt")
                            }
                            semaphore.signal()
                        }
                        semaphore.wait()
                    } else {
                        print("Cannot send read receipt without a message id")
                    }

                    // <RECEIVE MESSAGES>
                    chatThreadClient.listMessages { result, _ in
                        switch result {
                        case let .success(messages):
                            var iterator = messages.syncIterator
                            while let message = iterator.next() {
                                print("Received message of type \(message.type)")
                            }

                        case .failure:
                            print("Failed to receive messages")
                        }
                        semaphore.signal()
                    }
                    semaphore.wait()

                    // <ADD A USER>
                    let user = ChatParticipant(
                        id: CommunicationUserIdentifier("<USER_ID>"),
                        displayName: "Jane"
                    )

                    chatThreadClient.add(participants: [user]) { result, _ in
                        switch result {
                        case let .success(result):
                            if let errors = result.invalidParticipants, !errors.isEmpty {
                                print("Error adding participant")
                            } else {
                                print("Added participant")
                            }
                        case .failure:
                            print("Failed to add the participant")
                        }
                        semaphore.signal()
                    }
                    semaphore.wait()
                    
                    // <LIST USERS>
                    chatThreadClient.listParticipants { result, _ in
                        switch result {
                        case let .success(participants):
                            var iterator = participants.syncIterator
                            while let participant = iterator.next() {
                                let user = participant.id as! CommunicationUserIdentifier
                                print("User with id: \(user.identifier)")
                            }
                        case .failure:
                            print("Failed to list participants")
                        }
                        semaphore.signal()
                    }
                    semaphore.wait()
                } catch {
                    print("Quickstart failed: \(error.localizedDescription)")
                }
            }
        }

}

