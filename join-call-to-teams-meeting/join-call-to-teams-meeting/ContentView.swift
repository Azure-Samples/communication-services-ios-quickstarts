import SwiftUI
import AzureCommunicationCalling
import AVFoundation

struct ContentView: View {
    @State var meetingLink: String = ""
    @State var callStatus: String = ""
    @State var message: String = ""
    @State var recordingStatus: String = ""
    @State var callClient: CallClient?
    @State var callAgent: CallAgent?
    @State var call: Call?
    @State var callObserver: CallObserver?

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Teams meeting link", text: $meetingLink)
                    Button(action: joinTeamsMeeting) {
                        Text("Join Teams Meeting")
                    }.disabled(callAgent == nil)
                    Button(action: leaveMeeting) {
                        Text("Leave Meeting")
                    }.disabled(call == nil)
                    Text(callStatus)
                    Text(message)
                    Text(recordingStatus)
                }
            }
            .navigationBarTitle("Calling Quickstart")
        }.onAppear {
            // Initialize call agent
            var userCredential: CommunicationTokenCredential?
            do {
                userCredential = try CommunicationTokenCredential(token: "eyJhbGciOiJSUzI1NiIsImtpZCI6IjEwMiIsIng1dCI6IjNNSnZRYzhrWVNLd1hqbEIySmx6NTRQVzNBYyIsInR5cCI6IkpXVCJ9.eyJza3lwZWlkIjoiYWNzOjM3M2NkYjgwLTFhMGEtNDRlMC05M2I1LTc3ZjM1YjBkZjMxNV8wMDAwMDAwYS1iZTBiLTQ3MmMtZTNjNy01OTNhMGQwMDNkNWQiLCJzY3AiOjE3OTIsImNzaSI6IjE2MjQwMDM2ODMiLCJpYXQiOjE2MjQwMDM2ODMsImV4cCI6MTYyNDA5MDA4MywiYWNzU2NvcGUiOiJ2b2lwIiwicmVzb3VyY2VJZCI6IjM3M2NkYjgwLTFhMGEtNDRlMC05M2I1LTc3ZjM1YjBkZjMxNSJ9.dgkbYwD7nWRNiR5y93soxrMePZj49gqA1TFYfCF0hGRG5utvnkZq06ZTGGaqT91FpI2GF-_McdJLPyinOE15WnGRfl6HOIDldqWOkeBQ5UzD3xChuxHC74wzHySFZq2GBaAhXzisgyfYuKzaejA6A4nQ2KrK4mGdkjWrgGgKnjGUpIrI9p1tjeHjr3EtaY2NfeBm89fZ8HV0fnrJ0AVdXcoWBnmZI3QZrnELGuEHmY0tqI2vStR8SGyFpYbjHht4_hpcROEIXkttSMzed8t-CILlTayprp0VuOGPzegXT66B-LJjiW8AQTNXf_JaRO7_eXMUWhuaVaNTyl8d2LQpHw")
            } catch {
                print("ERROR: It was not possible to create user credential.")
                self.message = "Please enter your token in source code"
                return
            }

            self.callClient = CallClient()

            // Creates the call agent
            self.callClient?.createCallAgent(userCredential: userCredential!) { (agent, error) in
                if error != nil {
                    self.message = "Failed to create CallAgent."
                    return
                } else {
                    self.callAgent = agent
                    self.message = "Call agent successfully created."
                }
            }
        }
    }

    func joinTeamsMeeting() {
        // Ask permissions
        AVAudioSession.sharedInstance().requestRecordPermission { (granted) in
            if granted {
                let joinCallOptions = JoinCallOptions()
                let teamsMeetingLinkLocator = TeamsMeetingLinkLocator(meetingLink: self.meetingLink)
                self.callAgent?.join(with: teamsMeetingLinkLocator, joinCallOptions: joinCallOptions) {(call, error) in
                    if (error == nil) {
                        self.call = call
                        self.callObserver = CallObserver(self)
                        self.call!.delegate = self.callObserver
                        self.message = "Teams meeting joined successfully"
                    } else {
                        print("Failed to get call object")
                        return
                    }
                }
            }
        }
    }


    func leaveMeeting() {
        if let call = call {
            call.hangUp(options: nil, completionHandler: { (error) in
                if error == nil {
                    self.message = "Leaving Teams meeting was successful"
                } else {
                    self.message = "Leaving Teams meeting failed"
                }
            })
        } else {
            self.message = "No active call to hangup"
        }
    }
}

class CallObserver : NSObject, CallDelegate {
    private var owner:ContentView
    init(_ view:ContentView) {
        owner = view
    }

    public func call(_ call: Call, didChangeState args: PropertyChangedEventArgs) {
        owner.callStatus = CallObserver.callStateToString(state: call.state)
        if call.state == .disconnected {
            owner.call = nil
            owner.message = "Left Meeting"
        } else if call.state == .inLobby {
            owner.message = "Waiting in lobby !!"
        } else if call.state == .connected {
            owner.message = "Joined Meeting !!"
        }
    }
    
    public func call(_ call: Call, didChangeRecordingState args: PropertyChangedEventArgs) {
        if (call.isRecordingActive == true) {
            owner.recordingStatus = "This call is being recorded"
        }
        else {
            owner.recordingStatus = ""
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

