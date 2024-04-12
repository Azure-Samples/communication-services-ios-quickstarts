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
    private let acsToken = "<ACS_USER_ACCESS_TOKEN>"
    private let cteToken = "<CTE_USER_ACCESS_TOKEN>"

    @State var currentMri: String = "<CTE_MRI>"
    @State var callee: String = "29228d3e-040e-4656-a70e-890ab4e173e4"
    @State var callClient = CallClient()
    @State var callAgent: CallAgent?
    @State var call: Call?
    @State var incomingCall: IncomingCall?
    @State var incomingCallHandler: IncomingCallHandler?
    @State var callHandler:CallHandler?

    @State var teamsCallAgent : TeamsCallAgent?
    @State var teamsCall: TeamsCall?
    @State var teamsIncomingCall: TeamsIncomingCall?
    @State var teamsIncomingCallHandler: TeamsIncomingCallHandler?
    @State var teamsCallHandler:TeamsCallHandler?

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
    @State var isSpeakerOn:Bool = false
    @State var isCte:Bool = false
    @State var isMuted:Bool = false
    @State var isHeld: Bool = false
    @State var callAgentType: String = "None"
    
    @State var callState: String = "None"
    @State var cxProvider: CXProvider?
    @State var remoteParticipantObserver:RemoteParticipantObserver?
    @State var pushToken: Data?
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    var appPubs: AppPubs

    var body: some View {
        HStack {
            Form {
                Section {
                    TextField("Who would you like to call?", text: $callee)
                    Button(action: createCallAgentButton) {
                        Text("Create CallAgent")
                    }
                    Button(action: startCall) {
                        Text("Start Call")
                    }.disabled(callAgent == nil && teamsCallAgent == nil)
                    Button(action: addParticipant) {
                        Text("Add Participant")
                    }.disabled(call == nil && teamsCall == nil)
                    Button(action: holdCall) {
                        Text(isHeld ? "Resume" : "Hold")
                    }.disabled(call == nil && teamsCall == nil)
                    Button(action: switchMicrophone) {
                        Text(isMuted ? "UnMute" : "Mute")
                    }
                    Button(action: endCall) {
                        Text("End Call")
                    }.disabled(call == nil && teamsCall == nil)
                    Button(action: toggleLocalVideo) {
                        HStack {
                            Text(sendingVideo ? "Turn Off Video" : "Turn On Video")
                        }
                    }
                    VStack {
                        Toggle("CTE", isOn: $isCte)
                        Toggle("Speaker", isOn: $isSpeakerOn)
                            .onChange(of: isSpeakerOn) { newValue in
                                switchSpeaker(newValue)
                            }.disabled(call == nil && teamsCall == nil)
                        TextField("Call State", text: $callState)
                            .foregroundColor(.red)
                        TextField("MRI", text: $currentMri)
                            .foregroundColor(.blue)
                        TextField("CallAgent Type", text: $callAgentType)
                            .foregroundColor(.green)
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

    private func getCallBase() -> CommonCall? {
        var callBase: CommonCall?
        
        if let call = self.call {
            callBase = call
        } else if let teamsCall = self.teamsCall {
            callBase = teamsCall
        }

       return callBase
    }

    private func getCallAgentBase() -> CommonCallAgent? {
        var callAgentBase: CommonCallAgent?

        if let callAgent = self.callAgent {
            callAgentBase = callAgent
        } else if let teamsCallAgent = self.teamsCallAgent {
            callAgentBase = teamsCallAgent
        }
        
        return callAgentBase
    }
    
    private func createTeamsCallAgentOptions() -> TeamsCallAgentOptions {
        let options = TeamsCallAgentOptions()
        options.callKitOptions = createCallKitOptions()
        return options
    }
    
    func declineIncomingCall() {
        var incomingCallBase: CommonIncomingCall?

        if incomingCall != nil {
            incomingCallBase = incomingCall
        } else if teamsIncomingCall != nil {
            incomingCallBase = teamsIncomingCall
        }

        guard let incomingCallBase = incomingCallBase else {
            self.showAlert = true
            self.alertMessage = "No incoming call to reject"
            return
        }

        incomingCallBase.reject { (error) in
            guard let rejectError = error else {
                return
            }
            self.showAlert = true
            self.alertMessage = rejectError.localizedDescription
            isIncomingCall = false
        }
    }

    func showIncomingCallBanner(_ incomingCall: CommonIncomingCall?) {
        guard let incomingCallBase = incomingCall else {
            return
        }
        isIncomingCall = true
        if incomingCallBase is IncomingCall {
            self.incomingCall = (incomingCallBase as! IncomingCall)
        } else if incomingCall is TeamsIncomingCall {
            self.teamsIncomingCall = (incomingCall as! TeamsIncomingCall)
        }
    }
    
    func callRemoved(_ call: CommonCall) {
        self.call = nil
        self.teamsCall = nil
        self.incomingCall = nil
        self.teamsIncomingCall = nil

        for data in remoteVideoStreamData {
            data.renderer?.dispose()
        }
        self.previewRenderer?.dispose()
        remoteVideoStreamData.removeAll()
        sendingVideo = false
    }
    
    func setTeamsCallAndObserver(teamsCall: TeamsCall? , error: Error?) {
        guard let teamsCall = teamsCall else {
            self.showAlert = true
            self.alertMessage = "Failed to get Teams Call"
            return
        }

        self.teamsCall = teamsCall
        print("Teams CallId: \(teamsCall.id)")
        self.teamsCallHandler = TeamsCallHandler(self)
        self.teamsCall!.delegate = self.teamsCallHandler
        self.remoteParticipantObserver = RemoteParticipantObserver(self)
        switchSpeaker(nil)
    }

    func addParticipant() {
        let allCallees = self.callee.components(separatedBy: ";")
        
        let callees = allCallees.filter({ (e) -> Bool in (e.starts(with: "8:") )})
            .map { (e) -> CommunicationIdentifier in CommunicationUserIdentifier(e)}
        
        let pstnCallees = allCallees.filter({ (e) -> Bool in !e.starts(with: "8:")})
                                    .map { (e) -> CommunicationIdentifier in PhoneNumberIdentifier(phoneNumber: e.replacingOccurrences(of: "4:", with: "")) }
                
        if let call = call {
            let phoneNumberOptions = AddPhoneNumberOptions()
            phoneNumberOptions.alternateCallerId = PhoneNumberIdentifier(phoneNumber: "+12133947338")
            for pstnCallee in pstnCallees {
                do {
                    try call.add(participant: pstnCallee as! PhoneNumberIdentifier, options: phoneNumberOptions)
                } catch {
                    self.showAlert = true
                    self.alertMessage = "Failed to add phone number \(pstnCallee.rawId)"
                }
            }

            for callee in callees {
                do {
                    try call.add(participant: callee as! CommunicationUserIdentifier)
                } catch {
                    self.showAlert = true
                    self.alertMessage = "Failed to add participant \(callee.rawId)"
                }
            }
        } else if teamsCall != nil {
            self.showAlert = true
            self.alertMessage = "Cannot add participant to a Teams Call."
        }
        
    }

    func switchMicrophone() {

        if let callBase = self.getCallBase() {
            if self.isMuted {
                callBase.unmuteOutgoingAudio() { error in
                    if error == nil {
                        isMuted = false
                    } else {
                        self.showAlert = true
                        self.alertMessage = "Failed to unmute audio"
                    }
                }
            } else {
                callBase.muteOutgoingAudio() { error in
                    if error == nil {
                        isMuted = true
                    } else {
                        self.showAlert = true
                        self.alertMessage = "Failed to mute audio"
                    }
                }
            }
        } else {
            isMuted = !isMuted
        }
        userDefaults.set(isMuted, forKey: "isMuted")
    }

    func switchSpeaker(_ newValue: Bool?) -> Void {
        var muteSpeaker = false
        if newValue == nil {
            muteSpeaker = userDefaults.value(forKey: "isSpeakerOn") as? Bool ?? false
        } else {
            muteSpeaker = newValue!
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            if muteSpeaker {
                try audioSession.overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
            } else {
                try audioSession.overrideOutputAudioPort(AVAudioSession.PortOverride.none)
            }
            userDefaults.set(self.isSpeakerOn, forKey: "isSpeakerOn")
        } catch {
            self.showAlert = true
            self.alertMessage = "Failed to switch speaker: code: \(error.localizedDescription)"
        }
    }

    private func createCallAgentOptions() -> CallAgentOptions {
        let options = CallAgentOptions()
        options.pushNotificationTtl = 25*60*60 // Extending device token TTL to 25 hours
        options.callKitOptions = createCallKitOptions()
        return options
    }

    private func createCallKitOptions() -> CallKitOptions {
        let callKitOptions = CallKitOptions(with: CallKitHelper.createCXProvideConfiguration())
        callKitOptions.provideRemoteInfo = self.provideCallKitRemoteInfo
        callKitOptions.configureAudioSession = self.configureAudioSession
        return callKitOptions
    }
    
    private func configureAudioSession() -> Error? {
        let audioSession: AVAudioSession = AVAudioSession.sharedInstance()
        //let audioSessionMode: AVAudioSession.Mode = .default
        //let options: AVAudioSession.CategoryOptions = .allowBluetooth
        var configError: Error?
        do {
            try audioSession.setCategory(.playAndRecord)
            os_log("==> configureAudioSession done", log:self.log)
        } catch {
            os_log("==> configureAudioSession failed", log:self.log)
            configError = error
        }

        return configError
    }
    
    func provideCallKitRemoteInfo(callerInfo: CallerInfo) -> CallKitRemoteInfo
    {
        let callKitRemoteInfo = CallKitRemoteInfo()
        // Replace CALL_TO_PHONENUMBER_BY_APP by finding the map of the
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
            guard let callAgentBase = self.getCallAgentBase() else {
                return
            }
            
            // CallAgent is created normally handle the push
            callAgentBase.handlePush(notification: callNotification) { (error) in
                if error == nil {
                    os_log("SDK handle push notification normal mode: passed", log:self.log)
                } else {
                    os_log("SDK handle push notification normal mode: failed", log:self.log)
                }
            }
        }

        createCallAgent { error in
            handlePush()
        }
    }

    private func registerForPushNotification() {

        if let callAgentBase = self.getCallAgentBase(),
           let pushToken = self.pushToken {
            callAgentBase.registerPushNotifications(deviceToken: pushToken) { error in
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

    func createCallAgentButton() {
        createCallAgent(completionHandler: nil)
    }

    private func createCallAgent(completionHandler: ((Error?) -> Void)?) {
        DispatchQueue.main.async {
            if isCte {
                if teamsCallAgent != nil {
                    completionHandler?(nil)
                    return
                }

                var userCredential: CommunicationTokenCredential
                do {
                    userCredential = try CommunicationTokenCredential(token: cteToken)
                } catch {
                    self.showAlert = true
                    self.alertMessage = "Failed to create CommunicationTokenCredential for Teams"
                    completionHandler?(CreateCallAgentErrors.noToken)
                    return
                }

                callClient.createTeamsCallAgent(userCredential: userCredential,
                                                options: createTeamsCallAgentOptions()) { (agent, error) in
                    if error == nil {
                        self.teamsCallAgent = agent
                        self.cxProvider = nil
                        print("Teams Call agent successfully created.")
                        teamsIncomingCallHandler = TeamsIncomingCallHandler(contentView: self)
                        self.teamsCallAgent!.delegate = teamsIncomingCallHandler
                        registerForPushNotification()
                        callAgentType = "CTE CallAgent"
                        callAgent?.dispose()
                    } else {
                        self.showAlert = true
                        self.alertMessage = "Failed to create CallAgent (with CallKit) : \(error?.localizedDescription ?? "Empty Description")"
                    }
                    completionHandler?(error)
                }
            } else {
                if callAgent != nil {
                    completionHandler?(nil)
                    return
                }

                var userCredential: CommunicationTokenCredential
                do {
                    userCredential = try CommunicationTokenCredential(token: acsToken)
                } catch {
                    self.showAlert = true
                    self.alertMessage = "Failed to create CommunicationTokenCredential"
                    completionHandler?(CreateCallAgentErrors.noToken)
                    return
                }

                currentMri = getMri(recvdToken: acsToken)

                self.callClient.createCallAgent(userCredential: userCredential,
                                                options: createCallAgentOptions()) { (agent, error) in
                    if error == nil {
                        self.callAgent = agent
                        self.cxProvider = nil
                        print("Call agent successfully created.")
                        incomingCallHandler = IncomingCallHandler(contentView: self)
                        self.callAgent!.delegate = incomingCallHandler
                        registerForPushNotification()
                        callAgentType = "ACS CallAgent"
                        teamsCallAgent?.dispose()
                    } else {
                        self.showAlert = true
                        self.alertMessage = "Failed to create CallAgent (with CallKit) : \(error?.localizedDescription ?? "Empty Description")"
                    }
                    completionHandler?(error)
                }
            }
        }
    }

    func answerIncomingCall() {
        isIncomingCall = false
        let options: CallOptions = isCte ? AcceptTeamsCallOptions() : AcceptCallOptions()

        if sendingVideo {
            let outgoingVideoOptions = OutgoingVideoOptions()
            initLocalVideoStreams()
            if let firstLocalVideoStream = localVideoStream.first {
                outgoingVideoOptions.streams.append(firstLocalVideoStream)
                options.outgoingVideoOptions = outgoingVideoOptions
            } else {
                self.showAlert = true
                self.alertMessage = "Failed to start video"
            }
        }
        
        if isMuted {
            let outgoingAudioOptions = OutgoingAudioOptions()
            outgoingAudioOptions.muted = true
            options.outgoingAudioOptions = outgoingAudioOptions
        }
        
        if isCte {
            guard let teamsIncomingCall = self.teamsIncomingCall else {
                self.showAlert = true
                self.alertMessage = "No teams incoming call to accept"
                return
            }
            
            guard let options = options as? AcceptTeamsCallOptions else {
                self.showAlert = true
                self.alertMessage = "Options not of type AcceptTeamsCallOptions"
                return
            }

            teamsIncomingCall.accept(options: options) { teamsCall, error in
                setTeamsCallAndObserver(teamsCall: teamsCall, error: error)
            }
        } else {
            guard let incomingCall = self.incomingCall else {
                self.showAlert = true
                self.alertMessage = "No acs incoming call to accept"
                return
            }

            guard let options = options as? AcceptCallOptions else {
                self.showAlert = true
                self.alertMessage = "Options not of type AcceptCallOptions"
                return
            }

            incomingCall.accept(options: options) { (call, error) in
                setCallAndObersever(call: call, error: error)
            }
        }
    }

    private func initLocalVideoStreams() {
        guard let deviceManager = self.deviceManager else {
            self.showAlert = true
            self.alertMessage = "No DeviceManager instance exists"
            return
        }
        guard let camera = deviceManager.cameras.first else {
            self.showAlert = true
            self.alertMessage = "Failed to get camera"
            return
        }
        localVideoStream.removeAll()
        localVideoStream.append(LocalVideoStream(camera: camera))
    }

    private func createLocalVideoPreview() {
        let scalingMode = ScalingMode.fit
        initLocalVideoStreams()
        do {
            if let firstLocalVideoStream = localVideoStream.first {
                previewRenderer = try VideoStreamRenderer(localVideoStream: firstLocalVideoStream)
                previewView = try previewRenderer!.createView(withOptions: CreateViewOptions(scalingMode:scalingMode))
                self.sendingVideo = true
            } else {
                self.showAlert = true
                self.alertMessage = "Failed to get first video stream"
            }
        } catch let error as NSError {
            self.showAlert = true
            self.alertMessage = error.localizedDescription
        }
    }

    func toggleLocalVideo() {
        guard let callBase = self.getCallBase() else {
            if(!sendingVideo) {
                createLocalVideoPreview()
            } else {
                self.sendingVideo = false
                self.previewView = nil
                self.previewRenderer!.dispose()
                self.previewRenderer = nil
            }
            return
        }

        if (sendingVideo) {
            if let firstLocalVideoStream = localVideoStream.first {
                callBase.stopVideo(stream: firstLocalVideoStream) { (error) in
                    if (error == nil) {
                        self.sendingVideo = false
                        self.previewView = nil
                        self.previewRenderer?.dispose()
                        self.previewRenderer = nil
                    } else {
                        self.showAlert = true
                        self.alertMessage = "Failed to stop video"
                        return
                    }
                }
            }
        } else {
            createLocalVideoPreview()
            guard let firstLocalVideoStream = localVideoStream.first else {
                self.showAlert = true
                self.alertMessage = "Failed to start preview"
                return
            }
            callBase.startVideo(stream:firstLocalVideoStream) { (error) in
                if (error != nil) {
                    print("Cannot send local video")
                }
            }
        }
    }

    func holdCall() {

        guard let callBase = self.getCallBase() else {
            self.showAlert = true
            self.alertMessage = "No active call to hold/resume"
            return
        }
        
        if self.isHeld {
            callBase.resume { error in
                if error == nil {
                    self.isHeld = false
                }  else {
                    self.showAlert = true
                    self.alertMessage = "Failed to hold the call"
                }
            }
        } else {
            callBase.hold { error in
                if error == nil {
                    self.isHeld = true
                } else {
                    self.showAlert = true
                    self.alertMessage = "Failed to resume the call"
                }
            }
        }
    }

    func startCall() {
        Task {
            var callOptions: CallOptions?
            var meetingLocator: JoinMeetingLocator?
            var callees:[CommunicationIdentifier] = []
            
            if self.callee.starts(with: "8:") {
                let calleesRaw = self.callee.split(separator: ";")
                for calleeRaw in calleesRaw {
                    if calleeRaw.starts(with: "8:orgid") {
                        callees.append(MicrosoftTeamsUserIdentifier(userId: String(calleeRaw)))
                    } else {
                        callees.append(CommunicationUserIdentifier(String(calleeRaw)))
                    }
                }

                if isCte {
                    if callees.count == 1 {
                        callOptions = StartTeamsCallOptions()
                    } else if callees.count > 1 {
                        // When starting a call with multiple participants , need to pass a thread ID
                        self.showAlert = true
                        self.alertMessage = "Adding participant not suported in a Teams Call"
                        return
                    }
                } else {
                    callOptions = StartCallOptions()
                }
            } else if self.callee.starts(with: "4:") {
                if isCte {
                    let calleesRaw = self.callee.split(separator: ";")
                    for calleeRaw in calleesRaw {
                        callees.append(PhoneNumberIdentifier(phoneNumber: String(calleeRaw.replacingOccurrences(of: "4:", with: ""))))
                    }

                    if callees.count == 1 {
                        callOptions = StartCallOptions()
                    } else if callees.count > 1 {
                        self.showAlert = true
                        self.alertMessage = "Adding participant not suported in a Teams Call"
                        return
                    }
                } else {
                    let startCallOptions = StartCallOptions()
                    startCallOptions.alternateCallerId = PhoneNumberIdentifier(phoneNumber: "+12133947338")
                }
            } else if let groupId = UUID(uuidString: self.callee) {
                if isCte {
                    self.showAlert = true
                    self.alertMessage = "CTE does not support group call"
                    return
                } else {
                    let groupCallLocator = GroupCallLocator(groupId: groupId)
                    meetingLocator = groupCallLocator
                    callOptions = JoinCallOptions()
                }
            } else if (self.callee.starts(with: "https:")) {
                let teamsMeetingLinkLocator = TeamsMeetingLinkLocator(meetingLink: self.callee)
                if isCte {
                    callOptions = JoinTeamsCallOptions()
                } else {
                    callOptions = JoinCallOptions()
                }
                meetingLocator = teamsMeetingLinkLocator
            }

            
            if sendingVideo
            {
                if let callOptions = callOptions {
                    let outgoingVideoOptions = OutgoingVideoOptions()
                    initLocalVideoStreams()
                    outgoingVideoOptions.streams = localVideoStream
                    callOptions.outgoingVideoOptions = outgoingVideoOptions
                } else {
                    self.showAlert = true
                    self.alertMessage = "Failed to set video options"
                    return
                }
            }

            if isMuted {
                if let callOptions = callOptions {
                    let outgoingAudioOptions = OutgoingAudioOptions()
                    outgoingAudioOptions.muted = true
                    callOptions.outgoingAudioOptions = outgoingAudioOptions
                } else {
                    self.showAlert = true
                    self.alertMessage = "Failed to start call muted"
                    return
                }
            }

            if isCte {
                guard let teamsCallAgent = self.teamsCallAgent else {
                    self.showAlert = true
                    self.alertMessage = "No Teams CallAgent instance exists to place the call"
                    return
                }
                
                do {
                    var teamsCall: TeamsCall?
                    if self.callee.starts(with: "https:") {
                        if let meetingLocator = meetingLocator as? TeamsMeetingLinkLocator,
                           let options = callOptions as? JoinTeamsCallOptions {
                            teamsCall = try await teamsCallAgent.join(with: meetingLocator,
                                                                      joinTeamsCallOptions: options)
                            } else {
                                self.showAlert = true
                                self.alertMessage = "Failed to start ACS call"
                                return
                            }
                    } else {
                        if callees.count == 1 {
                            if let firstCallee = callees.first,
                               let options = callOptions as? StartTeamsCallOptions {
                                teamsCall = try await teamsCallAgent.startCall(participant: firstCallee,
                                                                                   options: options)
                            } else {
                                self.showAlert = true
                                self.alertMessage = "Failed to start teams call"
                                return
                            }
                        } else if callees.count > 1 {
                            self.showAlert = true
                            self.alertMessage = "Teams CallAgent cannot start a call with multiple participants"
                            return
                        }
                    }
                    setTeamsCallAndObserver(teamsCall: teamsCall, error: nil)
                } catch {
                    setTeamsCallAndObserver(teamsCall: nil, error: error)
                }
            } else {
                guard let callAgent = self.callAgent else {
                    self.showAlert = true
                    self.alertMessage = "No CallAgent instance exists to place the call"
                    return
                }
                
                do {
                    var call: Call?
                    if self.callee.starts(with: "https:") {
                        if let meetingLocator = meetingLocator,
                                  let options = callOptions as? JoinCallOptions {
                            call = try await callAgent.join(with: meetingLocator, joinCallOptions: options)
                        } else {
                            self.showAlert = true
                            self.alertMessage = "Failed to join call with meetingLocator"
                            return
                        }
                    } else if let meetingLocator = meetingLocator as? GroupCallLocator,
                              let options = callOptions as? JoinCallOptions {
                        call = try await callAgent.join(with: meetingLocator, joinCallOptions: options)
                    } else if let options = callOptions as? StartCallOptions {
                        call = try await callAgent.startCall(participants: callees, options: options)
                    } else {
                        self.showAlert = true
                        self.alertMessage = "Failed to join call"
                        return
                    }
                    setCallAndObersever(call: call, error: nil)
                } catch {
                    setCallAndObersever(call: nil, error: error)
                }
            }
        }
    }

    func setCallAndObersever(call: Call?, error:Error?) {

        guard let call = call else {
            self.showAlert = true
            self.alertMessage = "Failed to get Call"
            return
        }

        self.call = call
        print("ACS CallId: \(call.id)")
        self.callHandler = CallHandler(self)
        call.delegate = self.callHandler
        self.remoteParticipantObserver = RemoteParticipantObserver(self)
        switchSpeaker(nil)
    }

    func endCall() {
        guard let callBase = self.getCallBase() else {
            return
        }

        callBase.hangUp(options: HangUpOptions()) { (error) in
            if (error != nil) {
                print("ERROR: It was not possible to hangup the call.")
            }
            self.call = nil
            self.teamsCall = nil
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

    
    private func cleanupRemoteVideo(args: VideoStreamStateChangedEventArgs) {
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
    }
    
    public func remoteParticipant(_ remoteParticipant: RemoteParticipant, didChangeVideoStreamState args: VideoStreamStateChangedEventArgs) {
        print("Remote Video Stream state for videoId: \(args.stream.id) is \(args.stream.state)")
        switch args.stream.state {
        case .available:
            if let remoteVideoStream = args.stream as? RemoteVideoStream {
                renderRemoteStream(remoteVideoStream)
            }
            break

        case .notAvailable:
            cleanupRemoteVideo(args: args)
            break

        case .stopping:
            cleanupRemoteVideo(args: args)
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
