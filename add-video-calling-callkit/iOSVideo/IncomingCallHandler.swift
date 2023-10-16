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

    func onIncomingCall(callAgentBase: CallAgent, incomingCallBase: IncomingCall) {
        // If there is no CallKitHelper exit
        guard let callKitHelper =  CallKitObjectManager.getCallKitHelper() else {
            return
        }

        Task {
            await callKitHelper.addIncomingCall(incomingCall: incomingCallBase)
        }
        let incomingCallReporter = CallKitIncomingCallReporter()
        incomingCallReporter.reportIncomingCall(callId: incomingCallBase.id,
                                               callerInfo: incomingCallBase.callerInfo,
                                               videoEnabled: incomingCallBase.isVideoEnabled,
                                               completionHandler: { error in
            if error == nil {
                print("Incoming call was reported successfully")
            } else {
                print("Incoming call was not reported successfully")
            }
        })
    }
    
    func onIncomingCallEnded(incomingCallBase: IncomingCall) {
        contentView?.isIncomingCall = false
        Task {
            await CallKitObjectManager.getCallKitHelper()?.removeIncomingCall(callId: incomingCallBase.id)
        }
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
        onIncomingCall(callAgentBase: callAgent, incomingCallBase: incomingCall)
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
