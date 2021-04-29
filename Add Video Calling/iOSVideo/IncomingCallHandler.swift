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

final class IncomingCallHandler: NSObject, CallAgentDelegate, IncomingCallDelegate {
    public var contentView: ContentView?
    private var incomingCall: IncomingCall?

    private static var instance: IncomingCallHandler?
    static func getOrCreateInstance() -> IncomingCallHandler {
        if let c = instance {
            return c
        }
        instance = IncomingCallHandler()
        return instance!
    }

    private override init() {}
    
    public func callAgent(_ callAgent: CallAgent, didRecieveIncomingCall incomingCall: IncomingCall) {
        self.incomingCall = incomingCall
        self.incomingCall?.delegate = self
        contentView?.showIncomingCallBanner(self.incomingCall!)
    }
    
    public func callAgent(_ callAgent: CallAgent, didUpdateCalls args: CallsUpdatedEventArgs) {
        if let removedCall = args.removedCalls.first {
            contentView?.callRemoved(removedCall)
            self.incomingCall = nil
        }
    }
}
