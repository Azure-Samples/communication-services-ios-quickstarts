//
//  ContentView.swift
//  iOSVideo
//
// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.
//

import SwiftUI
import AzureCommunication
import AzureCommunicationCalling
import AVFoundation
import Foundation


struct ContentView: View {
    @State var callee: String = ""
    @State var callClient: CallClient?
    @State var callAgent: CallAgent?
    @State var call: Call?
    @State var deviceManager: DeviceManager?
    @State var localVideoStream:[LocalVideoStream]?
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
    
    @State var callObserver:CallObserver?
    @State var remoteParticipantObserver:RemoteParticipantObserver?

    var body: some View {
        NavigationView {
            ZStack{
                Form {
                    Section {
                        TextField("Who would you like to call?", text: $callee)
                        Button(action: startCall) {
                            Text("Start Call")
                        }.disabled(callAgent == nil)
                        Button(action: endCall) {
                            Text("End Call")
                        }.disabled(call == nil)
                        Button(action: toggleLocalVideo) {
                            HStack {
                                Text(sendingVideo ? "Turn Off Video" : "Turn On Video")
                            }
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
                ZStack{
                    VStack{
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
                        }
                        
                    }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    VStack{
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
        }.onAppear{
            let incomingCallHandler = IncomingCallHandler.getOrCreateInstance()
            incomingCallHandler.contentView = self
            var userCredential: CommunicationTokenCredential?
            do {
                userCredential = try CommunicationTokenCredential(token: "<USER_ACCESS_TOKEN>")
            } catch {
                print("ERROR: It was not possible to create user credential.")
                return
            }
            
            AVAudioSession.sharedInstance().requestRecordPermission { (granted) in
                if granted {
                    AVCaptureDevice.requestAccess(for: .video) { (videoGranted) in
                        /* NO OPERATION */
                    }
                }
            }

            self.callClient = CallClient()
            self.callClient?.createCallAgent(userCredential: userCredential!) { (agent, error) in
                if error != nil {
                    print("ERROR: It was not possible to create a call agent.")
                    return
                }

                else {
                    self.callAgent = agent
                    print("Call agent successfully created.")
                    self.callAgent!.delegate = incomingCallHandler
                    self.callClient?.getDeviceManager { (deviceManager, error) in
                        if (error == nil) {
                            print("Got device manager instance")
                            self.deviceManager = deviceManager
                        } else {
                            print("Failed to get device manager instance")
                        }
                    }
                }
            }
        }
    }
    func declineIncomingCall(){
        self.incomingCall!.reject { (error) in }
        isIncomingCall = false
    }
    func showIncomingCallBanner(_ incomingCall: IncomingCall?) {
        isIncomingCall = true
        self.incomingCall = incomingCall
    }
    func answerIncomingCall() {
        isIncomingCall = false
        let options = AcceptCallOptions()
        if (self.incomingCall != nil) {
            guard let deviceManager = deviceManager else {
                return
            }
            
            if (self.localVideoStream == nil) {
                self.localVideoStream = [LocalVideoStream]()
            }
            if(sendingVideo)
            {
                let camera = deviceManager.cameras.first
                localVideoStream!.append(LocalVideoStream(camera: camera!))
                let videoOptions = VideoOptions(localVideoStreams: localVideoStream!)
                options.videoOptions = videoOptions
            }
            self.incomingCall!.accept(options: options) { (call, error) in
                setCallAndObersever(call: call, error: error)
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
    }
    
    func toggleLocalVideo() {
        if (call == nil)
        {
            if(!sendingVideo)
            {
                self.callClient = CallClient()
                self.callClient?.getDeviceManager { (deviceManager, error) in
                    if (error == nil) {
                        print("Got device manager instance")
                        self.deviceManager = deviceManager
                    } else {
                        print("Failed to get device manager instance")
                    }
                }
                guard let deviceManager = deviceManager else {
                    return
                }
                let camera = deviceManager.cameras.first
                let scalingMode = ScalingMode.fit
                if (self.localVideoStream == nil) {
                    self.localVideoStream = [LocalVideoStream]()
                }
                localVideoStream!.append(LocalVideoStream(camera: camera!))
                previewRenderer = try! VideoStreamRenderer(localVideoStream: localVideoStream!.first!)
                previewView = try! previewRenderer!.createView(withOptions: CreateViewOptions(scalingMode:scalingMode))
                self.sendingVideo = true
            }
            else{
                self.sendingVideo = false
                self.previewView = nil
                self.previewRenderer!.dispose()
                self.previewRenderer = nil
            }
        }
        else{
            if (sendingVideo) {
                call!.stopVideo(stream: localVideoStream!.first!) { (error) in
                    if (error != nil) {
                        print("cannot stop video")
                    }
                    else {
                        self.sendingVideo = false
                        self.previewView = nil
                        self.previewRenderer!.dispose()
                        self.previewRenderer = nil
                    }
                }
            }
            else {
                guard let deviceManager = deviceManager else {
                    return
                }
                let camera = deviceManager.cameras.first
                let scalingMode = ScalingMode.fit
                if (self.localVideoStream == nil) {
                    self.localVideoStream = [LocalVideoStream]()
                }
                localVideoStream!.append(LocalVideoStream(camera: camera!))
                previewRenderer = try! VideoStreamRenderer(localVideoStream: localVideoStream!.first!)
                previewView = try! previewRenderer!.createView(withOptions: CreateViewOptions(scalingMode:scalingMode))
                call!.startVideo(stream:(localVideoStream?.first)!) { (error) in
                    if (error != nil) {
                        print("cannot start video")
                    }
                    else {
                        self.sendingVideo = true
                    }
                }
            }
        }
    }

    func startCall() {
        let startCallOptions = StartCallOptions()
        if(sendingVideo)
        {
            if (self.localVideoStream == nil) {
                self.localVideoStream = [LocalVideoStream]()
            }
            let videoOptions = VideoOptions(localVideoStreams: localVideoStream!)
            startCallOptions.videoOptions = videoOptions
        }
        let callees:[CommunicationIdentifier] = [CommunicationUserIdentifier(self.callee)]
        self.callAgent?.startCall(participants: callees, options: startCallOptions) { (call, error) in
            setCallAndObersever(call: call, error: error)
        }
    }
    
    func setCallAndObersever(call:Call!, error:Error?) {
        if (error == nil) {
            self.call = call
            self.callObserver = CallObserver(self)
            self.call!.delegate = self.callObserver
            self.remoteParticipantObserver = RemoteParticipantObserver(self)
        } else {
            print("Failed to get call object")
        }
    }

    func endCall() {
        self.call!.hangUp(options: HangUpOptions()) { (error) in
            if (error != nil) {
                print("ERROR: It was not possible to hangup the call.")
            }
        }
        self.previewRenderer?.dispose()
        self.remoteRenderer?.dispose()
        sendingVideo = false
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
    init(_ view:ContentView) {
            owner = view
    }
        
    public func call(_ call: Call, didChangeState args: PropertyChangedEventArgs) {
        if(call.state == CallState.connected) {
            initialCallParticipant()
        }
    }

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
        data.renderer = try! VideoStreamRenderer(remoteVideoStream: stream)
        let view:RendererView = try! data.renderer!.createView(withOptions: CreateViewOptions(scalingMode:scalingMode))
        self.owner.remoteViews.append(view)
        owner.remoteVideoStreamData[stream.id] = data
    }

    public func remoteParticipant(_ remoteParticipant: RemoteParticipant, didUpdateVideoStreams args: RemoteVideoStreamsEventArgs) {
        for stream in args.addedRemoteVideoStreams {
            renderRemoteStream(stream)
        }
        for stream in args.removedRemoteVideoStreams {
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
        ContentView()
    }
}
