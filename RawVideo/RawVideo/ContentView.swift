//
//  ContentView.swift
//  RawVideo
//
//  Created by Yassir Amadh Bisteni Aldana on 29/03/23.
//

import AzureCommunicationCalling
import SwiftUI
import AVFoundation

struct ContentView : View
{
    // UI
    @State private var videoDeviceInfoItemList: [VideoDeviceInfoItem] = []
    @State private var cameraItemList: [CameraItem] = []
    @State private var selectedVideoDeviceInfoIndex: Int = -1
    @State private var selectedCameraIndex: Int = -1
    @State private var outgoingVideoStreamType: VideoStreamType = VideoStreamType.virtualOutgoing
    @State private var incomingVideoStreamType: VideoStreamType = VideoStreamType.rawIncoming
    @FocusState private var isFocused: Bool
    
    // App
    @State private var incomingVideoStreamDictionary: [Int32: IncomingVideoStream]?
    @State private var videoDeviceInfoList: [VideoDeviceInfo] = []
    @State private var cameraList: [AVCaptureDevice] = []
    @State private var callClient: CallClient?
    @State private var callAgent: CallAgent?
    @State private var call: Call?
    @State private var deviceManager: DeviceManager?
    @State private var localVideoStreamObserver: LocalVideoStreamObserver?
    @State private var virtualRawOutgoingVideoStreamObserver: VirtualRawOutgoingVideoStreamObserver?
    @State private var screenShareRawOutgoingVideoStreamObserver: ScreenShareRawOutgoingVideoStreamObserver?
    @State private var remoteVideoStreamObserver: RemoteVideoStreamObserver?
    @State private var rawIncomingVideoStreamObserver: RawIncomingVideoStreamObserver?
    @State private var callObserver: CallObserver?
    @State private var remoteParticipantObserver: RemoteParticipantObserver?
    @State private var screenCaptureService: ScreenCaptureService?
    @State private var cameraCaptureService: CameraCaptureService?
    @State private var outgoingVideoStream: OutgoingVideoStream?
    @State private var localVideoStream: LocalVideoStream?
    @State private var virtualOutgoingVideoStream: VirtualOutgoingVideoStream?
    @State private var screenShareOutgoingVideoStream: ScreenShareOutgoingVideoStream?
    @State private var outoingVideoStreamRenderer: VideoStreamRenderer? = nil
    @State private var outgoingVideoStreamRendererView: RendererView? = nil
    @State private var incomingVideoStreamRenderer: VideoStreamRenderer? = nil
    @State private var incomingVideoStreamRendererView: RendererView? = nil
    @State private var outgoingPixelBuffer: CVPixelBuffer?
    @State private var incomingPixelBuffer: CVPixelBuffer?
    @State private var w: Double = 0.0
    @State private var h: Double = 0.0
    @State private var framerate: Float = 30.0
    @State private var maxWidth: Double = 1920.0;
    @State private var maxHeight: Double = 1080.0;
    @State private var token: String = "ACS token"
    @State private var meetingLink: String = "Teams meeting link"
    @State private var callInProgress: Bool = false
    @State private var loading: Bool = false
    
    struct CameraItem : Hashable
    {
        var id: Int
        var name: String
    }
    
    struct VideoDeviceInfoItem : Hashable
    {
        var id: Int
        var name: String
    }
    
    enum OutgoingVideoStreamTypeItem : String, CaseIterable
    {
        case localOutgoing
        case virtualOutgoing
        case screenShareOutgoing
        
        func ToVideoStreamType() -> VideoStreamType
        {
            switch self
            {
            case .localOutgoing:
                return VideoStreamType.localOutgoing
            case .virtualOutgoing:
                return VideoStreamType.virtualOutgoing
            case .screenShareOutgoing:
                return VideoStreamType.screenShareOutgoing
            }
        }
    }
    
    enum IncomingVideoStreamTypeItem : String, CaseIterable
    {
        case remoteIncoming
        case rawIncoming
        
        func ToVideoStreamType() -> VideoStreamType
        {
            switch self
            {
                case .remoteIncoming:
                    return VideoStreamType.remoteIncoming
                case .rawIncoming:
                    return VideoStreamType.rawIncoming
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometryReader in
            ZStack(alignment: .center) {
                if (loading)
                {
                    ProgressView()
                        .zIndex(1)
                }
                
                VStack {
                    if (!callInProgress)
                    {
                        TextEditor(text: $token)
                            .frame(width: 250, height: 30)
                            .padding(10)
                            .overlay(RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.black, lineWidth: 2))
                            .focused($isFocused)
                            .onChange(of: token) { _ in
                                if token.last?.isNewline == .some(true)
                                {
                                    token.removeLast()
                                    isFocused = false
                                }
                            }
                        TextEditor(text: $meetingLink)
                            .frame(width: 250, height: 30)
                            .padding(10)
                            .overlay(RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.black, lineWidth: 2))
                            .focused($isFocused)
                            .onChange(of: meetingLink) { _ in
                                if meetingLink.last?.isNewline == .some(true)
                                {
                                    meetingLink.removeLast()
                                    isFocused = false
                                }
                            }
                        Picker("", selection: $incomingVideoStreamType) {
                            ForEach (IncomingVideoStreamTypeItem.allCases, id: \.self) { videoStreamType in
                                Text(videoStreamType.rawValue).tag(videoStreamType.ToVideoStreamType())
                            }
                        }
                        .accentColor(.black)
                        .frame(width: 250, height: 30)
                        .padding(10)
                        .overlay(RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.black, lineWidth: 2))
                        Picker("", selection: $outgoingVideoStreamType) {
                            ForEach (OutgoingVideoStreamTypeItem.allCases, id: \.self) { videoStreamType in
                                Text(videoStreamType.rawValue).tag(videoStreamType.ToVideoStreamType())
                            }
                        }
                        .accentColor(.black)
                        .frame(width: 250, height: 30)
                        .padding(10)
                        .overlay(RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.black, lineWidth: 2))
                        if (outgoingVideoStreamType == VideoStreamType.localOutgoing)
                        {
                            Picker("", selection: $selectedVideoDeviceInfoIndex) {
                                ForEach (videoDeviceInfoItemList, id: \.self) { videoDeviceInfoItem in
                                    Text(videoDeviceInfoItem.name).tag(videoDeviceInfoItem.id)
                                }
                            }
                            .accentColor(.black)
                            .frame(width: 250, height: 30)
                            .padding(10)
                            .overlay(RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.black, lineWidth: 2))
                        }
                        if (outgoingVideoStreamType == VideoStreamType.virtualOutgoing)
                        {
                            Picker("", selection: $selectedCameraIndex) {
                                ForEach (cameraItemList, id: \.self) { cameraItem in
                                    Text(cameraItem.name).tag(cameraItem.id)
                                }
                            }
                            .accentColor(.black)
                            .frame(width: 250, height: 30)
                            .padding(10)
                            .overlay(RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.black, lineWidth: 2))
                        }
                    }
                    if (callInProgress)
                    {
                        ZStack(alignment: .topLeading) {
                            VStack {
                                if (outgoingVideoStreamType != VideoStreamType.localOutgoing)
                                {
                                    RawVideoFrameView(cvPixelBuffer: $outgoingPixelBuffer)
                                        .overlay(RoundedRectangle(cornerRadius: 5)
                                            .stroke(Color.black, lineWidth: 2))
                                        .background(Color.black)
                                }
                                else
                                {
                                    VideoStreamView(view: $outgoingVideoStreamRendererView)
                                        .overlay(RoundedRectangle(cornerRadius: 5)
                                            .stroke(Color.black, lineWidth: 2))
                                        .background(Color.black)
                                }
                            }
                            .frame(width: 120, height: 67.5)
                            .zIndex(1)
                            .offset(x: 5, y: 5)
                            
                            VStack {
                                if (incomingVideoStreamType != VideoStreamType.remoteIncoming)
                                {
                                    RawVideoFrameView(cvPixelBuffer: $incomingPixelBuffer)
                                }
                                else
                                {
                                    VideoStreamView(view: $incomingVideoStreamRendererView)
                                }
                            }
                            .frame(width: 320, height: 180)
                            .zIndex(0)
                            .overlay(RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.black, lineWidth: 2))
                        }
                        .frame(width: geometryReader.size.width - 30, height: 180)
                    }
                    HStack {
                        Button(action: {
                            Task {
                                await StartCall()
                            }
                        })
                        {
                            HStack {
                                Text("Start Call")
                                    .accentColor(.black)
                            }
                            .frame(width: 120, height: 30)
                            .padding(10)
                            .background(Color(.green))
                            .cornerRadius(5)
                        }
                        Button(action: {
                            Task {
                                await EndCall()
                            }
                        })
                        {
                            HStack {
                                Text("End Call")
                                    .accentColor(.black)
                            }
                            .frame(width: 120, height: 30)
                            .padding(10)
                            .background(Color(.red))
                            .cornerRadius(5)
                        }
                    }
                }
                .frame(width: geometryReader.size.width, height: geometryReader.size.height)
                .onAppear(perform: {
                    Task {
                        await GetPermissions()
                        await InitializeTestCase()
                    }
                })
                .onTapGesture {
                    if (isFocused)
                    {
                        isFocused = false
                    }
                }
                .disabled(loading)
                .zIndex(0)
            }
        }
    }

    struct ContentView_Previews: PreviewProvider 
    {
        static var previews: some View
        {
            ContentView()
        }
    }
    
    private func InitializeTestCase() async -> Void
    {
        incomingVideoStreamDictionary = [Int32: IncomingVideoStream]()
        
        localVideoStreamObserver = LocalVideoStreamObserver(view: self)
        virtualRawOutgoingVideoStreamObserver = VirtualRawOutgoingVideoStreamObserver(view: self)
        screenShareRawOutgoingVideoStreamObserver = ScreenShareRawOutgoingVideoStreamObserver(view: self)
        remoteVideoStreamObserver = RemoteVideoStreamObserver(view: self)
        rawIncomingVideoStreamObserver = RawIncomingVideoStreamObserver(view: self)
        rawIncomingVideoStreamObserver?.delegate = OnRawVideoFrameCaptured
        remoteParticipantObserver = RemoteParticipantObserver(view: self)
        callObserver = CallObserver(view: self, remoteParticipantObserver: remoteParticipantObserver!)
        
        await CreateAgent()
        
        videoDeviceInfoList = deviceManager?.cameras ?? []
        videoDeviceInfoItemList = [VideoDeviceInfoItem]();
        selectedVideoDeviceInfoIndex = videoDeviceInfoList.count > 0 ? 0 : -1;
        
        for i in 0 ..< videoDeviceInfoList.count
        {
            let videoDeviceInfoItem = VideoDeviceInfoItem(id: i, name: videoDeviceInfoList[i].name)
            videoDeviceInfoItemList.append(videoDeviceInfoItem)
        }
        
        cameraList = CameraCaptureService.GetCameraList()
        cameraItemList = [CameraItem]();
        selectedCameraIndex = cameraList.count > 0 ? 0 : -1;
        
        for i in 0 ..< cameraList.count
        {
            let cameraItem = CameraItem(id: i, name: cameraList[i].localizedName)
            cameraItemList.append(cameraItem)
        }
    }
    
    private func GetPermissions() async -> Void
    {
        let cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let microphoneAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        if cameraAuthorizationStatus == .notDetermined
        {
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
                
            })
        }
        
        if microphoneAuthorizationStatus == .notDetermined
        {
            AVCaptureDevice.requestAccess(for: .audio, completionHandler: { (granted: Bool) in
                
            })
        }
    }

    private func CreateAgent() async -> Void
    {
        if (token.isEmpty)
        {
            await ShowMessage(message: "Token is not valid")
            return
        }
        
        do
        {
            let credential = try CommunicationTokenCredential(token: token)
            callClient = CallClient()
            let callAgentOptions = CallAgentOptions()
            callAgentOptions.displayName = "iOS Quickstart User"
            
            callAgent = try await callClient!.createCallAgent(userCredential: credential, options: callAgentOptions)

            deviceManager = try await callClient!.getDeviceManager()
        }
        catch let ex
        {
            let msg = ex.localizedDescription
            print(msg)
        }
    }

    private func StartCall() async -> Void
    {
        if (callInProgress)
        {
            return;
        }
        
        if (!ValidateCallSettings())
        {
            return;
        }

        callInProgress = true;
        
        let incomingVideoOptions = IncomingVideoOptions()
        incomingVideoOptions.streamType = incomingVideoStreamType
        
        let outgoingVideoOptions = CreateOutgoingVideoOptions()
        
        let joinCallOptions = JoinCallOptions()
        joinCallOptions.incomingVideoOptions = incomingVideoOptions
        joinCallOptions.outgoingVideoOptions = outgoingVideoOptions
        
        let locator = TeamsMeetingLinkLocator(meetingLink: meetingLink)

        do
        {
            loading = true
            
            call = try await callAgent!.join(with: locator, joinCallOptions: joinCallOptions)
            
            try await call!.muteOutgoingAudio()
            try await call!.muteIncomingAudio()
            
            loading = false
        }
        catch let ex
        {
            callInProgress = false
            
            loading = false
            await ShowMessage(message: "Failed to start")
            
            let msg = ex.localizedDescription
            print(msg)
        }

        if (call != nil)
        {
            AddRemoteParticipantList(remoteParticipantList: call!.remoteParticipants)
            
            call!.delegate = callObserver!
        }
    }
    
    func AddRemoteParticipantList(remoteParticipantList: [RemoteParticipant]) -> Void
    {
        remoteParticipantList.forEach { remoteParticipant in
            remoteParticipant.incomingVideoStreams.forEach { incomingVideoStream in
                OnIncomingVideoStreamStateChanged(stream: incomingVideoStream)
            }
            
            remoteParticipant.delegate = remoteParticipantObserver
        }
    }

    private func CreateOutgoingVideoOptions() -> OutgoingVideoOptions
    {
        let rawOutgoingVideoStreamOptions = CreateRawOutgoingVideoStreamOptions()
        switch (outgoingVideoStreamType)
        {
            case .localOutgoing:
                let videoDeviceInfo = videoDeviceInfoList[selectedVideoDeviceInfoIndex]
                localVideoStream = LocalVideoStream(camera: videoDeviceInfo)
                localVideoStream!.delegate = localVideoStreamObserver
                outgoingVideoStream = localVideoStream
                
                break
            case .virtualOutgoing:
                virtualOutgoingVideoStream = VirtualOutgoingVideoStream(videoStreamOptions: rawOutgoingVideoStreamOptions)
                virtualOutgoingVideoStream!.delegate = virtualRawOutgoingVideoStreamObserver
                outgoingVideoStream = virtualOutgoingVideoStream
                
                break
            case .screenShareOutgoing:
                screenShareOutgoingVideoStream = ScreenShareOutgoingVideoStream(videoStreamOptions: rawOutgoingVideoStreamOptions)
                screenShareOutgoingVideoStream!.delegate = screenShareRawOutgoingVideoStreamObserver
                outgoingVideoStream = screenShareOutgoingVideoStream
                
                break
            default:
                break
        }

        let outgoingVideoOptions = OutgoingVideoOptions()
        var outgoingVideoStreamList = [OutgoingVideoStream]()
        outgoingVideoStreamList.append(outgoingVideoStream!)
        outgoingVideoOptions.streams = outgoingVideoStreamList
        
        return outgoingVideoOptions
    }

    private func CreateRawOutgoingVideoStreamOptions() -> RawOutgoingVideoStreamOptions
    {
        let format = CreateVideoStreamFormat()

        let options = RawOutgoingVideoStreamOptions()
        options.formats = [format]

        return options
    }

    private func CreateVideoStreamFormat() -> VideoStreamFormat
    {
        let format = VideoStreamFormat()
        format.pixelFormat = VideoStreamPixelFormat.nv12
        format.framesPerSecond = framerate
        
        switch (outgoingVideoStreamType)
        {
            case .virtualOutgoing:
                format.resolution = VideoStreamResolution.vga
                w = Double(format.width)
                h = Double(format.height)
                break;
            case .screenShareOutgoing:
                GetDisplaySize()
                format.width = Int32(w)
                format.height = Int32(h)
                break;
            default:
                break;
        }
        
        format.stride1 = Int32(w)
        format.stride2 = Int32(w)
        
        return format
    }
    
    func OnVideoStreamStateChanged(args: VideoStreamStateChangedEventArgs) -> Void
    {
        let stream = args.stream
        switch (stream.direction)
        {
            case .outgoing:
                OnOutgoingVideoStreamStateChanged(stream: stream as! OutgoingVideoStream)
                break
            case .incoming:
                OnIncomingVideoStreamStateChanged(stream: stream as! IncomingVideoStream)
                break
            default:
                break
        }
    }
    
    private func OnOutgoingVideoStreamStateChanged(stream: OutgoingVideoStream) -> Void
    {
        switch (stream.state)
        {
            case .available:
                if (stream.type == .localOutgoing)
                {
                    StartLocalPreview()
                }
            
                break
            case .started:
                switch (stream.type)
                {
                    case .virtualOutgoing:
                        StartCameraCaptureService()
                        break
                    case .screenShareOutgoing:
                        StartScreenCaptureService()
                        break
                    default:
                        break
                }
            
                break
            case .stopped:
                switch (stream.type)
                {
                    case .localOutgoing:
                        StopLocalPreview();
                    case .virtualOutgoing:
                        StopCameraCaptureService()
                        break
                    case .screenShareOutgoing:
                        StopScreenCaptureService()
                        break
                    default:
                        break
                }
            
                break
            default:
                break
        }
    }
    
    public func OnIncomingVideoStreamStateChanged(stream: IncomingVideoStream) -> Void
    {
        switch (stream.state)
        {
            case .available:
                if (!incomingVideoStreamDictionary!.keys.contains(stream.id))
                {
                    switch (stream.type)
                    {
                        case .remoteIncoming:
                            StartRemotePreview(remoteVideoStream: stream as! RemoteVideoStream)
                            break
                        case .rawIncoming:
                            let rawIncomingVideoStream = stream as! RawIncomingVideoStream
                            rawIncomingVideoStream.delegate = rawIncomingVideoStreamObserver
                            rawIncomingVideoStream.start()

                            break
                        default:
                            break
                    }
                    
                    incomingVideoStreamDictionary![stream.id] = stream
                }

                break
            case .stopped:
                if (incomingVideoStreamDictionary!.keys.contains(stream.id))
                {
                    if (incomingVideoStreamType == .remoteIncoming)
                    {
                        StopRemotePreview()
                    }
                }
            
                break
            case .notAvailable:
                if (incomingVideoStreamDictionary!.keys.contains(stream.id))
                {
                    if (incomingVideoStreamType == .rawIncoming)
                    {
                        let rawIncomingVideoStream = incomingVideoStreamDictionary![stream.id] as! RawIncomingVideoStream
                        rawIncomingVideoStream.delegate = nil
                    }
                    
                    incomingVideoStreamDictionary!.removeValue(forKey: stream.id)
                }

                break
            default:
                break
        }
    }
    
    func OnRawVideoFrameCaptured(rawVideoFrameBuffer: RawVideoFrameBuffer, direction: StreamDirection) -> Void
    {
        switch (direction)
        {
            case .outgoing:
                outgoingPixelBuffer = rawVideoFrameBuffer.buffer
                break
            case .incoming:
                incomingPixelBuffer = rawVideoFrameBuffer.buffer
                break
            default:
                break
        }
    }
    
    private func StartRemotePreview(remoteVideoStream: RemoteVideoStream) -> Void
    {
        if (incomingVideoStreamRendererView == nil)
        {
            incomingVideoStreamRenderer = try! VideoStreamRenderer(remoteVideoStream: remoteVideoStream)
            let options = CreateViewOptions.init(scalingMode: ScalingMode.fit)
            incomingVideoStreamRendererView = try! incomingVideoStreamRenderer?.createView(withOptions: options)
        }
    }
    
    private func StopRemotePreview() -> Void
    {
        if (incomingVideoStreamRendererView != nil)
        {
            incomingVideoStreamRendererView?.dispose()
            incomingVideoStreamRendererView = nil
            
            incomingVideoStreamRenderer?.dispose()
            incomingVideoStreamRenderer = nil
        }
    }
    
    private func StartLocalPreview() -> Void
    {
        if (outgoingVideoStreamRendererView == nil)
        {
            outoingVideoStreamRenderer = try! VideoStreamRenderer(localVideoStream: localVideoStream!)
            let options = CreateViewOptions.init(scalingMode: ScalingMode.fit)
            outgoingVideoStreamRendererView = try! outoingVideoStreamRenderer?.createView(withOptions: options)
        }
    }
    
    private func StopLocalPreview() -> Void
    {
        if (outgoingVideoStreamRendererView != nil)
        {
            outgoingVideoStreamRendererView?.dispose()
            outgoingVideoStreamRendererView = nil
            
            outoingVideoStreamRenderer?.dispose()
            outoingVideoStreamRenderer = nil
        }
    }
    
    private func StartCameraCaptureService() -> Void
    {
        if (cameraCaptureService == nil)
        {
            cameraCaptureService = CameraCaptureService(rawOutgoingVideoStream: virtualOutgoingVideoStream!)
            cameraCaptureService?.Start(camera: cameraList[selectedCameraIndex])
            cameraCaptureService?.delegate = OnRawVideoFrameCaptured
        }
    }
    
    private func StopCameraCaptureService() -> Void
    {
        if (cameraCaptureService != nil)
        {
            cameraCaptureService?.delegate = nil
            cameraCaptureService?.Stop()
            cameraCaptureService = nil
        }
    }
    
    private func StartScreenCaptureService() -> Void
    {
        if (screenCaptureService == nil)
        {
            screenCaptureService = ScreenCaptureService(rawOutgoingVideoStream: screenShareOutgoingVideoStream!)
            screenCaptureService?.Start()
            screenCaptureService?.delegate = OnRawVideoFrameCaptured
        }
    }
    
    private func StopScreenCaptureService() -> Void
    {
        if (screenCaptureService != nil)
        {
            screenCaptureService?.delegate = nil
            screenCaptureService?.Stop()
            screenCaptureService = nil
        }
    }
    
    private func EndCall() async -> Void
    {
        if (!callInProgress)
        {
            return
        }

        do
        {
            loading = true
            
            if (call != nil)
            {
                call!.delegate = nil
                
                StopCameraCaptureService()
                StopScreenCaptureService()
                
                localVideoStream = nil
                virtualOutgoingVideoStream = nil
                screenShareOutgoingVideoStream = nil

                if (outgoingVideoStream != nil)
                {
                    try await call!.stopVideo(stream: outgoingVideoStream!)
                    outgoingVideoStream = nil
                }

                try await call!.hangUp(options: HangUpOptions())
                call = nil
            }

            callInProgress = false
            incomingVideoStreamDictionary!.removeAll()
            
            loading = false
        }
        catch let ex
        {
            loading = false
            await ShowMessage(message: "Failed to stopped")
            
            let msg = ex.localizedDescription
            print(msg)
        }
    }
    
    private func GetDisplaySize() -> Void
    {
        let screenSize = UIScreen.main.bounds
        w = screenSize.width
        h = screenSize.height
        
        if (h > maxHeight)
        {
            var percentage = abs((maxHeight / h) - 1);
            w = ceil((w * percentage));
            h = maxHeight;
        }

        if (w > maxWidth)
        {
            var percentage = abs((maxWidth / w) - 1);
            h = ceil((h * percentage));
            w = maxWidth;
        }
    }
    
    private func ValidateCallSettings() -> Bool
    {
        var isValid = true;
        switch (outgoingVideoStreamType)
        {
            case .localOutgoing:
                isValid = selectedVideoDeviceInfoIndex != -1
                break
            case .virtualOutgoing:
                isValid = selectedCameraIndex != -1
                break
            default:
                break
        }

        return isValid;
    }
    
    private func ShowMessage(message: String) async -> Void
    {
        let alert = await UIAlertController(title: "Call", message: message, preferredStyle: .alert)
        let cancelAction = await UIAlertAction(title: "Ok", style: .cancel, handler: nil)
        await alert.addAction(cancelAction)
        let window = await UIApplication.shared.keyWindow
        await window?.rootViewController?.present(alert, animated: true)
    }
}

class LocalVideoStreamObserver: NSObject, LocalVideoStreamDelegate
{
    private var view: ContentView

    init(view: ContentView)
    {
        self.view = view
    }
    
    func localVideoStream(_ localVideoStream: LocalVideoStream, didChangeState args: VideoStreamStateChangedEventArgs)
    {
        view.OnVideoStreamStateChanged(args: args)
    }
}

class VirtualRawOutgoingVideoStreamObserver: NSObject, VirtualOutgoingVideoStreamDelegate
{
    private var view: ContentView

    init(view: ContentView)
    {
        self.view = view
    }
    
    func virtualOutgoingVideoStream(_ virtualOutgoingVideoStream: VirtualOutgoingVideoStream, didChangeState args: VideoStreamStateChangedEventArgs) 
    {
        view.OnVideoStreamStateChanged(args: args)
    }
}

class ScreenShareRawOutgoingVideoStreamObserver: NSObject, ScreenShareOutgoingVideoStreamDelegate
{
    private var view: ContentView

    init(view: ContentView)
    {
        self.view = view
    }
    
    func screenShareOutgoingVideoStream(_ screenShareOutgoingVideoStream: ScreenShareOutgoingVideoStream, didChangeState args: VideoStreamStateChangedEventArgs)
    {
        view.OnVideoStreamStateChanged(args: args)
    }
}

class RemoteVideoStreamObserver: NSObject, RemoteVideoStreamDelegate
{
    private var view: ContentView

    init(view: ContentView)
    {
        self.view = view
    }
    
    func remoteVideoStream(_ remoteVideoStream: RemoteVideoStream, didChangeState args: VideoStreamStateChangedEventArgs)
    {
        view.OnVideoStreamStateChanged(args: args)
    }
}

class RawIncomingVideoStreamObserver: NSObject, RawIncomingVideoStreamDelegate
{
    private var view: ContentView
    var delegate: ((RawVideoFrameBuffer, StreamDirection) -> Void)?

    init(view: ContentView)
    {
        self.view = view
    }
    
    func rawIncomingVideoStream(_ rawIncomingVideoStream: RawIncomingVideoStream, didChangeState args: VideoStreamStateChangedEventArgs)
    {
        view.OnVideoStreamStateChanged(args: args)
    }
    
    func rawIncomingVideoStream(_ rawIncomingVideoStream: RawIncomingVideoStream, didReceiveRawVideoFrame args: RawVideoFrameReceivedEventArgs)
    {
        let rawVideoFrameBuffer = args.frame as! RawVideoFrameBuffer
        
        delegate!(rawVideoFrameBuffer, .incoming)
    }
}

class CallObserver: NSObject, CallDelegate
{
    private var view: ContentView
    private var remoteParticipantObserver: RemoteParticipantObserver

    init(view: ContentView, remoteParticipantObserver: RemoteParticipantObserver)
    {
        self.view = view
        self.remoteParticipantObserver = remoteParticipantObserver
    }
    
    func call(_ call: Call, didUpdateRemoteParticipant args: ParticipantsUpdatedEventArgs)
    {
        view.AddRemoteParticipantList(remoteParticipantList: args.addedParticipants)
            
        args.removedParticipants.forEach { remoteParticipant in
            remoteParticipant.delegate = nil
        }
    }
}

class RemoteParticipantObserver: NSObject, RemoteParticipantDelegate
{
    private var view: ContentView

    init(view: ContentView)
    {
        self.view = view
    }
    
    func remoteParticipant(_ remoteParticipant: RemoteParticipant, didChangeVideoStreamState args: VideoStreamStateChangedEventArgs) 
    {
        view.OnVideoStreamStateChanged(args: args)
    }
}
