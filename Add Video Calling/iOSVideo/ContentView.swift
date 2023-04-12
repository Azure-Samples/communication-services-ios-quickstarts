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

struct ContentView: View {
    init(appPubs: AppPubs) {
        self.appPubs = appPubs
    }

    private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "ACSVideoSample")
    private let token = "<USER_ACCESS_TOKEN>"

    @State var callee: String = "8:echo123"
    @State var callClient = CallClient()
    @State var callAgent: CallAgent?
    @State var call: Call?
    @State var deviceManager: DeviceManager?
    @State var localVideoStream = [LocalVideoStream]()
    @State var incomingCall: IncomingCall?
    @State var sendingVideo:Bool = false
    @State var errorMessage:String = "Unknown"

    @State var remoteVideoStreamData:[Int32:RemoteVideoStreamData] = [:]
    @State var previewRenderer:VideoStreamRenderer? = nil
    @State var previewView:RendererView? = nil
    @State var remoteRenderer:VideoStreamRenderer? = nil
    @State var remoteViews:[RendererView] = []
    @State var remoteParticipant: RemoteParticipant?
    @State var remoteVideoSize:String = "Unknown"
    @State var isIncomingCall:Bool = false
    @State var showAlert = false
    @State var alertMessage = ""
    @State var userDefaults: UserDefaults = .standard
    @State var isCallKitInSDKEnabled = false
    @State var isSpeakerOn:Bool = false
    @State var isMuted:Bool = false
    @State var isHeld: Bool = false
    
    @State var callState: String = "None"
    @State var incomingCallHandler: IncomingCallHandler?
    @State var cxProvider: CXProvider?
    @State var callObserver:CallObserver?
    @State var remoteParticipantObserver:RemoteParticipantObserver?
    
    private let callKitHelper: CallKitHelper? = CallKitObjectManager.getOrCreateCallKitHelper()

    @State var pushToken: Data?

    var appPubs: AppPubs

    var body: some View {
        NavigationView {
            ZStack{
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
                        Toggle("Enable CallKit in SDK", isOn: $isCallKitInSDKEnabled)
                            .onChange(of: isCallKitInSDKEnabled) { _ in
                                userDefaults.set(self.isCallKitInSDKEnabled, forKey: "isCallKitInSDKEnabled")
                                createCallAgent(completionHandler: nil)
                            }.disabled(call != nil)

                        Toggle("Speaker", isOn: $isSpeakerOn)
                            .onChange(of: isSpeakerOn) { _ in
                                switchSpeaker()
                            }.disabled(call == nil)
                        TextField("Call State", text: $callState)
                            .foregroundColor(.red)
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
                ZStack{
                    VStack {
                        ForEach(remoteViews, id:\.self) { renderer in
                            ZStack{
                                VStack{
                                    RemoteVideoView(view: renderer)
                                        .frame(width: .infinity, height: .infinity)
                                        .background(Color(.lightGray))
                                }
                            }
                            Button(action: endCall) {
                                Text("End Call")
                            }.disabled(call == nil)
                            Button(action: toggleLocalVideo) {
                                HStack {
                                    Text(sendingVideo ? "Turn Off Video" : "Turn On Video")
                                }
                            }
                            Button(action: switchSpeaker) {
                                HStack {
                                    Text(isSpeakerOn ? "Turn Off Speaker" : "Turn On Speaker")
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

             if callAgent == nil {
                 createCallAgent(completionHandler: nil)
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
            #if BETA
            call.updateOutgoingAudio(mute: !isMuted) { error in
                if error == nil {
                    isMuted = !isMuted
                } else {
                    self.showAlert = true
                    self.alertMessage = "Failed to unmute/mute audio"
                }
            }
            #else
            if self.isMuted {
                call.unmute() { error in
                    if error == nil {
                        isMuted = false
                    } else {
                        self.showAlert = true
                        self.alertMessage = "Failed to unmute audio"
                    }
                }
            } else {
                call.mute() { error in
                    if error == nil {
                        isMuted = true
                    } else {
                        self.showAlert = true
                        self.alertMessage = "Failed to mute audio"
                    }
                }
            }
            #endif
        } else {
            Task {
                await callKitHelper!.muteCall(callId:call.id, isMuted: !isMuted) { error in
                    if error == nil {
                        isMuted = !isMuted
                    } else {
                        self.showAlert = true
                        self.alertMessage = "Failed to mute the call (without CallKit)"
                    }
                }
            }
        }
        
        userDefaults.set(isMuted, forKey: "isMuted")
    }

    func switchSpeaker() -> Void {
        let audioSession = AVAudioSession.sharedInstance()
        if isSpeakerOn {
            try! audioSession.overrideOutputAudioPort(AVAudioSession.PortOverride.none)
        } else {
            try! audioSession.overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
        }
        isSpeakerOn = !isSpeakerOn
        userDefaults.set(self.isSpeakerOn, forKey: "isSpeakerOn")
    }

    private func createCallAgentOptions() -> CallAgentOptions {
        let options = CallAgentOptions()
        #if BETA
        options.callKitOptions = createCallKitOptions()
        #endif
        
        return options
    }

    #if BETA
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

    #endif

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

    private func createCallAgent(completionHandler: ((Error?) -> Void)?) {
        var userCredential: CommunicationTokenCredential
        do {
            userCredential = try CommunicationTokenCredential(token: token)
        } catch {
            self.showAlert = true
            self.alertMessage = "Failed to create CommunicationTokenCredential"
            completionHandler?(CreateCallAgentErrors.noToken)
            return
        }

        if callAgent != nil {
            // Have to dispose existing CallAgent if present
            // Because we cannot create two CallAgent's
            callAgent!.dispose()
            callAgent = nil
        }

        if userDefaults.value(forKey: "isCallKitInSDKEnabled") as? Bool ?? isCallKitInSDKEnabled {
            #if BETA
            self.callClient.createCallAgent(userCredential: userCredential,
                                            options: createCallAgentOptions()) { (agent, error) in
                if error == nil {
                    self.callAgent = agent
                    self.cxProvider = nil
                    print("Call agent successfully created.")
                    incomingCallHandler = IncomingCallHandler(contentView: self)
                    self.callAgent!.delegate = incomingCallHandler
                    registerForPushNotification()
                } else {
                    self.showAlert = true
                    self.alertMessage = "Failed to create CallAgent (with CallKit)"
                }
                completionHandler?(error)
            }
            #else
                self.showAlert = true
                self.alertMessage = "ACS CallKit available only in Beta builds"
                self.isCallKitInSDKEnabled = false
                completionHandler?(CreateCallAgentErrors.callKitInSDKNotSupported)
            #endif
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
                    self.alertMessage = "Failed to create CallAgent (without CallKit)"
                }
                completionHandler?(error)
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
        isIncomingCall = true
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
            localVideoStream.append(LocalVideoStream(camera: camera!))
            #if BETA
            let videoOptions = VideoOptions(outgoingVideoStreams: localVideoStream)
            #else
            let videoOptions = VideoOptions(localVideoStreams: localVideoStream)
            #endif
            options.videoOptions = videoOptions
        }

        if isCallKitInSDKEnabled {
            incomingCall.accept(options: options) { (call, error) in
                setCallAndObersever(call: call, error: error)
            }
        } else {
            Task {
                await callKitHelper!.acceptCall(callId: incomingCall.id,
                                                                           options: options) { call, error in
                    setCallAndObersever(call: call, error: error)
                }
            }
        }
    }

    func callRemoved(_ call: Call) {
        self.call = nil
        self.incomingCall = nil
        self.remoteRenderer?.dispose()
        for data in remoteVideoStreamData.values {
            data.renderer?.dispose()
        }
        self.previewRenderer?.dispose()
        sendingVideo = false
        Task {
            await callKitHelper?.endCall(callId: call.id) { error in
            }
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
                    await callKitHelper!.holdCall(callId: call.id, onHold: false) { error in
                        if error == nil {
                            self.isHeld = false
                        } else {
                            self.showAlert = true
                            self.alertMessage = "Failed to hold the call"
                        }
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
                    await callKitHelper!.holdCall(callId: call.id, onHold: true) { error in
                        if error == nil {
                            self.isHeld = true
                        } else {
                            self.showAlert = true
                            self.alertMessage = "Failed to resume the call"
                        }
                    }
                }
            }
        }
    }

    func startCall() {
        let startCallOptions = StartCallOptions()
        if(sendingVideo)
        {
            guard let deviceManager = self.deviceManager else {
                self.showAlert = true
                self.alertMessage = "No DeviceManager instance exists"
                return
            }

            localVideoStream.removeAll()
            localVideoStream.append(LocalVideoStream(camera: deviceManager.cameras.first!))
            #if BETA
            let videoOptions = VideoOptions(outgoingVideoStreams: localVideoStream)
            #else
            let videoOptions = VideoOptions(localVideoStreams: localVideoStream)
            #endif
            startCallOptions.videoOptions = videoOptions
        }
        let callees:[CommunicationIdentifier] = [CommunicationUserIdentifier(self.callee)]
        
        if self.isCallKitInSDKEnabled {
            guard let callAgent = self.callAgent else {
                self.showAlert = true
                self.alertMessage = "No CallAgent instance exists to place the call"
                return
            }

            callAgent.startCall(participants: callees, options: startCallOptions) { (call, error) in
                setCallAndObersever(call: call, error: error)
            }
        } else {
            Task {
                await callKitHelper!.placeCall(participants: callees,
                                              callerDisplayName: "Alice",
                                              meetingLocator: nil,
                                              options: startCallOptions) { call, error in
                    setCallAndObersever(call: call, error: error)
                }
            }
        }
    }

    func setCallAndObersever(call:Call!, error:Error?) {
        if (error == nil) {
            self.call = call
            self.callObserver = CallObserver(self)
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
                await callKitHelper!.endCall(callId: self.call!.id) { error in
                    if (error != nil) {
                        print("ERROR: It was not possible to hangup the call.")
                    }
                }
            }
        }
        self.previewRenderer?.dispose()
        self.remoteRenderer?.dispose()
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

    var views:[RendererView] = []
    init(view:ContentView, stream:RemoteVideoStream) {
        owner = view
        self.stream = stream
    }

    public func videoStreamRenderer(didRenderFirstFrame renderer: VideoStreamRenderer) {
        let size:StreamSize = renderer.size
        owner.remoteVideoSize = String(size.width) + " X " + String(size.height)
    }
}

public class CallObserver: NSObject, CallDelegate, IncomingCallDelegate {
    private var owner: ContentView
    private var callKitHelper: CallKitHelper?
    
    init(_ view:ContentView) {
        owner = view
    }

    public func call(_ call: Call, didChangeState args: PropertyChangedEventArgs) {
        switch call.state {
        case .connected:
            owner.callState = "Connected"
        case .connecting:
            owner.callState = "Connecting"
        case .disconnected:
            owner.callState = "Disconnected"
        case .disconnecting:
            owner.callState = "Disconnecting"
        case .inLobby:
            owner.callState = "InLobby"
        case .localHold:
            owner.callState = "LocalHold"
        case .remoteHold:
            owner.callState = "RemoteHold"
        case .ringing:
            owner.callState = "Ringing"
        default:
            owner.callState = "None"
        }

        if(call.state == CallState.connected) {
            initialCallParticipant()
        }

        Task {
            await callKitHelper?.reportOutgoingCall(call: call)
        }
    }
    
    #if BETA
    public func call(_ call: Call, didUpdateOutgoingAudioState args: PropertyChangedEventArgs) {
        owner.isMuted = call.isOutgoingAudioMuted
    }
    #else
    public func call(_ call: Call, didChangeMuteState args: PropertyChangedEventArgs) {
        owner.isMuted = call.isMuted
    }
    #endif

    public func call(_ call: Call, didUpdateRemoteParticipant args: ParticipantsUpdatedEventArgs) {
        for participant in args.addedParticipants {
            participant.delegate = owner.remoteParticipantObserver
            for stream in participant.videoStreams {
                if !owner.remoteVideoStreamData.isEmpty {
                    return
                }
                let data:RemoteVideoStreamData = RemoteVideoStreamData(view: owner, stream: stream)
                let scalingMode = ScalingMode.fit
                data.renderer = try! VideoStreamRenderer(remoteVideoStream: stream)
                let view:RendererView = try! data.renderer!.createView(withOptions: CreateViewOptions(scalingMode:scalingMode))
                data.views.append(view)
                self.owner.remoteViews.append(view)
                owner.remoteVideoStreamData[stream.id] = data
            }
            owner.remoteParticipant = participant
        }
    }

    public func initialCallParticipant() {
        for participant in owner.call!.remoteParticipants {
            participant.delegate = owner.remoteParticipantObserver
            for stream in participant.videoStreams {
                renderRemoteStream(stream)
            }
            owner.remoteParticipant = participant
        }
    }

    public func renderRemoteStream(_ stream: RemoteVideoStream!) {
        if !owner.remoteVideoStreamData.isEmpty {
            return
        }
        let data:RemoteVideoStreamData = RemoteVideoStreamData(view: owner, stream: stream)
        let scalingMode = ScalingMode.fit
        data.renderer = try! VideoStreamRenderer(remoteVideoStream: stream)
        let view:RendererView = try! data.renderer!.createView(withOptions: CreateViewOptions(scalingMode:scalingMode))
        self.owner.remoteViews.append(view)
        owner.remoteVideoStreamData[stream.id] = data
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
            self.owner.remoteViews.append(view)
            owner.remoteVideoStreamData[stream.id] = data
        } catch let error as NSError {
            self.owner.alertMessage = error.localizedDescription
            self.owner.showAlert = true
        }
    }

    public func remoteParticipant(_ remoteParticipant: RemoteParticipant, didUpdateVideoStreams args: RemoteVideoStreamsEventArgs) {
        for stream in args.addedRemoteVideoStreams {
            renderRemoteStream(stream)
        }
        for _ in args.removedRemoteVideoStreams {
            for data in owner.remoteVideoStreamData.values {
                data.renderer?.dispose()
            }
            owner.remoteViews.removeAll()
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
