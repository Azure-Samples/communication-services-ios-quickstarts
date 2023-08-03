//
//  ContentView.swift
//  roomsquickstart
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT license.

import SwiftUI
import AVFoundation
import AzureCommunicationCalling

struct HomePageView: View {
    private let token = "USER_ACCESS_TOKEN"
    
    @State private var roomId: String = ""
    @State private var callObserver:CallObserver?
    @State private var previewRenderer: VideoStreamRenderer? = nil
    @State private var previewView: RendererView? = nil
    @State private var sendingLocalVideo: Bool = false
    @State private var speakerEnabled: Bool = false
    @State private var muted: Bool = false
    @State private var call: Call?
    @State private var callHandler: CallHandler?
    @State private var callAgent: CallAgent?
    @State private var deviceManager: DeviceManager?
    @State private var localVideoStreams: [LocalVideoStream]?

    @State var callState: String = "Unknown"
    @State var showAlert: Bool = false
    @State var alertMessage: String = ""
    @State var participants: [[Participant]] = [[]]
    
    var body: some View {
        NavigationView {
            ZStack {
                if (call == nil) {
                    Form {
                        Section {
                            TextField("Room ID", text: $roomId)
                            Button(action: joinRoomCall) {
                                Text("Join Room Call")
                            }
                        }
                    }
                    .navigationBarTitle("Rooms Quickstart")
                } else {
                    ZStack {
                        VStack {
                            ForEach(participants, id:\.self) { array in
                                HStack {
                                    ForEach(array, id:\.self) { participant in
                                        ParticipantView(self, participant)
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: 200, alignment: .topLeading)
                            }
                        }
                        .background(Color.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        VStack {
                            if (sendingLocalVideo) {
                                HStack {
                                    RenderInboundVideoView(view: $previewView)
                                        .frame(width:90, height:160)
                                        .padding(10)
                                        .background(Color.green)
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            HStack {
                                Button(action: toggleMute) {
                                    HStack {
                                        Text(muted ? "Unmute" : "Mute")
                                    }
                                    .frame(width:80)
                                    .padding(.vertical, 10)
                                    .background(Color(.lightGray))
                                }
                                Button(action: toggleLocalVideo) {
                                    HStack {
                                        Text(sendingLocalVideo ? "Video-Off" : "Video-On")
                                    }
                                    .frame(width:80)
                                    .padding(.vertical, 10)
                                    .background(Color(.lightGray))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            HStack {
                                Button(action:toggleSpeaker) {
                                    HStack {
                                        Text(speakerEnabled ? "Speaker-Off" : "Speaker-On")
                                    }
                                    .frame(width:100)
                                    .padding(.vertical, 10)
                                    .background(Color(.lightGray))
                                }
                                Button(action: leaveRoomCall) {
                                    HStack {
                                        Text("Leave Room Call")
                                    }
                                    .frame(width:80)
                                    .padding(.vertical, 10)
                                    .background(Color(.red))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            HStack {
                                Text("Status:")
                                Text(callState)
                            }
                            .padding(.vertical, 10)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    }
                }
            }
        }
        .onAppear(perform: initialize)
        .onDisappear(perform: leaveRoomCall)
        .alert(isPresented: $showAlert) { () -> Alert in
            Alert(title: Text("ERROR"), message: Text(alertMessage), dismissButton: .default(Text("Dismiss")))
        }
    }
    
    private func initialize() {
        // Ask for permissions
        AVAudioSession.sharedInstance().requestRecordPermission { (granted) in
            if granted {
                AVCaptureDevice.requestAccess(for: .video) { (videoGranted) in /* NOOP */ }
            }
        }
        
        self.callHandler = CallHandler.getOrCreateInstance()
        
        if !self.callHandler!.initialized {
            self.callHandler!.initialize(token: self.token, owner: self)
        }
    }
    
    private func toggleLocalVideo() {
        if (self.sendingLocalVideo) {
            self.call!.stopVideo(stream: self.localVideoStreams!.first!) { (error) in
                if (error != nil) {
                    self.alertMessage = "Could not stop preview renderer"
                    self.showAlert = true
                } else {
                    self.sendingLocalVideo = false
                    self.previewView = nil
                    self.previewRenderer!.dispose()
                    self.previewRenderer = nil
                }
            }
        } else {
            let availableCameras = self.deviceManager!.cameras
            let scalingMode:ScalingMode = .crop
            if (self.localVideoStreams == nil) {
                self.localVideoStreams = [LocalVideoStream]()
            }
            self.localVideoStreams!.append(LocalVideoStream(camera: availableCameras.first!))
            self.previewRenderer = try! VideoStreamRenderer(localVideoStream: self.localVideoStreams!.first!)
            self.previewView = try! previewRenderer!.createView(withOptions: CreateViewOptions(scalingMode:scalingMode))
            self.call!.startVideo(stream: self.localVideoStreams!.first!) { (error) in
                if (error != nil) {
                    self.alertMessage = "Could not share video"
                    self.showAlert = true
                }
                else {
                    self.sendingLocalVideo = true
                }
            }
        }
    }
    
    private func toggleMute() {
        if (self.muted) {
            call!.unmuteOutgoingAudio(completionHandler: { (error) in
                if error == nil {
                    self.muted = false
                }
            })
        } else {
            call!.muteOutgoingAudio(completionHandler: { (error) in
                if error == nil {
                    self.muted = true
                }
            })
        }
    }
    
    private func toggleSpeaker() {
        let audioSession = AVAudioSession.sharedInstance()
        if self.speakerEnabled {
            try! audioSession.overrideOutputAudioPort(AVAudioSession.PortOverride.none)
        } else {
            try! audioSession.overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
        }
        
        self.speakerEnabled = !self.speakerEnabled
    }
    
    public func joinRoomCall() {
        if self.callAgent == nil {
            self.showAlert = true
            self.alertMessage = "CallAgent not initialized"
            return
        }
        
        if (self.roomId.isEmpty) {
            self.showAlert = true
            self.alertMessage = "Room ID not set"
            return
        }
        
        // Join a call with a Room ID
        let options = JoinCallOptions()
        
        let audioOptionsOutgoing = OutgoingAudioOptions()
        audioOptionsOutgoing.muted = self.muted
        
        options.outgoingAudioOptions = audioOptionsOutgoing
        
        let roomCallLocator = RoomCallLocator(roomId: roomId)
        self.callAgent!.join(with: roomCallLocator, joinCallOptions: options) { (call, error) in
            self.setCallAndObserver(call: call, error: error)
        }
    }
    
    public func leaveRoomCall() {
        if (self.sendingLocalVideo) {
            self.call!.stopVideo(stream: self.localVideoStreams!.first!) { (error) in
                if (error != nil) {
                    self.alertMessage = "Could not stop preview renderer"
                    self.showAlert = true
                } else {
                    self.sendingLocalVideo = false
                    self.previewView = nil
                    self.previewRenderer?.dispose()
                    self.previewRenderer = nil
                }
            }
        }
        self.call?.hangUp(options: nil) { (error) in }
        self.participants.removeAll()
        self.call?.delegate = nil
        self.call = nil
    }
    
    public func callRemoved(_ call: Call) {
        self.call = nil
    }
    
    public func setCallAndObserver(call:Call!, error:Error?) {
        if (error == nil) {
            self.call = call
            self.callObserver = CallObserver(view:self)

            self.call!.delegate = self.callObserver

            if (self.call!.state == CallState.connected) {
                self.callObserver!.handleInitialCallState(call: call)
            }
        } else {
            self.alertMessage = "Failed to set CallObserver"
            self.showAlert = true
        }
    }
    
    public func setCallAgent(callAgent: CallAgent, callHandler: CallHandler)
    {
        self.callAgent = callAgent
        self.callAgent?.delegate = callHandler
    }
    
    public func setDeviceManager(deviceManager: DeviceManager)
    {
        self.deviceManager = deviceManager
    }
}

struct HomePageView_Previews: PreviewProvider {
    static var previews: some View {
        HomePageView()
    }
}

public class CallObserver : NSObject, CallDelegate
{
    private var owner: HomePageView
    private var firstTimeCallConnected: Bool = true
    
    init(view:HomePageView) {
        owner = view
        super.init()
    }

    public func call(_ call: Call, didChangeState args: PropertyChangedEventArgs) {
        let state = CallObserver.callStateToString(state:call.state)
        owner.callState = state
        if (call.state == CallState.disconnected) {
            owner.leaveRoomCall()
        }
        else if (call.state == CallState.connected) {
            if(self.firstTimeCallConnected) {
                self.handleInitialCallState(call: call);
            }
            self.firstTimeCallConnected = false;
        }
    }

    public func handleInitialCallState(call: Call) {
        // We want to build a matrix with max 2 columns

        owner.callState = CallObserver.callStateToString(state:call.state)
        var participants = [Participant]()

        // Add older/existing participants
        owner.participants.forEach { (existingParticipants: [Participant]) in
            participants.append(contentsOf: existingParticipants)
        }
        owner.participants.removeAll()

        // Add new participants to the collection
        for remoteParticipant in call.remoteParticipants {
            let mri = Utilities.toMri(remoteParticipant.identifier)
            let found = participants.contains { (participant) -> Bool in
                participant.getMri() == mri
            }

            if !found {
                let participant = Participant(call, remoteParticipant)
                participants.append(participant)
            }
        }

        // Convert 1-D array into a 2-D array with 2 columns
        var indexOfParticipant = 0
        while indexOfParticipant < participants.count {
            var newParticipants = [Participant]()
            newParticipants.append(participants[indexOfParticipant])
            indexOfParticipant += 1
            if (indexOfParticipant < participants.count) {
                newParticipants.append(participants[indexOfParticipant])
                indexOfParticipant += 1
            }
            owner.participants.append(newParticipants)
        }
    }

    public func call(_ call: Call, didUpdateRemoteParticipant args: ParticipantsUpdatedEventArgs) {
        var participants = [Participant]()
        // Add older/existing participants
        owner.participants.forEach { (existingParticipants: [Participant]) in
            participants.append(contentsOf: existingParticipants)
        }
        owner.participants.removeAll()

        // Remove deleted participants from the collection
        args.removedParticipants.forEach { p in
            let mri = Utilities.toMri(p.identifier)
            participants.removeAll { (participant) -> Bool in
                participant.getMri() == mri
            }
        }

        // Add new participants to the collection
        for remoteParticipant in args.addedParticipants {
            let mri = Utilities.toMri(remoteParticipant.identifier)
            let found = participants.contains { (view) -> Bool in
                view.getMri() == mri
            }

            if !found {
                let participant = Participant(call, remoteParticipant)
                participants.append(participant)
            }
        }

        // Convert 1-D array into a 2-D array with 2 columns
        var indexOfParticipant = 0
        while indexOfParticipant < participants.count {
            var array = [Participant]()
            array.append(participants[indexOfParticipant])
            indexOfParticipant += 1
            if (indexOfParticipant < participants.count) {
                array.append(participants[indexOfParticipant])
                indexOfParticipant += 1
            }
            owner.participants.append(array)
        }
    }

    private static func callStateToString(state:CallState) -> String {
        switch state {
        case .connected: return "Connected"
        case .connecting: return "Connecting"
        case .disconnected: return "Disconnected"
        case .disconnecting: return "Disconnecting"
        case .none: return "None"
        default: return "Unknown"
        }
    }
}

class Participant: NSObject, RemoteParticipantDelegate, ObservableObject {
    private var videoStreamCount = 0
    private let innerParticipant:RemoteParticipant
    private let call:Call
    private var renderedRemoteVideoStream:RemoteVideoStream?
    
    @Published var state:ParticipantState = ParticipantState.disconnected
    @Published var isMuted:Bool = false
    @Published var isSpeaking:Bool = false
    @Published var hasVideo:Bool = false
    @Published var displayName:String = ""
    @Published var videoOn:Bool = true
    @Published var renderer:VideoStreamRenderer? = nil
    @Published var rendererView:RendererView? = nil
    @Published var scalingMode: ScalingMode = .fit

    init(_ call: Call, _ innerParticipant: RemoteParticipant) {
        self.call = call
        self.innerParticipant = innerParticipant
        self.displayName = innerParticipant.displayName

        super.init()

        self.innerParticipant.delegate = self

        self.state = innerParticipant.state
        self.isMuted = innerParticipant.isMuted
        self.isSpeaking = innerParticipant.isSpeaking
        self.hasVideo = innerParticipant.incomingVideoStreams.count > 0
        if(self.hasVideo) {
            handleInitialRemoteVideo()
        }
    }

    deinit {
        self.innerParticipant.delegate = nil
    }

    func getMri() -> String {
        Utilities.toMri(innerParticipant.identifier)
    }

    func set(scalingMode: ScalingMode) {
        if self.rendererView != nil {
            self.rendererView!.update(scalingMode: scalingMode)
        }
        self.scalingMode = scalingMode
    }
    
    func handleInitialRemoteVideo() {
        renderedRemoteVideoStream = innerParticipant.videoStreams[0]
        renderer = try! VideoStreamRenderer(remoteVideoStream: renderedRemoteVideoStream!)
        rendererView = try! renderer!.createView()
    }

    func toggleVideo() {
        if videoOn {
            rendererView = nil
            renderer?.dispose()
            videoOn = false
        }
        else {
            renderer = try! VideoStreamRenderer(remoteVideoStream: innerParticipant.videoStreams[0])
            rendererView = try! renderer!.createView()
            videoOn = true
        }
    }

    func remoteParticipant(_ remoteParticipant: RemoteParticipant, didUpdateVideoStreams args: RemoteVideoStreamsEventArgs) {
        let hadVideo = hasVideo
        hasVideo = innerParticipant.videoStreams.count > 0
        if videoOn {
            if hadVideo && !hasVideo {
                // Remote user stopped sharing
                rendererView = nil
                renderer?.dispose()
            } else if hasVideo && !hadVideo {
                // remote user started sharing
                renderedRemoteVideoStream = innerParticipant.videoStreams[0]
                renderer = try! VideoStreamRenderer(remoteVideoStream: renderedRemoteVideoStream!)
                rendererView = try! renderer!.createView()
            } else if hadVideo && hasVideo {
                if args.addedRemoteVideoStreams.count > 0 {
                    if renderedRemoteVideoStream?.id == args.addedRemoteVideoStreams[0].id {
                        return
                    }
    
                    // remote user added a second video, so switch to the latest one
                    guard let rendererTemp = renderer else {
                        return
                    }
                    rendererTemp.dispose()
                    renderedRemoteVideoStream = args.addedRemoteVideoStreams[0]
                    renderer = try! VideoStreamRenderer(remoteVideoStream: renderedRemoteVideoStream!)
                    rendererView = try! renderer!.createView()
                } else if args.removedRemoteVideoStreams.count > 0 {
                    if args.removedRemoteVideoStreams[0].id == renderedRemoteVideoStream!.id {
                        // remote user stopped sharing video that we were rendering but is sharing
                        // another video that we can render
                        renderer!.dispose()

                        renderedRemoteVideoStream = innerParticipant.videoStreams[0]
                        renderer = try! VideoStreamRenderer(remoteVideoStream: renderedRemoteVideoStream!)
                        rendererView = try! renderer!.createView()
                    }
                }
            }
        }
    }

    func remoteParticipant(_ remoteParticipant: RemoteParticipant, didChangeDisplayName args: PropertyChangedEventArgs) {
        self.displayName = innerParticipant.displayName
    }
}

class Utilities {
    @available(*, unavailable) private init() {}

    public static func toMri(_ id: CommunicationIdentifier?) -> String {

        if id is CommunicationUserIdentifier {
            let communicationUserIdentifier = id as! CommunicationUserIdentifier
            return communicationUserIdentifier.identifier
        } else {
            return "<nil>"
        }
    }
}
