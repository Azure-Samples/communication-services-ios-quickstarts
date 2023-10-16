//
//  CallHandler.swift
//  iOSVideo
//
//  Created by Sanath Rao on 6/28/23.
//

import Foundation
import AzureCommunicationCalling

public class CallHandlerBase: NSObject {
    private var owner: ContentView
    private var callKitHelper: CallKitHelper?

    init(_ view: ContentView) {
        owner = view
    }
    
    #if BETA
    public func onStateChanged(call: CallBase, args: PropertyChangedEventArgs) {
        switch call.state {
        case .connected:
            owner.callState = "Connected"
            break
        case .connecting:
            owner.callState = "Connecting"
            break
        case .disconnected:
            owner.callState = "Disconnected"
            break
        case .disconnecting:
            owner.callState = "Disconnecting"
            break
        case .inLobby:
            owner.callState = "InLobby"
            break
        case .localHold:
            owner.callState = "LocalHold"
            break
        case .remoteHold:
            owner.callState = "RemoteHold"
            break
        case .ringing:
            owner.callState = "Ringing"
            break
        case .earlyMedia:
            owner.callState = "EarlyMedia"
            break
        case .none:
            owner.callState = "None"
            break
        default:
            owner.callState = "Default"
            break
        }

        if(call.state == CallState.connected) {
            initialCallParticipant()
        }
    }

    public func onRemoteParticipantUpdated(call: CallBase, args: ParticipantsUpdatedEventArgs) {
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
                data.rendererView = view
                owner.remoteVideoStreamData.append(data)
            }
            owner.remoteParticipant = participant
        }
    }
    
    public func onOutgoingAudioStateChanged(call: CallBase) {
        owner.isMuted = call.isOutgoingAudioMuted
    }

    private func renderRemoteStream(_ stream: RemoteVideoStream!) {
        if !owner.remoteVideoStreamData.isEmpty {
            return
        }
        let data:RemoteVideoStreamData = RemoteVideoStreamData(view: owner, stream: stream)
        let scalingMode = ScalingMode.fit
        data.renderer = try! VideoStreamRenderer(remoteVideoStream: stream)
        let view:RendererView = try! data.renderer!.createView(withOptions: CreateViewOptions(scalingMode:scalingMode))
        data.rendererView = view
        owner.remoteVideoStreamData.append(data)
    }

    private func initialCallParticipant() {
        var callBase: CallBase?
        if let call = owner.call {
            callBase = owner.call
        } else if let call = owner.teamsCall {
            callBase = owner.teamsCall
        }
        
        for participant in callBase!.remoteParticipants {
            participant.delegate = owner.remoteParticipantObserver
            for stream in participant.videoStreams {
                renderRemoteStream(stream)
            }
            owner.remoteParticipant = participant
        }
    }
    #else
    public func onStateChanged(call: Call, args: PropertyChangedEventArgs) {
        switch call.state {
        case .connected:
            owner.callState = "Connected"
            break
        case .connecting:
            owner.callState = "Connecting"
            break
        case .disconnected:
            owner.callState = "Disconnected"
            break
        case .disconnecting:
            owner.callState = "Disconnecting"
            break
        case .inLobby:
            owner.callState = "InLobby"
            break
        case .localHold:
            owner.callState = "LocalHold"
            break
        case .remoteHold:
            owner.callState = "RemoteHold"
            break
        case .ringing:
            owner.callState = "Ringing"
            break
        case .earlyMedia:
            owner.callState = "EarlyMedia"
            break
        case .none:
            owner.callState = "None"
            break
        default:
            owner.callState = "Default"
            break
        }

        if(call.state == CallState.connected) {
            initialCallParticipant()
        }
    }

    public func onRemoteParticipantUpdated(call: Call, args: ParticipantsUpdatedEventArgs) {
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
                data.rendererView = view
                owner.remoteVideoStreamData.append(data)
            }
            owner.remoteParticipant = participant
        }
    }
    
    public func onOutgoingAudioStateChanged(call: Call) {
        owner.isMuted = call.isOutgoingAudioMuted
    }

    private func renderRemoteStream(_ stream: RemoteVideoStream!) {
        if !owner.remoteVideoStreamData.isEmpty {
            return
        }
        let data:RemoteVideoStreamData = RemoteVideoStreamData(view: owner, stream: stream)
        let scalingMode = ScalingMode.fit
        data.renderer = try! VideoStreamRenderer(remoteVideoStream: stream)
        let view:RendererView = try! data.renderer!.createView(withOptions: CreateViewOptions(scalingMode:scalingMode))
        data.rendererView = view
        owner.remoteVideoStreamData.append(data)
    }

    private func initialCallParticipant() {
        for participant in owner.call!.remoteParticipants {
            participant.delegate = owner.remoteParticipantObserver
            for stream in participant.videoStreams {
                renderRemoteStream(stream)
            }
            owner.remoteParticipant = participant
        }
    }
    #endif
    
}

public final class CallHandler: CallHandlerBase, CallDelegate, IncomingCallDelegate {
    
    override init(_ view:ContentView) {
        super.init(view)
    }

    public func call(_ call: Call, didChangeState args: PropertyChangedEventArgs) {
        onStateChanged(call: call, args: args)
    }
    
    public func call(_ call: Call, didUpdateOutgoingAudioState args: PropertyChangedEventArgs) {
        onOutgoingAudioStateChanged(call: call)
    }

    public func call(_ call: Call, didUpdateRemoteParticipant args: ParticipantsUpdatedEventArgs) {
        onRemoteParticipantUpdated(call: call, args: args)
    }
    
    public func call(_ call: Call, didChangeId args: PropertyChangedEventArgs) {
        print("ACSCall New CallId: \(call.id)")
    }
}

#if BETA
public final class TeamsCallHandler: CallHandlerBase, TeamsCallDelegate, TeamsIncomingCallDelegate {
    
    override init(_ view:ContentView) {
        super.init(view)
    }
    
    public func teamsCall(_ teamsCall: TeamsCall, didChangeState args: PropertyChangedEventArgs) {
        onStateChanged(call: teamsCall, args: args)
    }
    
    public func teamsCall(_ teamsCall: TeamsCall, didUpdateOutgoingAudioState args: PropertyChangedEventArgs) {
        onOutgoingAudioStateChanged(call: teamsCall)
    }
    
    public func teamsCall(_ teamsCall: TeamsCall, didUpdateRemoteParticipant args: ParticipantsUpdatedEventArgs) {
        onRemoteParticipantUpdated(call: teamsCall, args: args)
    }
    
    public func teamsCall(_ teamsCall: TeamsCall, didChangeId args: PropertyChangedEventArgs) {
        print("TeamsCall New CallId: \(teamsCall.id)")
    }
}
#endif
