//
//  ContentView.swift
//  Chat Teams Interop
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//
import AVFoundation
import SwiftUI

import AzureCommunicationCalling
import AzureCommunicationChat


let endpoint = "<ADD_YOUR_ENDPOINT_URL_HERE>"
let token = "<ADD_YOUR_USER_TOKEN_HERE>"

struct ContentView: View {
  @State var message: String = ""
  @State var meetingLink: String = ""
  @State var chatThreadId: String = ""

  // Calling state
  @State var callClient: CallClient?
  @State var callObserver: CallDelegate?
  @State var callAgent: CallAgent?
  @State var call: Call?

  // Chat state
  @State var chatClient: ChatClient?
  @State var chatThreadClient: ChatThreadClient?
  @State var chatMessage: String = ""
  @State var meetingMessages: [MeetingMessage] = []

  let displayName: String = "Quickstart User"

  var body: some View {
    NavigationView {
      Form {
        Section {
          TextField("Teams Meeting URL", text: $meetingLink)
            .onChange(of: self.meetingLink, perform: { value in
              if let threadIdFromMeetingLink = getThreadId(from: value) {
                self.chatThreadId = threadIdFromMeetingLink
              }
            })
          TextField("Chat thread ID", text: $chatThreadId)
        }
        Section {
          HStack {
            Button(action: joinMeeting) {
              Text("Join Meeting")
            }.disabled(
              chatThreadId.isEmpty || callAgent == nil || call != nil
            )
            Spacer()
            Button(action: leaveMeeting) {
              Text("Leave Meeting")
            }.disabled(call == nil)
          }
          Text(message)
        }
        Section {
          ForEach(meetingMessages, id: \.id) { message in
            let currentUser: Bool = (message.displayName == self.displayName)
            let foregroundColor = currentUser ? Color.white : Color.black
            let background = currentUser ? Color.blue : Color(.systemGray6)
            let alignment = currentUser ? HorizontalAlignment.trailing : .leading
            
            HStack {
              if currentUser {
                Spacer()
              }
              VStack(alignment: alignment) {
                Text(message.displayName).font(Font.system(size: 10))
                Text(message.content)
                  .frame(maxWidth: 200)
              }

              .padding(8)
              .foregroundColor(foregroundColor)
              .background(background)
              .cornerRadius(8)

              if !currentUser {
                Spacer()
              }
            }
          }
          .frame(maxWidth: .infinity)
        }

        TextField("Enter your message...", text: $chatMessage)
        Button(action: sendMessage) {
          Text("Send Message")
        }.disabled(chatThreadClient == nil)
      }

      .navigationBarTitle("Teams Chat Interop")
    }

    .onAppear {
      if let threadIdFromMeetingLink = getThreadId(from: self.meetingLink) {
        self.chatThreadId = threadIdFromMeetingLink
      }
      // Authenticate
      do {
        let credentials = try CommunicationTokenCredential(token: token)
        self.callClient = CallClient()
        self.callClient?.createCallAgent(
          userCredential: credentials
        ) { agent, error in
          if let e = error {
            self.message = "ERROR: It was not possible to create a call agent."
            print(e)
            return
          } else {
            self.callAgent = agent
          }
        }

        // Start the chat client
        self.chatClient = try ChatClient(
          endpoint: endpoint,
          credential: credentials,
          withOptions: AzureCommunicationChatClientOptions()
        )
        // Register for real-time notifications
        self.chatClient?.startRealTimeNotifications { result in
          switch result {
          case .success:
            self.chatClient?.register(
              event: .chatMessageReceived,
              handler: receiveMessage
            )
          case let .failure(error):
            self.message = "Could not register for message notifications: " + error.localizedDescription
            print(error)
          }
        }

      } catch {
        print(error)
        self.message = error.localizedDescription
      }
    }
  }

  // This will extract a meeting ID from one version of a teams meeting link
  // The thread ID may not be in the URL and instead Graph API can be used
  // to retrieve the thread ID for the meeting.
  func getThreadId(from teamsMeetingLink: String) -> String? {
    if let range = teamsMeetingLink.range(of: "meetup-join/") {
      let thread = teamsMeetingLink[range.upperBound...]
      if let endRange = thread.range(of: "/")?.lowerBound {
        return String(thread.prefix(upTo: endRange))
      }
    }
    return nil
  }

  func joinMeeting() {
    // Ask permissions
    AVAudioSession.sharedInstance().requestRecordPermission { (granted) in
      if granted {
        let teamsMeetingLink = TeamsMeetingLinkLocator(
          meetingLink: self.meetingLink
        )
        self.callAgent?.join(
          with: teamsMeetingLink,
          joinCallOptions: JoinCallOptions()
        ) {(call, error) in
          if let e = error {
            self.message = "Failed to join call: " + e.localizedDescription
            print(e.localizedDescription)
            return
          }

          self.call = call
          self.callObserver = CallObserver(self)
          self.call?.delegate = self.callObserver
          self.message = "Teams meeting joined successfully"
        }
      } else {
        self.message = "Not authorized to use mic"
      }
    }
  }

  // For teams interoperability, the chat system is only available when the
  // user is admitted into the meeting.
  func connectChat() {
    do {
      self.chatThreadClient = try chatClient?.createClient(
        forThread: self.chatThreadId
      )
      self.message = "Joined meeting chat successfully"
    } catch {
      self.message = "Failed to join the chat thread: " + error.localizedDescription
    }
  }

  func leaveMeeting() {
    if let call = self.call {
      self.chatClient?.unregister(event: .chatMessageReceived)
      self.chatClient?.stopRealTimeNotifications()

      call.hangUp(options: nil) { (error) in
        if let e = error {
          self.message = "Leaving Teams meeting failed: " + e.localizedDescription
        } else {
          self.message = "Leaving Teams meeting was successful"
        }
      }
      self.meetingMessages.removeAll()
    } else {
      self.message = "No active call to hangup"
    }
  }

  func sendMessage() {
    let message = SendChatMessageRequest(
      content: self.chatMessage,
      senderDisplayName: self.displayName,
      type: .text
    )

    self.chatThreadClient?.send(message: message) { result, _ in
      switch result {
      case .success:
        print("Chat message sent")
        self.chatMessage = ""

      case let .failure(error):
        self.message = "Failed to send message: " + error.localizedDescription + "\n Has your token expired?"
      }
    }
  }

  func receiveMessage(event: TrouterEvent) -> Void {
    switch event {
    case let .chatMessageReceivedEvent(messageEvent):
      let message = MeetingMessage.fromTrouter(event: messageEvent)
      self.meetingMessages.append(message)

      /// OTHER EVENTS
      //    case .realTimeNotificationConnected:
      //    case .realTimeNotificationDisconnected:
      //    case .typingIndicatorReceived(_):
      //    case .readReceiptReceived(_):
      //    case .chatMessageEdited(_):
      //    case .chatMessageDeleted(_):
      //    case .chatThreadCreated(_):
      //    case .chatThreadPropertiesUpdated(_):
      //    case .chatThreadDeleted(_):
      //    case .participantsAdded(_):
      //    case .participantsRemoved(_):

    default:
      break
    }
  }
}

#Preview {
  ContentView(
    meetingMessages: [
      MeetingMessage(
        id: UUID().uuidString,
        date: Date(),
        content: "Hi there!",
        displayName: "Alice"
      ),
      MeetingMessage(
        id: UUID().uuidString,
        date: Date(),
        content: "Welcome!",
        displayName: "Quickstart User"
      )
    ]
  )
}

class CallObserver : NSObject, CallDelegate {
  private var owner: ContentView

  init(_ view: ContentView) {
    owner = view
  }

  func call(
    _ call: Call,
    didChangeState args: PropertyChangedEventArgs
  ) {
    owner.message = CallObserver.callStateToString(state: call.state)
    if call.state == .disconnected {
      owner.call = nil
      owner.message = "Left Meeting"
    } else if call.state == .inLobby {
      owner.message = "Waiting in lobby (go let them in!)"
    } else if call.state == .connected {
      owner.message = "Connected"
      owner.connectChat()
    }
  }

  private static func callStateToString(state: CallState) -> String {
    switch state {
    case .connected: return "Connected"
    case .connecting: return "Connecting"
    case .disconnected: return "Disconnected"
    case .disconnecting: return "Disconnecting"
    case .earlyMedia: return "EarlyMedia"
    case .none: return "None"
    case .ringing: return "Ringing"
    case .inLobby: return "InLobby"
    default: return "Unknown"
    }
  }
}

struct MeetingMessage: Identifiable {
  let id: String
  let date: Date
  let content: String
  let displayName: String

  static func fromTrouter(event: ChatMessageReceivedEvent) -> MeetingMessage {
    let displayName: String = event.senderDisplayName ?? "Unknown User"
    let content: String = event.message.replacingOccurrences(
      of: "<[^>]+>", with: "",
      options: String.CompareOptions.regularExpression
    )
    return MeetingMessage(
      id: event.id,
      date: event.createdOn?.value ?? Date(),
      content: content,
      displayName: displayName
    )
  }
}
