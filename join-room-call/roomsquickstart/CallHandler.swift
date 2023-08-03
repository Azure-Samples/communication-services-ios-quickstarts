//
//  CallHandler.swift
//  roomsquickstart
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT license.

import Foundation
import AzureCommunicationCalling
import AVFoundation

final class CallHandler: NSObject, CallAgentDelegate {
    public var callClient: CallClient?
    public var initialized: Bool = false
    
    private var owner: HomePageView?
    private var lock = NSLock()

    private static var instance: CallHandler?
    static func getOrCreateInstance() -> CallHandler {
        if let c = instance {
            return c
        }
        instance = CallHandler()
        return instance!
    }

    private override init() {}
    
    public func callAgent(_ callAgent: CallAgent, didUpdateCalls args: CallsUpdatedEventArgs) {
        if let removedCall = args.removedCalls.first {
            owner?.callRemoved(removedCall)
        }
    }
    
    public func initialize(token: String, owner: HomePageView) {
        if self.initialized {
            return
        }
        
        self.owner = owner
        
        lock.lock()
        
        var userCredential: CommunicationTokenCredential
        do {
            userCredential = try CommunicationTokenCredential(token: token)
        } catch {
            // error here
            owner.showAlert = true
            owner.alertMessage = "Failed to create CommunicationTokenCredential"
            lock.unlock()
            return
        }
        
        self.callClient = CallClient()
        
        self.callClient!.getDeviceManager { (deviceManager, error) in
            if (error == nil) {
                print("Got device manager instance")
                // This app does not support landscape mode
                // But iOS still generates the device orientation events
                // This is a work-around so that iOS stops generating those events
                // And stop sending it to the SDK.
                UIDevice.current.endGeneratingDeviceOrientationNotifications()
                owner.setDeviceManager(deviceManager: deviceManager!)
            } else {
                owner.showAlert = true
                owner.alertMessage = "Failed to get DeviceManager"
            }
        }
        
        let options = CallAgentOptions()
        
        self.callClient!.createCallAgent(userCredential: userCredential,
                                         options: options,
                                         completionHandler: { (callAgent, error) in
                if error != nil {
                    owner.showAlert = true
                    owner.alertMessage = "Failed to create CallAgent"
                } else {
                    owner.setCallAgent(callAgent: callAgent!, callHandler: self)
                    self.initialized = true
                }
            self.lock.unlock()
        })
    }
}
