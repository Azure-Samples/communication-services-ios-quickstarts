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

final class IncomingCallHandler: NSObject, IncomingCallDelegate, CallAgentDelegate {
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

    public func onIncomingCall(_ callAgent: CallAgent!, incomingcall: IncomingCall!) {
        self.incomingCall = incomingcall
        self.incomingCall?.delegate = self
        contentView?.incomingCallReceived(self.incomingCall!)
    }

    public func onCallsUpdated(_ callAgent: CallAgent!, args: CallsUpdatedEventArgs!) {
        if let removedCall = args.removedCalls?.first {
            contentView?.callRemoved(removedCall)
            self.incomingCall = nil
        }
    }
}
