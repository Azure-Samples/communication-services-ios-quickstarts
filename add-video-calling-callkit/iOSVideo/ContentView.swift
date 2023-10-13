//
//  ContentView.swift
//  iOSVideo
//
// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.
//
import SwiftUI
import AzureCommunicationCommon
import AzureCommunicationCalling
import AVFoundation
import Foundation
import PushKit
import os.log
import CallKit

enum CreateCallAgentErrors: Error {
    case noToken
    case callKitInSDKNotSupported
}

struct JwtPayload: Decodable {
    var skypeid: String
    var exp: UInt64
}

struct ContentView: View {
    init(appPubs: AppPubs) {
        self.appPubs = appPubs
    }

    private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "ACSVideoSample")
    private let token = "<USER_ACCESS_TOKEN>"
    private let cteToken = "eyJhbGciOiJSUzI1NiIsImtpZCI6IjVFODQ4MjE0Qzc3MDczQUU1QzJCREU1Q0NENTQ0ODlEREYyQzRDODQiLCJ4NXQiOiJYb1NDRk1kd2M2NWNLOTVjelZSSW5kOHNUSVEiLCJ0eXAiOiJKV1QifQ.eyJza3lwZWlkIjoib3JnaWQ6MjQ1MzI0OGUtYzEwZi00YTUxLTkyOTMtNmRmNGU5Mjk4YTA3Iiwic2NwIjoxMDI0LCJjc2kiOiIxNjg3OTg3NzkwIiwiZXhwIjoxNjg3OTkyMDQwLCJyZ24iOiJhbWVyIiwidGlkIjoiYmM2MWY0ZmMtMjZkNy00MTFlLTkxYTktNGMxNDY5MWRhYmRmIiwiYWNzU2NvcGUiOiJ2b2lwLGNoYXQiLCJyZXNvdXJjZUlkIjoiYjZhYWRhMWYtMGIxZC00N2FjLTg2NmYtOTFhYWUwMGExZDAxIiwiaWF0IjoxNjg3OTg4MDkxfQ.mG17TTJdWO7DTmoRgzJT3kTWvAO6egkSdW4uYvrU8U6E-rpcbx5ZUmeCzNjfU_wKzA7Plnkz6mOo6bDDCEkAl4eGscIc9TZH0cKsapxOQT2EAJjb1EXvpZhUIy4vxBw0NFGEaef0xGfLsb4SM8MEwXTJ6C3HajH3t8x1Vmsew-s9EDgwCdX0mul0k7Iyd0-25pUhVtzbY1Af9tRzEWjtJDSj7MgBZ-ewj5In2spIbDJ0awIB98V7404GGIOpWyK3k3roBbSvIGS18cRq6_EfBlwzUcHQ5URK7YhBpWu6AUeaL0PO4QXvuXW1xS9TAwhsuI4ZMR9eatJzpyhyvXPjSQ"
    
    @State var callee: String = "29228d3e-040e-4656-a70e-890ab4e173e4"
    @State var callClient = CallClient()

    @State var callAgent: CallAgent?
    @State var call: Call?
    @State var incomingCall: IncomingCall?

    @State var deviceManager: DeviceManager?
    @State var localVideoStream = [LocalVideoStream]()
    @State var sendingVideo:Bool = false
    @State var errorMessage:String = "Unknown"

    @State var remoteVideoStreamData:[RemoteVideoStreamData] = []
    @State var previewRenderer:VideoStreamRenderer? = nil
    @State var previewView:RendererView? = nil
    @State var remoteParticipant: RemoteParticipant?
    @State var remoteVideoSize:String = "Unknown"
    @State var isIncomingCall:Bool = false
    @State var showAlert = false
    @State var alertMessage = ""
    @State var userDefaults: UserDefaults = .standard
    @State var isCallKitInSDKEnabled = false
    @State var isSpeakerOn:Bool = false
    @State var isCte:Bool = false
    @State var isMuted:Bool = false
    @State var isHeld: Bool = false
    @State var mri: String = ""
    
    @State var callState: String = "None"
    @State var incomingCallHandler: IncomingCallHandler?
    @State var cxProvider: CXProvider?
    @State var callObserver:CallHandler?
    @State var remoteParticipantObserver:RemoteParticipantObserver?
    @State var pushToken: Data?
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    var appPubs: AppPubs

    var body: some View {
        HStack {
            Form {
                Section {
                    TextField("Who would you like to call?", text: $callee)
                    Button(action: startCall) {
                        Text("Start Call")
                    }.disabled(callAgent == nil)
                    Button(action: holdCall) {
                        Text(isHeld ? "Resume" : "Hold")
                    }.disabled(call == nil)
                    Button(action: switchMicrophone) {
                        Text(isMuted ? "UnMute" : "Mute")
                    }.disabled(call == nil)
                    Button(action: endCall) {
                        Text("End Call")
                    }.disabled(call == nil)
                    Button(action: toggleLocalVideo) {
                        HStack {
                            Text(sendingVideo ? "Turn Off Video" : "Turn On Video")
                        }
                    }
                    VStack {
                        Toggle("Enable CallKit in SDK", isOn: $isCallKitInSDKEnabled)
                            .onChange(of: isCallKitInSDKEnabled) { _ in
                                userDefaults.set(self.isCallKitInSDKEnabled, forKey: "isCallKitInSDKEnabled")
                                createCallAgent(completionHandler: nil)
                            }.disabled(call != nil)
                        Toggle("CTE", isOn: $isCte)
                            .onChange(of: isCte) { _ in
                                createCallAgent(completionHandler: nil)
                            }.disabled(call != nil)
                        Toggle("Speaker", isOn: $isSpeakerOn)
                            .onChange(of: isSpeakerOn) { _ in
                                switchSpeaker()
                            }.disabled(call == nil)
                        TextField("Call State", text: $callState)
                            .foregroundColor(.red)
                        TextField("MRI", text: $mri)
                            .foregroundColor(.blue)
                    }
                }
            }
            if (isIncomingCall) {
                HStack() {
                    VStack {
                        Text("Incoming call")
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    Button(action: answerIncomingCall) {
                        HStack {
                            Text("Answer")
                        }
                        .frame(width:80)
                        .padding(.vertical, 10)
                        .background(Color(.green))
                    }
                    Button(action: declineIncomingCall) {
                        HStack {
                            Text("Decline")
                        }
                        .frame(width:80)
                        .padding(.vertical, 10)
                        .background(Color(.red))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(10)
                .background(Color.gray)
            }
            ZStack {
                VStack {
                    ForEach(remoteVideoStreamData, id:\.self) { remoteVideoStreamData in
                        ZStack{
                            VStack{
                                RemoteVideoView(view: remoteVideoStreamData.rendererView!)
                                    .frame(width: .infinity, height: .infinity)
                                    .background(Color(.lightGray))
                            }
                        }
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                VStack {
                    if(sendingVideo)
                    {
                        VStack{
                            PreviewVideoStream(view: previewView!)
                                .frame(width: 135, height: 240)
                                .background(Color(.lightGray))
                        }
                    }
                }.frame(maxWidth:.infinity, maxHeight:.infinity,alignment: .bottomTrailing)
            }
     .navigationBarTitle("Video Calling Quickstart")
        }
        .onReceive(self.appPubs.$pushToken, perform: { newPushToken in
            guard let newPushToken = newPushToken else {
                print("Got empty token")
                return
            }

            if let existingToken = self.pushToken {
                if existingToken != newPushToken {
                    self.pushToken = newPushToken
                }
            } else {
                self.pushToken = newPushToken
            }
        })
    .onReceive(self.appPubs.$pushPayload, perform: { payload in
            handlePushNotification(payload)
        })
     .onAppear{
            isCallKitInSDKEnabled = userDefaults.value(forKey: "isCallKitInSDKEnabled") as? Bool ?? false
            isSpeakerOn = userDefaults.value(forKey: "isSpeakerOn") as? Bool ?? false
            AVAudioSession.sharedInstance().requestRecordPermission { (granted) in
                if granted {
                    AVCaptureDevice.requestAccess(for: .video) { (videoGranted) in
                        /* NO OPERATION */
                    }
                }
            }

             if deviceManager == nil {
                self.callClient.getDeviceManager { (deviceManager, error) in
                    if (error == nil) {
                        print("Got device manager instance")
                        // This app does not support landscape mode
                        // But iOS still generates the device orientation events
                        // This is a work-around so that iOS stops generating those events
                        // And stop sending it to the SDK.
                        UIDevice.current.endGeneratingDeviceOrientationNotifications()
                        self.deviceManager = deviceManager
                    } else {
                        self.showAlert = true
                        self.alertMessage = "Failed to get DeviceManager"
                    }
                }
             }
        }
        .alert(isPresented: $showAlert) { () -> Alert in
            Alert(title: Text("ERROR"), message: Text(alertMessage), dismissButton: .default(Text("Dismiss")))
        }
    }

    func switchMicrophone() {
        guard let call = self.call else {
            return
        }

        if isCallKitInSDKEnabled {
            if self.isMuted {
                call.unmuteOutgoingAudio() { error in
                    if error == nil {
                        isMuted = false
                    } else {
                        self.showAlert = true
                        self.alertMessage = "Failed to unmute audio"
                    }
                }
            } else {
                call.muteOutgoingAudio() { error in
                    if error == nil {
                        isMuted = true
                    } else {
                        self.showAlert = true
                        self.alertMessage = "Failed to mute audio"
                    }
                }
            }
        } else {
            Task {
                do {
                    try await CallKitObjectManager.getCallKitHelper()!.muteCall(callId:call.id, isMuted: !isMuted)
                    isMuted = !isMuted
                } catch {
                    self.showAlert = true
                    self.alertMessage = "Failed to mute the call (without CallKit)"
                }
            }
        }
        
        userDefaults.set(isMuted, forKey: "isMuted")
    }

    func switchSpeaker() -> Void {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            if isSpeakerOn {
                try audioSession.overrideOutputAudioPort(AVAudioSession.PortOverride.none)
            } else {
                try audioSession.overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
            }
            isSpeakerOn = !isSpeakerOn
            userDefaults.set(self.isSpeakerOn, forKey: "isSpeakerOn")
        } catch {
            self.showAlert = true
            self.alertMessage = "Failed to switch speaker: code: \(error.localizedDescription)"
        }
    }

    private func createCallAgentOptions() -> CallAgentOptions {
        let options = CallAgentOptions()
        options.callKitOptions = createCallKitOptions()
        return options
    }

    private func createCallKitOptions() -> CallKitOptions {
        let callKitOptions = CallKitOptions(with: CallKitObjectManager.createCXProvideConfiguration())
        callKitOptions.provideRemoteInfo = self.provideCallKitRemoteInfo
        return callKitOptions
    }
    
    func provideCallKitRemoteInfo(callerInfo: CallerInfo) -> CallKitRemoteInfo
    {
        let callKitRemoteInfo = CallKitRemoteInfo()
        callKitRemoteInfo.displayName = "CALL_TO_PHONENUMBER_BY_APP"
        callKitRemoteInfo.handle = CXHandle(type: .generic, value: "VALUE_TO_CXHANDLE")
        return callKitRemoteInfo
    }

    public func handlePushNotification(_ pushPayload: PKPushPayload?)
    {
        guard let pushPayload = pushPayload else {
            print("Got empty payload")
            return
        }

        if pushPayload.dictionaryPayload.isEmpty {
            os_log("ACS SDK got empty dictionary in push payload", log:self.log)
            return
        }

        let callNotification = PushNotificationInfo.fromDictionary(pushPayload.dictionaryPayload)

        let handlePush : (() -> Void) = {
            guard let callAgent = callAgent else {
                os_log("ACS SDK failed to create callAgent when handling push", log:self.log)
                self.showAlert = true
                self.alertMessage = "Failed to create CallAgent when handling push"
                return
            }

            // CallAgent is created normally handle the push
            callAgent.handlePush(notification: callNotification) { (error) in
                if error == nil {
                    os_log("SDK handle push notification normal mode: passed", log:self.log)
                } else {
                    os_log("SDK handle push notification normal mode: failed", log:self.log)
                }
            }
        }

        if self.callAgent == nil {
            createCallAgent { error in
                handlePush()
            }
        } else {
            handlePush()
        }
    }

    private func registerForPushNotification() {
        if let callAgent = self.callAgent,
           let pushToken = self.pushToken {
            callAgent.registerPushNotifications(deviceToken: pushToken) { error in
                if error != nil {
                    self.showAlert = true
                    self.alertMessage = "Failed to register for Push"
                }
            }
        }
    }

    private func getMri(recvdToken: String) -> String {
        let tokenParts = recvdToken.components(separatedBy: ".")
        var token =  tokenParts[1]
        token = token.replacingOccurrences(of: "-", with: "+")
                     .replacingOccurrences(of: "_", with: "-")
                     .appending(String(repeating: "=", count: (4 - (token.count % 4)) % 4))

        if let data = Data(base64Encoded: token) {
            do {
                let payload = try JSONDecoder().decode(JwtPayload.self, from: data)
                return "8:\(payload.skypeid)"
            } catch {
                return "Invalid Token"
            }
        } else {
            return "Failed to parse"
        }
    }

    private func createCallAgent(completionHandler: ((Error?) -> Void)?) {
        DispatchQueue.main.async {
            if isCte {
                var userCredential: CommunicationTokenCredential
                do {
                    userCredential = try CommunicationTokenCredential(token: cteToken)
                } catch {
                    self.showAlert = true
                    self.alertMessage = "Failed to create CommunicationTokenCredential for Teams"
                    completionHandler?(CreateCallAgentErrors.noToken)
                    return
                }
            } else {
                var userCredential: CommunicationTokenCredential
                do {
                    userCredential = try CommunicationTokenCredential(token: token)
                } catch {
                    self.showAlert = true
                    self.alertMessage = "Failed to create CommunicationTokenCredential"
                    completionHandler?(CreateCallAgentErrors.noToken)
                    return
                }
                
                mri = getMri(recvdToken: token)
                if callAgent != nil {
                    // Have to dispose existing CallAgent if present
                    // Because we cannot create two CallAgent's
                    callAgent!.dispose()
                    callAgent = nil
                }
                
                if userDefaults.value(forKey: "isCallKitInSDKEnabled") as? Bool ?? isCallKitInSDKEnabled {
                    self.callClient.createCallAgent(userCredential: userCredential,
                                                    options: createCallAgentOptions()) { (agent, error) in
                        if error == nil {
                            CallKitObjectManager.deInitCallKitInApp()
                            self.callAgent = agent
                            self.cxProvider = nil
                            print("Call agent successfully created.")
                            incomingCallHandler = IncomingCallHandler(contentView: self)
                            self.callAgent!.delegate = incomingCallHandler
                            registerForPushNotification()
                        } else {
                            self.showAlert = true
                            self.alertMessage = "Failed to create CallAgent (with CallKit) : \(error?.localizedDescription ?? "Empty Description")"
                        }
                        completionHandler?(error)
                    }
                } else {
                    self.callClient.createCallAgent(userCredential: userCredential) { (agent, error) in
                        if error == nil {
                            self.callAgent = agent
                            print("Call agent successfully created (without CallKit)")
                            incomingCallHandler = IncomingCallHandler(contentView: self)
                            self.callAgent!.delegate = incomingCallHandler
                            let _ = CallKitObjectManager.getOrCreateCXProvider()
                            CallKitObjectManager.getCXProviderImpl().setCallAgent(callAgent: callAgent!)
                            registerForPushNotification()
                        } else {
                            self.showAlert = true
                            self.alertMessage = "Failed to create CallAgent (without CallKit) : \(error?.localizedDescription ?? "Empty Description")"
                        }
                        completionHandler?(error)
                    }
                }
            }
        }
    }

    func declineIncomingCall() {
        guard let incomingCall = self.incomingCall else {
            self.showAlert = true
            self.alertMessage = "No incoming call to reject"
            return
        }

        incomingCall.reject { (error) in
            guard let rejectError = error else {
                return
            }
            self.showAlert = true
            self.alertMessage = rejectError.localizedDescription
            isIncomingCall = false
        }
    }

    func showIncomingCallBanner(_ incomingCall: IncomingCall?) {
        self.incomingCall = incomingCall
    }

    func answerIncomingCall() {
        isIncomingCall = false
        let options = AcceptCallOptions()
        guard let incomingCall = self.incomingCall else {
            return
        }

        guard let deviceManager = deviceManager else {
            return
        }

        localVideoStream.removeAll()

        if(sendingVideo)
        {
            let camera = deviceManager.cameras.first
            let outgoingVideoOptions = OutgoingVideoOptions()
            outgoingVideoOptions.streams.append(LocalVideoStream(camera: camera!))
            options.outgoingVideoOptions = outgoingVideoOptions
        }

        if isCallKitInSDKEnabled {
            incomingCall.accept(options: options) { (call, error) in
                setCallAndObersever(call: call, error: error)
            }
        } else {
            Task {
                await CallKitObjectManager.getCallKitHelper()!.acceptCall(callId: incomingCall.id,
                                                                           options: options) { call, error in
                    setCallAndObersever(call: call, error: error)
                }
            }
        }
    }

    func callRemoved(_ call: Call) {
        self.call = nil
        self.incomingCall = nil
        for data in remoteVideoStreamData {
            data.renderer?.dispose()
        }
        self.previewRenderer?.dispose()
        remoteVideoStreamData.removeAll()
        sendingVideo = false
        Task {
            do {
                try await CallKitObjectManager.getCallKitHelper()?.endCall(callId: call.id)
            } catch {}
        }
    }

    private func createLocalVideoPreview() -> Bool {
        guard let deviceManager = self.deviceManager else {
            self.showAlert = true
            self.alertMessage = "No DeviceManager instance exists"
            return false
        }

        let scalingMode = ScalingMode.fit
        localVideoStream.removeAll()
        localVideoStream.append(LocalVideoStream(camera: deviceManager.cameras.first!))
        previewRenderer = try! VideoStreamRenderer(localVideoStream: localVideoStream.first!)
        previewView = try! previewRenderer!.createView(withOptions: CreateViewOptions(scalingMode:scalingMode))
        self.sendingVideo = true
        return true
    }

    func toggleLocalVideo() {
        guard let call = self.call else {
            if(!sendingVideo) {
                _ = createLocalVideoPreview()
            } else {
                self.sendingVideo = false
                self.previewView = nil
                self.previewRenderer!.dispose()
                self.previewRenderer = nil
            }
            return
        }

        if (sendingVideo) {
            call.stopVideo(stream: localVideoStream.first!) { (error) in
                if (error != nil) {
                    print("Cannot stop video")
                } else {
                    self.sendingVideo = false
                    self.previewView = nil
                    self.previewRenderer!.dispose()
                    self.previewRenderer = nil
                }
            }
        } else {
            if createLocalVideoPreview() {
                call.startVideo(stream:(localVideoStream.first)!) { (error) in
                    if (error != nil) {
                        print("Cannot send local video")
                    }
                }
            }
        }
    }

    func holdCall() {
        guard let call = self.call else {
            self.showAlert = true
            self.alertMessage = "No active call to hold/resume"
            return
        }
        
        if self.isHeld {
            if isCallKitInSDKEnabled {
                call.resume { error in
                    if error == nil {
                        self.isHeld = false
                    }  else {
                        self.showAlert = true
                        self.alertMessage = "Failed to hold the call"
                    }
                }
            } else {
                Task {
                    do {
                        try await CallKitObjectManager.getCallKitHelper()!.holdCall(callId: call.id, onHold: false)
                        self.isHeld = false
                    } catch {
                        self.showAlert = true
                        self.alertMessage = "Failed to hold the call"
                    }
                }
            }
        } else {
            if isCallKitInSDKEnabled {
                call.hold { error in
                    if error == nil {
                        self.isHeld = true
                    } else {
                        self.showAlert = true
                        self.alertMessage = "Failed to resume the call"
                    }
                }
            } else {
                Task {
                    do {
                        try await CallKitObjectManager.getCallKitHelper()!.holdCall(callId: call.id, onHold: true)
                        self.isHeld = true
                    } catch {
                        self.showAlert = true
                        self.alertMessage = "Failed to resume the call"
                    }
                }
            }
        }
    }

    func startCall() {
        Task {
            let outgoingVideoOptions = OutgoingVideoOptions()
            var callees:[CommunicationIdentifier]?
            var startCallOptions: StartCallOptions?
            var joinCallOptions: JoinCallOptions?
            
            var callOptions: CallOptions?
            var meetingLocator: JoinMeetingLocator?
            
            if(sendingVideo)
            {
                guard let deviceManager = self.deviceManager else {
                    self.showAlert = true
                    self.alertMessage = "No DeviceManager instance exists"
                    return
                }
                
                localVideoStream.removeAll()
                localVideoStream.append(LocalVideoStream(camera: deviceManager.cameras.first!))
                outgoingVideoOptions.streams = localVideoStream
            }

            if (self.callee.starts(with: "8:")) {
                callees = [CommunicationUserIdentifier(self.callee)]
                startCallOptions = StartCallOptions()
                startCallOptions!.outgoingVideoOptions = outgoingVideoOptions
                callOptions = startCallOptions
            } else if let groupId = UUID(uuidString: self.callee) {
                let groupCallLocator = GroupCallLocator(groupId: groupId)
                meetingLocator = groupCallLocator
                joinCallOptions = JoinCallOptions()
                joinCallOptions!.outgoingVideoOptions = outgoingVideoOptions
                callOptions = joinCallOptions
            } else if (self.callee.starts(with: "https:")) {
                let teamsMeetingLinkLocator = TeamsMeetingLinkLocator(meetingLink: self.callee)
                meetingLocator = teamsMeetingLinkLocator
                joinCallOptions = JoinCallOptions()
                joinCallOptions!.outgoingVideoOptions = outgoingVideoOptions
                callOptions = joinCallOptions
            }
            
            if self.isCallKitInSDKEnabled {
                guard let callAgent = self.callAgent else {
                    self.showAlert = true
                    self.alertMessage = "No CallAgent instance exists to place the call"
                    return
                }
                
                do {
                    if (self.callee.starts(with: "8:")) {
                        let call = try await callAgent.startCall(participants: callees!, options: startCallOptions!)
                        setCallAndObersever(call: call, error: nil)
                    } else if UUID(uuidString: self.callee) != nil || self.callee.starts(with: "https:") {
                        let call = try await callAgent.join(with: meetingLocator!, joinCallOptions: joinCallOptions!)
                        setCallAndObersever(call: call, error: nil)
                    }
                } catch {
                    setCallAndObersever(call: nil, error: error)
                }
            } else {
                await CallKitObjectManager.getCallKitHelper()!.placeCall(participants: callees,
                                                                         callerDisplayName: "Alice",
                                                                         meetingLocator: meetingLocator,
                                                                         options: callOptions) { call, error in
                    setCallAndObersever(call: call, error: error)
                }
            }
        }
    }

    func setCallAndObersever(call: Call?, error:Error?) {
        if (error == nil) {
            self.call = call
            self.callObserver = CallHandler(self)
            self.call!.delegate = self.callObserver
            self.remoteParticipantObserver = RemoteParticipantObserver(self)
            switchSpeaker()
        } else {
            print("Failed to get call object")
        }
    }

    func endCall() {
        if self.isCallKitInSDKEnabled {
            self.call!.hangUp(options: HangUpOptions()) { (error) in
                if (error != nil) {
                    print("ERROR: It was not possible to hangup the call.") 
                }
            }
        } else {
            Task {
                do {
                    try await CallKitObjectManager.getCallKitHelper()!.endCall(callId: self.call!.id)
                } catch {
                    self.showAlert = true
                    self.alertMessage = "ERROR: It was not possible to hangup the call \(error.localizedDescription)"
                }
            }
        }
        self.previewRenderer?.dispose()
        sendingVideo = false
        isSpeakerOn = false
    }
}

public class RemoteVideoStreamData : NSObject, RendererDelegate {
    public func videoStreamRenderer(didFailToStart renderer: VideoStreamRenderer) {
        owner.errorMessage = "Renderer failed to start"
    }

    private var owner:ContentView
    let stream:RemoteVideoStream
    var renderer:VideoStreamRenderer? {
        didSet {
            if renderer != nil {
                renderer!.delegate = self
            }
        }
    }

    var rendererView: RendererView?

    init(view:ContentView, stream:RemoteVideoStream) {
        owner = view
        self.stream = stream
    }

    public func videoStreamRenderer(didRenderFirstFrame renderer: VideoStreamRenderer) {
        let size:StreamSize = renderer.size
        owner.remoteVideoSize = String(size.width) + " X " + String(size.height)
    }
}

public class RemoteParticipantObserver : NSObject, RemoteParticipantDelegate {
    private var owner:ContentView
    init(_ view:ContentView) {
        owner = view
    }

    public func renderRemoteStream(_ stream: RemoteVideoStream!) {
        let data:RemoteVideoStreamData = RemoteVideoStreamData(view: owner, stream: stream)
        let scalingMode = ScalingMode.fit
        do {
            data.renderer = try VideoStreamRenderer(remoteVideoStream: stream)
            let view:RendererView = try data.renderer!.createView(withOptions: CreateViewOptions(scalingMode:scalingMode))
            owner.remoteVideoStreamData.append(data)
            data.rendererView = view
        } catch let error as NSError {
            self.owner.alertMessage = error.localizedDescription
            self.owner.showAlert = true
        }
    }

    
    public func remoteParticipant(_ remoteParticipant: RemoteParticipant, didChangeVideoStreamState args: VideoStreamStateChangedEventArgs) {
        print("Remote Video Stream state for videoId: \(args.stream.id) is \(args.stream.state)")
        switch args.stream.state {
        case .available:
            if let remoteVideoStream = args.stream as? RemoteVideoStream {
                renderRemoteStream(remoteVideoStream)
            }
            break

        case .stopping:
            if let remoteVideoStream = args.stream as? RemoteVideoStream {
                var i = 0
                for data in owner.remoteVideoStreamData {
                    if data.stream.id == remoteVideoStream.id {
                        data.renderer?.dispose()
                        owner.remoteVideoStreamData.remove(at: i)
                    }
                    i += 1
                }
            }
            break

        default:
            break
        }
    }
}

struct PreviewVideoStream: UIViewRepresentable {
    let view:RendererView
    func makeUIView(context: Context) -> UIView {
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct RemoteVideoView: UIViewRepresentable {
    let view:RendererView
    func makeUIView(context: Context) -> UIView {
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(appPubs: AppPubs())
    }
}
