//
//  ContentView.swift
//  iOSVideo
//
//  Created by Xu Mo Microsoft on 2/23/21.
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
    @State var localVideoStream: LocalVideoStream?
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
                            Text("Video On/Off")
                        }.disabled(call == nil)
                    }
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
                                Text("Video On/Off")
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
                userCredential = try CommunicationTokenCredential(token: "<USER ACCESS TOKEN>")
            } catch {
                print("ERROR: It was not possible to create user credential.")
                return
            }
            
            AVAudioSession.sharedInstance().requestRecordPermission { (granted) in
                if granted {
                    AVCaptureDevice.requestAccess(for: .video) { (videoGranted) in
                        /* NO OPERATION */ }
                }
            }

            self.callClient = CallClient()
            self.callClient?.createCallAgent(userCredential: userCredential) { (agent, error) in
                if error != nil {
                    print("ERROR: It was not possible to create a call agent.")
                    return
                }

                if let agent = agent {
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
    
    func incomingCallReceived(_ incomingCall: IncomingCall?) {
        self.incomingCall = incomingCall
        if (self.incomingCall != nil) {
            guard let deviceManager = deviceManager else {
                return
            }
            let camera = deviceManager.cameras.first
            localVideoStream = LocalVideoStream(camera: camera)
            let videoOptions = VideoOptions(localVideoStream:localVideoStream!)

            let options = AcceptCallOptions()
            options!.videoOptions = videoOptions
            let scalingMode = ScalingMode.fit
            self.previewRenderer = try! VideoStreamRenderer(localVideoStream: localVideoStream!)
            self.previewView = try! self.previewRenderer?.createView(with: RenderingOptions(scalingMode: scalingMode))
            self.sendingVideo = true
            self.incomingCall!.accept(options: options) { (call, error) in
                if(error == nil)
                {
                    self.call = call
                    self.callObserver = CallObserver(self)
                    self.call?.delegate = self.callObserver
                                
                    self.remoteParticipantObserver = RemoteParticipantObserver(self)
                } else {
                    print("cannot answer incoming call")
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
        self.previewRenderer!.dispose()
        sendingVideo = false
    }
    
    func toggleLocalVideo() {
        if (sendingVideo) {
            call!.stopVideo(stream: localVideoStream!) { (error) in
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
            let camera = deviceManager?.cameras.first
            let scalingMode = ScalingMode.fit
            localVideoStream = LocalVideoStream(camera: camera)
            previewRenderer = try! VideoStreamRenderer(localVideoStream: localVideoStream!)
            previewView = try! previewRenderer!.createView(with: RenderingOptions(scalingMode:scalingMode))
            call!.startVideo(stream:localVideoStream) { (error) in
                if (error != nil) {
                    print("cannot start video")
                }
                else {
                    self.sendingVideo = true
                }
            }
        }
    }

    func startCall() {
        guard let deviceManager = deviceManager else {
            return
        }
        let camera = deviceManager.cameras.first
        self.localVideoStream = LocalVideoStream(camera: camera)
        let videoOptions = VideoOptions(localVideoStream: localVideoStream)
                    
        let scalingMode = ScalingMode.fit
        self.previewRenderer = try! VideoStreamRenderer(localVideoStream: self.localVideoStream!)
        self.previewView = try! self.previewRenderer?.createView(with: RenderingOptions(scalingMode: scalingMode))
        self.sendingVideo = true
        print("Sending video", self.sendingVideo)
                    
        let startCallOptions = StartCallOptions()
        startCallOptions?.videoOptions = videoOptions
  
        let callees:[CommunicationIdentifier] = [CommunicationUserIdentifier(self.callee)]
        self.call = self.callAgent?.startCall(participants: callees, options: startCallOptions)
        
        self.callObserver = CallObserver(self)
        self.call!.delegate = self.callObserver
                    
        self.remoteParticipantObserver = RemoteParticipantObserver(self)
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
    public func rendererFailedToStart() {
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
    public func onFirstFrameRendered() {
        let size:StreamSize = renderer!.size
        owner.remoteVideoSize = String(size.width) + " X " + String(size.height)
    }
}

public class CallObserver: NSObject, CallDelegate, IncomingCallDelegate {
    private var owner: ContentView
    init(_ view:ContentView) {
            owner = view
    }
    
    public func onStateChanged(_ call: Call!, args: PropertyChangedEventArgs!) {
        if(call.state == CallState.connected) {
            initialCallParticipant()
        }
    }
    
    public func onRemoteParticipantsUpdated(_ call: Call!,args: ParticipantsUpdatedEventArgs!) {
        for participant in args.addedParticipants {
            participant.delegate = owner.remoteParticipantObserver
            for stream in participant.videoStreams! {
                if !owner.remoteVideoStreamData.isEmpty {
                    return
                }
                let data:RemoteVideoStreamData = RemoteVideoStreamData(view: owner, stream: stream)
                let scalingMode = ScalingMode.fit
                data.renderer = try! VideoStreamRenderer(remoteVideoStream: stream)
                let view:RendererView = try! data.renderer!.createView(with: RenderingOptions(scalingMode:scalingMode)!)
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
            for stream in participant.videoStreams! {
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
        let view:RendererView = try! data.renderer!.createView(with: RenderingOptions(scalingMode:scalingMode)!)
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
        let view:RendererView = try! data.renderer!.createView(with: RenderingOptions(scalingMode:scalingMode)!)
        self.owner.remoteViews.append(view)
        owner.remoteVideoStreamData[stream.id] = data
    }

    public func onVideoStreamsUpdated(_ remoteParticipant: RemoteParticipant!, args: RemoteVideoStreamsEventArgs!)
    {
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
