// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

import SwiftUI
import AzureCommunicationCalling
import AVFoundation

struct ContentView: View {
    @State var callee: String = ""
    @State var status: String = ""
    @State var callClient: CallClient?
    @State var callAgent: CallAgent?
    @State var call: Call?
    @State var callDelegates: CallDelegates?

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Who would you like to call?", text: $callee)
                    Button(action: startCall) {
                        Text("Start Call")
                    }.disabled(callAgent == nil)
                    Button(action: endCall) {
                        Text("End Call")
                    }.disabled(call == nil)
                    Text(status)
                }
            }
            .navigationBarTitle("Calling Quickstart")
        }.onAppear {
            // Initialize call agent
            var userCredential: CommunicationTokenCredential?
            do {
                userCredential = try CommunicationTokenCredential(token: "<USER_TOKEN_HERE>")
            } catch {
                print("ERROR: It was not possible to create user credential.")
                self.status = "Please enter your token in source code"
                return
            }

            self.callClient = CallClient()

            // Creates the call agent
            self.callClient?.createCallAgent(userCredential: userCredential) { (agent, error) in
                if error != nil {
                    print("ERROR: It was not possible to create a call agent.")
                }

                if let agent = agent {
                    self.callAgent = agent
                    print("Call agent successfully created.")
                }
            }
        }
    }

    func startCall() {
        // Ask permissions
        AVAudioSession.sharedInstance().requestRecordPermission { (granted) in
            if granted {
                let participants:[CommunicationUserIdentifier] = [CommunicationUserIdentifier(identifier: self.callee)]
                self.call = self.callAgent?.call(participants: participants, options: StartCallOptions())
                self.callDelegates = CallDelegates(self)
                self.call!.delegate = self.callDelegates
            }
        }
    }

    func endCall() {
        if let call = call {
            call.hangup(options: HangupOptions(), completionHandler: { (error) in
                if error != nil {
                    print("ERROR: It was not possible to hangup the call.")
                }
            })
        }
    }
}

class CallDelegates : NSObject, CallDelegate {
    private var owner:ContentView
    init(_ view:ContentView) {
        owner = view
    }
    public func onCallStateChanged(_ call: Call!,
                                   args: PropertyChangedEventArgs!) {
        owner.status = CallDelegates.callStateToString(call.state)
    }
    private static func callStateToString(_ state:CallState) -> String {
        switch state {
        case .connected: return "Connected"
        case .connecting: return "Connecting"
        case .disconnected: return "Disconnected"
        case .disconnecting: return "Disconnecting"
        case .earlyMedia: return "EarlyMedia"
        case .hold: return "Hold"
        case .incoming: return "Incoming"
        case .none: return "None"
        case .ringing: return "Ringing"
        default: return "Unknown"
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
