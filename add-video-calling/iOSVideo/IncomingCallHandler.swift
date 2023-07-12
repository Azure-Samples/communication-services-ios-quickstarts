//
//  IncomingCallHandler.swift
//  iOSVideo
//
// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.
//
import Foundation
import AzureCommunicationCalling
import AVFoundation


class IncomingCallHandlerBase : NSObject {
    public var contentView: ContentView?
    
    init(contentView: ContentView?) {
        self.contentView = contentView
    }
    
    func onIncomingCallEnded(incomingCallBase: IncomingCallBase) {
        contentView?.isIncomingCall = false
    }
    
}

final class IncomingCallHandler: IncomingCallHandlerBase, CallAgentDelegate, IncomingCallDelegate {
    private var incomingCall: IncomingCall?


    override init(contentView: ContentView?) {
        super.init(contentView: contentView)
    }

    public func callAgent(_ callAgent: CallAgent, didRecieveIncomingCall incomingCall: IncomingCall) {
        self.incomingCall = incomingCall
        self.incomingCall!.delegate = self
        contentView?.showIncomingCallBanner(self.incomingCall!)
    }

    func incomingCall(_ incomingCall: IncomingCall, didEnd args: PropertyChangedEventArgs) {
        self.incomingCall = nil
        onIncomingCallEnded(incomingCallBase: incomingCall)
    }
    
    func callAgent(_ callAgent: CallAgent, didUpdateCalls args: CallsUpdatedEventArgs) {
        if let removedCall = args.removedCalls.first {
            contentView?.callRemoved(removedCall)
            self.incomingCall = nil
        }

        if let addedCall = args.addedCalls.first {
            // This happens when call was accepted via CallKit and not from the app
            // We need to set the call instances and auto-navigate to call in progress screen.
            if addedCall.direction == .incoming {
                contentView?.isIncomingCall = false
                contentView?.setCallAndObersever(call: addedCall, error: nil)
            }
        }
    }
}

final class TeamsIncomingCallHandler: IncomingCallHandlerBase, TeamsCallAgentDelegate, TeamsIncomingCallDelegate {
    private var teamsIncomingCall: TeamsIncomingCall?


    override init(contentView: ContentView?) {
        super.init(contentView: contentView)
    }

    func teamsCallAgent(_ teamsCallAgent: TeamsCallAgent, didRecieveIncomingCall incomingCall: TeamsIncomingCall) {
        self.teamsIncomingCall = incomingCall
        self.teamsIncomingCall!.delegate = self
        contentView?.showIncomingCallBanner(self.teamsIncomingCall!)
    }

    func teamsIncomingCall(_ teamsIncomingCall: TeamsIncomingCall, didEnd args: PropertyChangedEventArgs) {
        self.teamsIncomingCall = nil
        onIncomingCallEnded(incomingCallBase: teamsIncomingCall)
    }
    
    func teamsCallAgent(_ teamsCallAgent: TeamsCallAgent, didUpdateCalls args: TeamsCallsUpdatedEventArgs) {
        if let removedCall = args.removedCalls.first {
            contentView?.callRemoved(removedCall)
            self.teamsIncomingCall = nil
        }

        if let addedCall = args.addedCalls.first {
            // This happens when call was accepted via CallKit and not from the app
            // We need to set the call instances and auto-navigate to call in progress screen.
            if addedCall.direction == .incoming {
                contentView?.isIncomingCall = false
                contentView?.setTeamsCallAndObserver(teamsCall: addedCall, error: nil)
            }
        }
    }
    
}
