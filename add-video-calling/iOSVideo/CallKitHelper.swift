import Foundation
import CallKit
import AzureCommunicationCommon
import AzureCommunicationCalling
import AVFAudio

enum CallKitErrors: String, Error {
    case invalidParticipants = "Invalid participants provided"
    case unknownOutgoingCallType = "Unknown outgoing call type"
    case noIncomingCallFound = "No incoming call found to accept"
    case noCallAgent = "No CallAgent created"
}

struct ActiveCallInfo {
    var completionHandler: (Error?) -> Void
}

struct OutInCallInfo {
    var participants: [CommunicationIdentifier]?
    var meetingLocator: JoinMeetingLocator?
    var options: Any?
    var completionHandler: (Call?, Error?) -> Void
}

// We cannot create recreate CXProvider everytime
// For e.g. if one CXProvider reports incoming call and another
// CXProvider instance accepts the call, the operation fails.
// So we need to ensure we have Singleton CXProvider instance
final class CallKitObjectManager {
    private static var callKitHelper: CallKitHelper?
    private static var cxProvider: CXProvider?
    private static var cxProviderImpl: CxProviderDelegateImpl?
    private static var userDefaults: UserDefaults = .standard

    static func createCXProvideConfiguration() -> CXProviderConfiguration {
        let providerConfig = CXProviderConfiguration()
        providerConfig.supportsVideo = true
        providerConfig.maximumCallsPerCallGroup = 1
        providerConfig.includesCallsInRecents = true
        providerConfig.supportedHandleTypes = [.phoneNumber, .generic]
        return providerConfig
    }

    static func getOrCreateCXProvider() -> CXProvider? {
        if userDefaults.value(forKey: "isCallKitInSDKEnabled") as? Bool ?? false {
            return nil
        }

        if cxProvider == nil {
            cxProvider = CXProvider(configuration: createCXProvideConfiguration())
            callKitHelper = CallKitHelper()
            cxProviderImpl = CxProviderDelegateImpl(with: callKitHelper!)
            cxProvider!.setDelegate(self.cxProviderImpl, queue: nil)
        }

        return cxProvider!
    }

    static func deInitCallKitInApp() {
        callKitHelper = nil
        cxProvider = nil
        cxProviderImpl = nil
    }

    static func getCXProviderImpl() -> CxProviderDelegateImpl {
        return cxProviderImpl!
    }

    static func getCallKitHelper() -> CallKitHelper? {
        return callKitHelper
    }
}

final class CxProviderDelegateImpl : NSObject, CXProviderDelegate {
    private var callKitHelper: CallKitHelper
    private var callAgent: CallAgent?
    
    init(with callKitHelper: CallKitHelper) {
        self.callKitHelper = callKitHelper
    }

    func setCallAgent(callAgent: CallAgent) {
        self.callAgent = callAgent
    }

    private func configureAudioSession() -> Error? {
        let audioSession: AVAudioSession = AVAudioSession.sharedInstance()

        var configError: Error?
        do {
            try audioSession.setCategory(.playAndRecord)
        } catch {
            configError = error
        }

        return configError
    }

    private func stopAudio(call: Call) async throws {
        #if BETA
        try await call.stopAudio(direction: .incoming)
        try await call.stopAudio(direction: .outgoing)
        #endif
    }
    
    private func startAudio(call: Call) async throws {
        #if BETA
        try await call.startAudio(stream: LocalAudioStream())
        try await call.startAudio(stream: RemoteAudioStream())
        // TODO: Check if mute was user initiated or not
        //try await call.updateOutgoingAudio(mute: false)
        //try await call.updateIncomingAudio(mute: false)
        #endif
    }

    func providerDidReset(_ provider: CXProvider) {
        // No-op
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        Task {
            guard let activeCall = await self.callKitHelper.getActiveCall(callId: action.callUUID.uuidString) else {
                action.fail()
                return
            }
            
            let activeCallInfo = await self.callKitHelper.getActiveCallInfo(transactionId: action.uuid.uuidString)

            do {
                if action.isOnHold {
                    try await activeCall.hold()
                } else {
                    // Dont resume the audio here, have to to wait for `didActivateAudioSession`
                    try await activeCall.resume()
                }
                action.fulfill()
                activeCallInfo?.completionHandler(nil)
            } catch {
                action.fail()
                activeCallInfo?.completionHandler(error)
            }
            
            await self.callKitHelper.removeActiveCallInfo(transactionId: action.uuid.uuidString)
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        Task {
            guard let activeCall = await self.callKitHelper.getActiveCall(callId: action.callUUID.uuidString) else {
                action.fail()
                return
            }

            let activeCallInfo = await self.callKitHelper.getActiveCallInfo(transactionId: action.uuid.uuidString)

            do {
                if action.isMuted {
                    try await activeCall.muteOutgoingAudio()
                } else {
                    try await activeCall.unmuteOutgoingAudio()
                }
                action.fulfill()
                activeCallInfo?.completionHandler(nil)
            } catch {
                action.fail()
                activeCallInfo?.completionHandler(error)
            }
            
            await self.callKitHelper.removeActiveCallInfo(transactionId: action.uuid.uuidString)
        }
    }

    func setMutedAudioOptions(callOptions: inout CallOptions) {
        let outgoingAudioOptions = OutgoingAudioOptions()
        outgoingAudioOptions.muted = true
        callOptions.outgoingAudioOptions = outgoingAudioOptions
        
        let incomingAudioOptions = IncomingAudioOptions()
        incomingAudioOptions.muted = true
        callOptions.incomingAudioOptions = incomingAudioOptions
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        Task {
            // this can be nil and its ok because this can also directly come from CallKit
            let outInCallInfo = await callKitHelper.getOutInCallInfo(transactionId: action.uuid)

            let completionBlock : ((Call?, Error?) -> Void) = { (call, error) in

                if error == nil {
                    action.fulfill()
                    Task {
                        await self.callKitHelper.addActiveCall(callId: action.callUUID.uuidString,
                                                               call: call!)
                    }
                } else {
                    action.fail()
                }

                outInCallInfo?.completionHandler(call, error)
                Task {
                    await self.callKitHelper.removeOutInCallInfo(transactionId: action.uuid)
                    await self.callKitHelper.removeIncomingCall(callId: action.callUUID.uuidString)
                }
            }

            if let error = configureAudioSession() {
                completionBlock(nil, error)
                return
            }

            let acceptCallOptions = outInCallInfo?.options as? AcceptCallOptions

            if (await callKitHelper.getIncomingCall(callId: action.callUUID.uuidString)) != nil {
                Task {
                    if let incomingCall = await self.callKitHelper.getIncomingCall(callId: action.callUUID.uuidString) {
                        do {
                            var copyAcceptCallOptions: CallOptions = AcceptCallOptions()
                            let outInCallInfo = await callKitHelper.getOutInCallInfo(transactionId: action.uuid)
                            if let copyAcceptCallOptions = outInCallInfo?.options as? AcceptCallOptions {
                                copyAcceptCallOptions.outgoingVideoOptions = copyAcceptCallOptions.outgoingVideoOptions
                            }

                            setMutedAudioOptions(callOptions: &copyAcceptCallOptions)

                            let call = try await incomingCall.accept(options: copyAcceptCallOptions as! AcceptCallOptions)
                            completionBlock(call, nil)
                        } catch {
                            completionBlock(nil, error)
                        }
                    }
                }
                return
            }

            let dispatchSemaphore = await self.callKitHelper.setAndGetSemaphore()
            DispatchQueue.global().async {
                _ = dispatchSemaphore.wait(timeout: DispatchTime(uptimeNanoseconds: 10 * NSEC_PER_SEC))
                Task {
                    if let incomingCall = await self.callKitHelper.getIncomingCall(callId: action.callUUID.uuidString) {
                        do {
                            let call = try await incomingCall.accept(options: acceptCallOptions ?? AcceptCallOptions())
                            completionBlock(call, nil)
                        } catch {
                            completionBlock(nil, error)
                        }
                    } else {
                        completionBlock(nil, CallKitErrors.noIncomingCallFound)
                    }
                }
            }
        }
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        Task {
            if let activeCall = await self.callKitHelper.getActiveCall(callId: action.callUUID.uuidString) {
                let activeCallInfo = await self.callKitHelper.getActiveCallInfo(transactionId: action.uuid.uuidString)
                do {
                    try await activeCall.hangUp(options: nil)
                    activeCallInfo?.completionHandler(nil)
                    action.fulfill()
                    await self.callKitHelper.removeActiveCall(callId: activeCall.id)
                    await self.callKitHelper.removeActiveCallInfo(transactionId: action.uuid.uuidString)
                } catch {
                    action.fail()
                    activeCallInfo?.completionHandler(error)
                }
            } else if let incomingCall = await self.callKitHelper.getIncomingCall(callId: action.callUUID.uuidString) {
                do {
                    try await incomingCall.reject()
                    action.fulfill()
                    await self.callKitHelper.removeIncomingCall(callId: action.callUUID.uuidString)
                } catch {
                    action.fail()
                }
            }
        }
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        Task {
            guard let activeCall = await self.callKitHelper.getActiveCall() else {
                print("No active calls found when activating audio session !!")
                return
            }

            try await startAudio(call: activeCall)
        }
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        Task {
            guard let activeCall = await self.callKitHelper.getActiveCall() else {
                print("No active calls found when deactivating audio session !!")
                return
            }

            try await stopAudio(call: activeCall)
        }
    }

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        Task {
            // This will be raised by CallKit always after raising a transaction
            // Which means an API call will have to happen to reach here
            guard let outInCallInfo = await callKitHelper.getOutInCallInfo(transactionId: action.uuid) else {
                return
            }
            
            let completionBlock : ((Call?, Error?) -> Void) = { (call, error) in
                
                if error == nil {
                    action.fulfill()
                    Task {
                        await self.callKitHelper.addActiveCall(callId: action.callUUID.uuidString,
                                                               call: call!)
                    }
                } else {
                    action.fail()
                }
                outInCallInfo.completionHandler(call, error)
                Task {
                    await self.callKitHelper.removeOutInCallInfo(transactionId: action.uuid)
                }
            }

            guard let callAgent = self.callAgent else {
                completionBlock(nil, CallKitErrors.noCallAgent)
                return
            }

            if let error = configureAudioSession() {
                completionBlock(nil, error)
                return
            }
            
            if let participants = outInCallInfo.participants {
                var copyStartCallOptions: CallOptions = StartCallOptions()
                if let startCallOptions = outInCallInfo.options as? StartCallOptions {
                    copyStartCallOptions.outgoingVideoOptions = startCallOptions.outgoingVideoOptions
                }

                setMutedAudioOptions(callOptions: &copyStartCallOptions)

                do {
                    let call = try await callAgent.startCall(participants: participants,
                                                                  options: (copyStartCallOptions as! StartCallOptions))
                    completionBlock(call, nil)
                } catch {
                    completionBlock(nil, error)
                }
            } else if let meetingLocator = outInCallInfo.meetingLocator {
                var copyJoinCallOptions: CallOptions = JoinCallOptions()
                if let joinCallOptions = outInCallInfo.options as? JoinCallOptions {
                    copyJoinCallOptions.outgoingVideoOptions = joinCallOptions.outgoingVideoOptions
                }

                setMutedAudioOptions(callOptions: &copyJoinCallOptions)

                do {
                    let call = try await callAgent.join(with: meetingLocator,
                                             joinCallOptions: (copyJoinCallOptions as! JoinCallOptions))
                    completionBlock(call, nil)
                } catch {
                    completionBlock(nil, error)
                }
            } else {
                completionBlock(nil, CallKitErrors.unknownOutgoingCallType)
            }
        }
    }
}

class CallKitIncomingCallReporter {
    
    private func createCallUpdate(isVideoEnabled: Bool, localizedCallerName: String, handle: CXHandle) -> CXCallUpdate {
        let callUpdate = CXCallUpdate()
        callUpdate.hasVideo = isVideoEnabled
        callUpdate.supportsHolding = true
        callUpdate.supportsDTMF = true
        callUpdate.supportsGrouping = false
        callUpdate.supportsUngrouping = false
        callUpdate.localizedCallerName = localizedCallerName
        callUpdate.remoteHandle = handle
        return callUpdate
    }

    func reportIncomingCall(callId: String,
                            callerInfo: CallerInfo,
                            videoEnabled: Bool,
                            completionHandler: @escaping (Error?) -> Void)
    {
        reportIncomingCall(callId: callId,
                           caller: callerInfo.identifier,
                           callerDisplayName: callerInfo.displayName,
                           videoEnabled: videoEnabled, completionHandler: completionHandler)
    }

    func reportIncomingCall(callId: String,
                            caller:CommunicationIdentifier,
                            callerDisplayName: String,
                            videoEnabled: Bool,
                            completionHandler: @escaping (Error?) -> Void) {
        let handleType: CXHandle.HandleType = caller is PhoneNumberIdentifier ? .phoneNumber : .generic
        let handle = CXHandle(type: handleType, value: caller.rawId)
        let callUpdate = createCallUpdate(isVideoEnabled: videoEnabled, localizedCallerName: callerDisplayName, handle: handle)
        CallKitObjectManager.getOrCreateCXProvider()?.reportNewIncomingCall(with: UUID(uuidString: callId.uppercased())!, update: callUpdate) { error in
            completionHandler(error)
        }
    }
}

actor CallKitHelper {
    private var callController = CXCallController()
    private var outInCallInfoMap: [String: OutInCallInfo] = [:]
    private var incomingCallMap: [String: IncomingCall] = [:]
    private var incomingCallSemaphore: DispatchSemaphore?
    private var activeCalls: [String : Call] = [:]
    private var updatedCallIdMap: [String:String] = [:]
    private var activeCallInfos: [String: ActiveCallInfo] = [:]

    func getActiveCallInfo(transactionId: String) -> ActiveCallInfo? {
        return activeCallInfos[transactionId.uppercased()]
    }

    func removeActiveCallInfo(transactionId: String) {
        activeCallInfos.removeValue(forKey: transactionId.uppercased())
    }

    private func onIdChanged(newId: String, oldId: String) {
        // For outgoing call we need to report an initial callId to CallKit
        // But that callId wont match with what is set in SDK.
        // So we need to maintain this map between which callId was reported to CallKit
        // and what is new callId in the SDK.
        // For incoming call this wont happen because in the push notification
        // we already get the id of the call.
        if newId != oldId {
            updatedCallIdMap[newId.uppercased()] = oldId.uppercased()
        }
    }

    func setAndGetSemaphore() -> DispatchSemaphore {
        self.incomingCallSemaphore = DispatchSemaphore(value: 0)
        return self.incomingCallSemaphore!
    }
    
    func setIncomingCallSemaphore(semaphore: DispatchSemaphore) {
        self.incomingCallSemaphore = semaphore
    }

    func addIncomingCall(incomingCall: IncomingCall) {
        incomingCallMap[incomingCall.id.uppercased()] = incomingCall
        self.incomingCallSemaphore?.signal()
    }
    
    func removeIncomingCall(callId: String) {
        incomingCallMap.removeValue(forKey: callId.uppercased())
        self.incomingCallSemaphore?.signal()
    }
    
    func getIncomingCall(callId: String) -> IncomingCall? {
        return incomingCallMap[callId.uppercased()]
    }

    func addActiveCall(callId: String, call: Call) {
        onIdChanged(newId: call.id, oldId: callId)
        activeCalls[callId.uppercased()] = call
    }

    func removeActiveCall(callId: String) {
        let finalCallId = getReportedCallIdToCallKit(callId: callId)
        activeCalls.removeValue(forKey: finalCallId)
    }

    func getActiveCall(callId: String) -> Call? {
        let finalCallId = getReportedCallIdToCallKit(callId: callId)
        return activeCalls[finalCallId]
    }

    func getActiveCall() -> Call? {
        // We only allow one active call at a time
        return activeCalls.first?.value
    }

    func removeOutInCallInfo(transactionId: UUID) {
        outInCallInfoMap.removeValue(forKey: transactionId.uuidString.uppercased())
    }

    func getOutInCallInfo(transactionId: UUID) -> OutInCallInfo? {
        return outInCallInfoMap[transactionId.uuidString.uppercased()]
    }

    private func isVideoOn(options: Any?) -> Bool
    {
        guard let optionsUnwrapped = options else {
            return false
        }
        
        var videoOptions: OutgoingVideoOptions?
        if let joinOptions = optionsUnwrapped as? JoinCallOptions {
            videoOptions = joinOptions.outgoingVideoOptions
        } else if let acceptOptions = optionsUnwrapped as? AcceptCallOptions {
            videoOptions = acceptOptions.outgoingVideoOptions
        } else if let startOptions = optionsUnwrapped as? StartCallOptions {
            videoOptions = startOptions.outgoingVideoOptions
        }
        
        guard let videoOptionsUnwrapped = videoOptions else {
            return false
        }
        
        return videoOptionsUnwrapped.streams.count > 0
    }

    private func transactOutInCallWithCallKit(action: CXAction, outInCallInfo: OutInCallInfo) {
        callController.requestTransaction(with: action) { [self] error in
            if error != nil {
                outInCallInfo.completionHandler(nil, error)
            } else {
                outInCallInfoMap[action.uuid.uuidString.uppercased()] = outInCallInfo
            }
        }
    }
    
    private func transactWithCallKit(action: CXAction, activeCallInfo: ActiveCallInfo) {
        callController.requestTransaction(with: action) { error in
            if error != nil {
                activeCallInfo.completionHandler(error)
            } else {
                self.activeCallInfos[action.uuid.uuidString.uppercased()] = activeCallInfo
            }
        }
    }

    private func getReportedCallIdToCallKit(callId: String) -> String {
        var finalCallId : String
        if let newCallId = self.updatedCallIdMap[callId.uppercased()] {
            finalCallId = newCallId
        } else {
            finalCallId = callId.uppercased()
        }
        
        return finalCallId
    }

    func acceptCall(callId: String,
                    options: AcceptCallOptions?,
                    completionHandler: @escaping (Call?, Error?) -> Void) {
        let callId = UUID(uuidString: callId.uppercased())!
        let answerCallAction = CXAnswerCallAction(call: callId)
        let outInCallInfo = OutInCallInfo(participants: nil,
                                          options: options,
                                          completionHandler: completionHandler)
        transactOutInCallWithCallKit(action: answerCallAction, outInCallInfo: outInCallInfo)
    }

    func reportOutgoingCall(call: Call) {
        if call.direction != .outgoing {
            return
        }

        let finalCallId = getReportedCallIdToCallKit(callId: call.id)
        print("Report outgoing call for: \(finalCallId)")
        if call.state == .connected {
            CallKitObjectManager.getOrCreateCXProvider()?.reportOutgoingCall(with: UUID(uuidString: finalCallId)! , connectedAt: nil)
        } else if call.state != .connecting {
            CallKitObjectManager.getOrCreateCXProvider()?.reportOutgoingCall(with: UUID(uuidString: finalCallId)! , startedConnectingAt: nil)
        }
    }

    func endCall(callId: String, completionHandler: @escaping (Error?) -> Void) {
        let finalCallId = getReportedCallIdToCallKit(callId: callId)
        let endCallAction = CXEndCallAction(call: UUID(uuidString: finalCallId)!)
        transactWithCallKit(action: endCallAction, activeCallInfo: ActiveCallInfo(completionHandler: completionHandler))
    }

    func holdCall(callId: String, onHold: Bool, completionHandler: @escaping (Error?) -> Void) {
        let finalCallId = getReportedCallIdToCallKit(callId: callId)
        let setHeldCallAction = CXSetHeldCallAction(call: UUID(uuidString: finalCallId)!, onHold: onHold)
        transactWithCallKit(action: setHeldCallAction, activeCallInfo: ActiveCallInfo(completionHandler: completionHandler))
    }

    func muteCall(callId: String, isMuted: Bool, completionHandler: @escaping (Error?) -> Void) {
        let finalCallId = getReportedCallIdToCallKit(callId: callId)
        let setMutedCallAction = CXSetMutedCallAction(call: UUID(uuidString: finalCallId)!, muted: isMuted)
        transactWithCallKit(action: setMutedCallAction, activeCallInfo: ActiveCallInfo(completionHandler: completionHandler))
    }

    func placeCall(participants: [CommunicationIdentifier]?,
                   callerDisplayName: String,
                   meetingLocator: JoinMeetingLocator?,
                   options: CallOptions?,
                   completionHandler: @escaping (Call?, Error?) -> Void)
    {
        let callId = UUID()
        
        var compressedParticipant: String = ""
        var handleType: CXHandle.HandleType = .generic

        if let participants = participants {
            if participants.count == 1 {
                if participants.first is PhoneNumberIdentifier {
                    handleType = .phoneNumber
                }
                compressedParticipant = participants.first!.rawId
            } else {
                for participant in participants {
                    handleType = participant is PhoneNumberIdentifier ? .phoneNumber : .generic
                    compressedParticipant.append(participant.rawId + ";")
                }
            }
        } else if let meetingLoc = meetingLocator as? GroupCallLocator {
            compressedParticipant = meetingLoc.groupId.uuidString
        }

        #if BETA
        if let meetingLoc = meetingLocator as? TeamsMeetingLinkLocator {
            compressedParticipant = meetingLoc.meetingLink
        } else if let meetingLoc = meetingLocator as? TeamsMeetingCoordinatesLocator {
            compressedParticipant = meetingLoc.threadId
        }
        #endif
        
        guard !compressedParticipant.isEmpty else {
            completionHandler(nil, CallKitErrors.invalidParticipants)
            return
        }

        let handle = CXHandle(type: handleType, value: compressedParticipant)
        let startCallAction = CXStartCallAction(call: callId, handle: handle)
        startCallAction.isVideo = isVideoOn(options: options)
        startCallAction.contactIdentifier = callerDisplayName
        
        transactOutInCallWithCallKit(action: startCallAction,
                                     outInCallInfo: OutInCallInfo(participants: participants,
                                                                  meetingLocator: meetingLocator,
                                                                  options: options, completionHandler: completionHandler))
    }
    
}
