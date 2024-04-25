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
    @State private var videoFormatItemList: [VideoFormatItem] = []
    @State private var videoDeviceInfoListIndex: Int = -1
    @State private var cameraListIndex: Int = -1
    @State private var videoFormatListIndex: Int = -1
    @State private var outgoingVideoStreamType: VideoStreamType = VideoStreamType.virtualOutgoing
    @State private var incomingVideoStreamType: VideoStreamType = VideoStreamType.rawIncoming
    @FocusState private var isFocused: Bool
    
    // App
    @State private var videoDeviceInfoList: [VideoDeviceInfo] = []
    @State private var cameraList: [AVCaptureDevice] = []
    @State private var videoFormatList: [VideoFormatBundle] = []
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
    @State private var cameraCaptureService: CameraCaptureService?
    @State private var screenCaptureService: ScreenCaptureService?
    @State private var videoFrameGeneratorService: VideoFrameGeneratorService?
    @State private var incomingVideoStream: IncomingVideoStream?
    @State private var remoteVideoStream: RemoteVideoStream?
    @State private var rawIncomingVideoStream: RawIncomingVideoStream?
    @State private var outgoingVideoStream: OutgoingVideoStream?
    @State private var localVideoStream: LocalVideoStream?
    @State private var virtualOutgoingVideoStream: VirtualOutgoingVideoStream?
    @State private var screenShareOutgoingVideoStream: ScreenShareOutgoingVideoStream?
    @State private var outoingVideoStreamRenderer: VideoStreamRenderer?
    @State private var outgoingVideoStreamRendererView: RendererView?
    @State private var incomingVideoStreamRenderer: VideoStreamRenderer?
    @State private var incomingVideoStreamRendererView: RendererView?
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
    @State private var showCallSettings: Bool = false
    @State private var loading: Bool = false
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    
    struct VideoDeviceInfoItem : Hashable
    {
        var id: Int
        var name: String
    }
    
    struct CameraItem : Hashable
    {
        var id: Int
        var name: String
    }
    
    struct VideoFormatItem : Hashable
    {
        var id: Int
        var resolution: String
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
                if loading
                {
                    ProgressView()
                        .zIndex(1)
                }
                
                VStack {
                    if !showCallSettings
                    {
                        VStack {
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
                            Button(action: {
                                Task {
                                    await GetPermissions()
                                }
                            })
                            {
                                HStack {
                                    Text("Init Resources")
                                        .accentColor(.white)
                                }
                                .frame(width: 120, height: 30)
                                .padding(10)
                                .background(Color(.blue))
                                .cornerRadius(5)
                            }
                        }
                    }
                    else
                    {
                        if !callInProgress
                        {
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
                                Picker("", selection: $videoDeviceInfoListIndex) {
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
                                Picker("", selection: $cameraListIndex) {
                                    ForEach (cameraItemList, id: \.self) { cameraItem in
                                        Text(cameraItem.name).tag(cameraItem.id)
                                    }
                                }
                                .onChange(of: cameraListIndex) { _ in
                                    didSelectedVideoFormat()
                                }
                                .accentColor(.black)
                                .frame(width: 250, height: 30)
                                .padding(10)
                                .overlay(RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.black, lineWidth: 2))
                                
                                Picker("", selection: $videoFormatListIndex) {
                                    ForEach (videoFormatItemList, id: \.self) { videoFormatItem in
                                        Text(videoFormatItem.resolution).tag(videoFormatItem.id)
                                    }
                                }
                                .accentColor(.black)
                                .frame(width: 250, height: 30)
                                .padding(10)
                                .overlay(RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.black, lineWidth: 2))
                            }
                        }
                        else
                        {
                            VStack {
                                if (outgoingVideoStream != nil)
                                {
                                    if (outgoingVideoStreamType != VideoStreamType.localOutgoing)
                                    {
                                        RawVideoFrameView(cvPixelBuffer: $outgoingPixelBuffer)
                                            .background(Color.black)
                                    }
                                    else
                                    {
                                        VideoStreamView(view: $outgoingVideoStreamRendererView)
                                            .background(Color.black)
                                    }
                                }
                            }
                            .frame(width: 320, height: 180)
                            .overlay(RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.black, lineWidth: 2))

                            VStack {
                                if (incomingVideoStream != nil)
                                {
                                    if (incomingVideoStreamType != VideoStreamType.remoteIncoming)
                                    {
                                        RawVideoFrameView(cvPixelBuffer: $incomingPixelBuffer)
                                            .background(Color.black)
                                    }
                                    else
                                    {
                                        VideoStreamView(view: $incomingVideoStreamRendererView)
                                            .background(Color.black)
                                    }
                                }
                            }
                            .frame(width: 320, height: 180)
                            .overlay(RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.black, lineWidth: 2))
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
                }
                .frame(width: geometryReader.size.width, height: geometryReader.size.height)
                .onAppear(perform: {
                    let defaults = UserDefaults.standard
                    if let savedToken = defaults.value(forKey: "Token") as? String
                    {
                        token = savedToken
                    }
                })
                .disabled(loading)
                .zIndex(0)
            }
            .onTapGesture {
                if isFocused
                {
                    isFocused = false
                }
            }
            .alert(isPresented: $showAlert) { () -> Alert in
                Alert(title: Text("ACS"), 
                      message: Text(alertMessage),
                      dismissButton: .default(Text("Ok"),
                      action: { alertMessage = "" }))
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
    
    private func InitResources() async -> Void
    {
        localVideoStreamObserver = LocalVideoStreamObserver(view: self)
        virtualRawOutgoingVideoStreamObserver = VirtualRawOutgoingVideoStreamObserver(view: self)
        screenShareRawOutgoingVideoStreamObserver = ScreenShareRawOutgoingVideoStreamObserver(view: self)
        remoteVideoStreamObserver = RemoteVideoStreamObserver(view: self)
        rawIncomingVideoStreamObserver = RawIncomingVideoStreamObserver(view: self)
        rawIncomingVideoStreamObserver?.delegate = OnRawVideoFrameArrived
        remoteParticipantObserver = RemoteParticipantObserver(view: self)
        callObserver = CallObserver(view: self, remoteParticipantObserver: remoteParticipantObserver!)
        
        await CreateCallAgent()
        
        guard let deviceManager = deviceManager else
        {
            return
        }
        
        videoDeviceInfoList = deviceManager.cameras
        videoDeviceInfoItemList = [VideoDeviceInfoItem]();
        videoDeviceInfoListIndex = videoDeviceInfoList.count > 0 ? 0 : -1;
        
        for i in 0 ..< videoDeviceInfoList.count
        {
            let videoDeviceInfoItem = VideoDeviceInfoItem(id: i, name: videoDeviceInfoList[i].name)
            videoDeviceInfoItemList.append(videoDeviceInfoItem)
        }
        
        cameraList = CameraCaptureService.GetCameraList()
        cameraItemList = [CameraItem]();
        cameraListIndex = cameraList.count > 0 ? 0 : -1;
        
        for i in 0 ..< cameraList.count
        {
            let cameraItem = CameraItem(id: i, name: cameraList[i].localizedName)
            cameraItemList.append(cameraItem)
        }
        
        didSelectedVideoFormat()
        
        showCallSettings = true
        
        let defaults = UserDefaults.standard
        if let savedMeetingLink = defaults.value(forKey: "MeetingLink") as? String
        {
            meetingLink = savedMeetingLink
        }
    }
    
    private func GetPermissions() async -> Void
    {
        if token.isEmpty || token == "ACS token"
        {
            showAlert = true
            alertMessage = "Invalid token"
            return
        }
        
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
        
        await InitResources()
    }

    private func CreateCallAgent() async -> Void
    {
        do
        {
            let credential = try CommunicationTokenCredential(token: token)
            callClient = CallClient()
            let callAgentOptions = CallAgentOptions()
            callAgentOptions.displayName = "iOS Quickstart User"
            
            callAgent = try await callClient?.createCallAgent(userCredential: credential, 
                                                              options: callAgentOptions)

            deviceManager = try await callClient?.getDeviceManager()
            
            let defaults = UserDefaults.standard
            defaults.set(token, forKey: "Token")
        }
        catch
        {
            showAlert = true
            alertMessage = "Failed to create call agent"
            print(error.localizedDescription)
        }
    }

    private func StartCall() async -> Void
    {
        if callInProgress
        {
            return;
        }
        
        if !(await ValidateCallSettings())
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
        
        loading = true
        do
        {
            call = try await callAgent?.join(with: locator, joinCallOptions: joinCallOptions)
            
            try await call?.muteOutgoingAudio()
            try await call?.muteIncomingAudio()
            
            let defaults = UserDefaults.standard
            defaults.set(meetingLink, forKey: "MeetingLink")
        }
        catch
        {
            callInProgress = false
            
            showAlert = true
            alertMessage = "Failed to start"
            print(error.localizedDescription)
        }
        
        loading = false
        
        guard let call = call else
        {
            return
        }
        
        call.delegate = callObserver!
        
        AddRemoteParticipantList(remoteParticipantList: call.remoteParticipants)
    }
    
    func AddRemoteParticipantList(remoteParticipantList: [RemoteParticipant]) -> Void
    {
        remoteParticipantList.forEach { remoteParticipant in
            remoteParticipant.delegate = remoteParticipantObserver
            remoteParticipant.incomingVideoStreams.forEach { incomingVideoStream in
                OnIncomingVideoStreamStateChanged(stream: incomingVideoStream)
            }
        }
    }

    private func CreateOutgoingVideoOptions() -> OutgoingVideoOptions
    {
        let rawOutgoingVideoStreamOptions = CreateRawOutgoingVideoStreamOptions()
        switch (outgoingVideoStreamType)
        {
            case .localOutgoing:
                let videoDeviceInfo = videoDeviceInfoList[videoDeviceInfoListIndex]
                localVideoStream = LocalVideoStream(camera: videoDeviceInfo)
                localVideoStream!.delegate = localVideoStreamObserver
                outgoingVideoStream = localVideoStream
                
                break
            case .virtualOutgoing:
                virtualOutgoingVideoStream = VirtualOutgoingVideoStream(
                    videoStreamOptions: rawOutgoingVideoStreamOptions)
                virtualOutgoingVideoStream!.delegate = virtualRawOutgoingVideoStreamObserver
                outgoingVideoStream = virtualOutgoingVideoStream
                
                break
            case .screenShareOutgoing:
                screenShareOutgoingVideoStream = ScreenShareOutgoingVideoStream(
                    videoStreamOptions: rawOutgoingVideoStreamOptions)
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
                let size = videoFormatList[videoFormatListIndex].size
                w = size.width
                h = size.height
                break;
            case .screenShareOutgoing:
                GetDisplaySize()
                break;
            default:
                break;
        }
        
        format.width = Int32(w)
        format.height = Int32(h)
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
        switch stream.state
        {
            case .available:
                if stream.type == .localOutgoing
                {
                    StartLocalPreview()
                }
            
                break
            case .started:
                switch stream.type
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
                switch stream.type
                {
                    case .localOutgoing:
                        StopLocalPreview()
                        break
                    case .virtualOutgoing:
                        StopCameraCaptureService()
                        break
                    case .screenShareOutgoing:
                        StopScreenCaptureService()
                        break
                    default:
                        break
                }
            
                outgoingVideoStream = nil
                break
            default:
                break
        }
    }
    
    public func OnIncomingVideoStreamStateChanged(stream: IncomingVideoStream) -> Void
    {
        if incomingVideoStream != nil && incomingVideoStream != stream
        {
            if stream.state == .available
            {
                Task
                {
                    showAlert = true
                    alertMessage = "This app only support 1 incoming video stream from 1 remote participant"
                }
            }
            
            return
        }
        
        switch stream.state
        {
            case .available:
                switch stream.type
                {
                    case .remoteIncoming:
                        remoteVideoStream = stream as? RemoteVideoStream
                        StartRemotePreview()
                        
                        break
                    case .rawIncoming:
                        guard let rawIncomingVideoStreamG = stream as? RawIncomingVideoStream else
                        {
                            return
                        }
                        
                        rawIncomingVideoStreamG.delegate = rawIncomingVideoStreamObserver
                        rawIncomingVideoStreamG.start()
                        rawIncomingVideoStream = rawIncomingVideoStreamG
                        
                        break
                    default:
                        break
                }
                
                incomingVideoStream = stream;
                break
            case .stopped:
                if incomingVideoStreamType == .remoteIncoming
                {
                    StopRemotePreview()
                }
            
                break
            case .notAvailable:
                if incomingVideoStreamType == .rawIncoming
                {
                    rawIncomingVideoStream!.delegate = nil
                }
                
                incomingVideoStream = nil
                break
            default:
                break
        }
    }
    
    func OnRawVideoFrameArrived(rawVideoFrameBuffer: RawVideoFrameBuffer) -> Void
    {
        incomingPixelBuffer = rawVideoFrameBuffer.buffer
    }
    
    func OnRawVideoFrameCaptured(rawVideoFrameBuffer: RawVideoFrameBuffer) -> Void
    {
        outgoingPixelBuffer = rawVideoFrameBuffer.buffer
    }
    
    private func StartRemotePreview() -> Void
    {
        if incomingVideoStreamRendererView == nil
        {
            incomingVideoStreamRenderer = try! VideoStreamRenderer(
                remoteVideoStream: remoteVideoStream!)
            let options = CreateViewOptions.init(scalingMode: ScalingMode.fit)
            
            DispatchQueue.main.async
            {
                incomingVideoStreamRendererView = try! incomingVideoStreamRenderer?.createView(
                    withOptions: options)
            }
        }
    }
    
    private func StopRemotePreview() -> Void
    {
        if let incomingVideoStreamRendererView = incomingVideoStreamRendererView
        {
            DispatchQueue.main.async
            {
                incomingVideoStreamRendererView.dispose()
                self.incomingVideoStreamRendererView = nil
                
                incomingVideoStreamRenderer?.dispose()
                incomingVideoStreamRenderer = nil
            }
        }
    }
    
    private func StartLocalPreview() -> Void
    {
        if outgoingVideoStreamRendererView == nil
        {
            outoingVideoStreamRenderer = try! VideoStreamRenderer(
                localVideoStream: localVideoStream!)
            let options = CreateViewOptions.init(scalingMode: ScalingMode.fit)
            
            DispatchQueue.main.async
            {
                outgoingVideoStreamRendererView = try! outoingVideoStreamRenderer?.createView(
                    withOptions: options)
            }
        }
    }
    
    private func StopLocalPreview() -> Void
    {
        if let outgoingVideoStreamRendererView = outgoingVideoStreamRendererView
        {
            DispatchQueue.main.async
            {
                outgoingVideoStreamRendererView.dispose()
                self.outgoingVideoStreamRendererView = nil
                
                outoingVideoStreamRenderer?.dispose()
                outoingVideoStreamRenderer = nil
            }
        }
    }
    
    private func StartCameraCaptureService() -> Void
    {
        if cameraCaptureService == nil
        {
            cameraCaptureService = CameraCaptureService(
                stream: virtualOutgoingVideoStream!, 
                camera: cameraList[cameraListIndex],
                format: videoFormatList[videoFormatListIndex].format)
            cameraCaptureService?.Start()
            cameraCaptureService?.delegate = OnRawVideoFrameCaptured
        }
    }
    
    private func StopCameraCaptureService() -> Void
    {
        guard let cameraCaptureService = cameraCaptureService else
        {
            return
        }
        
        cameraCaptureService.delegate = nil
        cameraCaptureService.Stop()
        self.cameraCaptureService = nil
    }
    
    private func StartScreenCaptureService() -> Void
    {
        if screenCaptureService == nil
        {
            screenCaptureService = ScreenCaptureService(
                stream: screenShareOutgoingVideoStream!)
            screenCaptureService?.Start()
            screenCaptureService?.delegate = OnRawVideoFrameCaptured
        }
    }
    
    private func StopScreenCaptureService() -> Void
    {
        guard let screenCaptureService = screenCaptureService else
        {
            return
        }
        
        screenCaptureService.delegate = nil
        screenCaptureService.Stop()
        self.screenCaptureService = nil
    }
    
    private func EndCall() async -> Void
    {
        if !callInProgress
        {
            return
        }
        
        loading = true
        do
        {
            if call != nil
            {
                call!.remoteParticipants.forEach { remoteParticipant in
                    remoteParticipant.delegate = nil
                }
                
                call!.delegate = nil
                
                StopRemotePreview()
                
                incomingVideoStream = nil
                remoteVideoStream = nil
                rawIncomingVideoStream = nil
                
                StopLocalPreview()
                StopCameraCaptureService()
                StopScreenCaptureService()
                
                if let localVideoStream = localVideoStream
                {
                    localVideoStream.delegate = nil
                    self.localVideoStream = nil;
                }
                
                if let virtualOutgoingVideoStream = virtualOutgoingVideoStream
                {
                    virtualOutgoingVideoStream.delegate = nil
                    self.virtualOutgoingVideoStream = nil
                }

                if let screenShareOutgoingVideoStream = screenShareOutgoingVideoStream
                {
                    screenShareOutgoingVideoStream.delegate = nil
                    self.screenShareOutgoingVideoStream = nil;
                }

                if let outgoingVideoStream = outgoingVideoStream
                {
                    try await call?.stopVideo(stream: outgoingVideoStream)
                    self.outgoingVideoStream = nil
                }

                try await call?.hangUp(options: HangUpOptions())
                call = nil
            }

            callInProgress = false
        }
        catch
        {
            showAlert = true
            alertMessage = "Failed to stopped"
            print(error.localizedDescription)
        }
        
        loading = false
    }
    
    private func GetDisplaySize() -> Void
    {
        let screenSize = UIScreen.main.bounds
        w = screenSize.width
        h = screenSize.height
        
        if h > maxHeight
        {
            let percentage = abs((maxHeight / h) - 1);
            w = ceil((w * percentage));
            h = maxHeight;
        }

        if w > maxWidth
        {
            let percentage = abs((maxWidth / w) - 1);
            h = ceil((h * percentage));
            w = maxWidth;
        }
    }
    
    private func ValidateCallSettings() async -> Bool
    {
        if meetingLink.isEmpty || !meetingLink.starts(with: "https://")
        {
            showAlert = true
            alertMessage = "Invalid teams meeting link"
            return false;
        }
        
        var isValid = true;
        switch outgoingVideoStreamType
        {
            case .localOutgoing:
                isValid = videoDeviceInfoListIndex != -1
                break
            case .virtualOutgoing:
                isValid = cameraListIndex != -1
                break
            default:
                break
        }

        return isValid;
    }
    
    private func didSelectedVideoFormat() -> Void
    {
        if cameraListIndex == -1
        {
            return
        }
        
        videoFormatList = CameraCaptureService.GetSuportedVideoFormats(
            camera: cameraList[cameraListIndex])
        
        videoFormatItemList = [VideoFormatItem]();
        videoFormatListIndex = videoFormatList.count > 0 ? 0 : -1;
        
        for i in 0 ..< videoFormatList.count
        {
            let size = videoFormatList[i].size
            let resolution = "\(Int(size.width))x\(Int(size.height))"
            let videoFormatItem = VideoFormatItem(id: i, resolution: resolution)
            videoFormatItemList.append(videoFormatItem)
        }
    }
}

class LocalVideoStreamObserver: NSObject, LocalVideoStreamDelegate
{
    private var view: ContentView

    init(view: ContentView)
    {
        self.view = view
    }
    
    func localVideoStream(_ localVideoStream: LocalVideoStream, 
                          didChangeState args: VideoStreamStateChangedEventArgs)
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
    
    func virtualOutgoingVideoStream(_ virtualOutgoingVideoStream: VirtualOutgoingVideoStream, 
                                    didChangeState args: VideoStreamStateChangedEventArgs)
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
    
    func screenShareOutgoingVideoStream(_ screenShareOutgoingVideoStream: ScreenShareOutgoingVideoStream, 
                                        didChangeState args: VideoStreamStateChangedEventArgs)
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
    
    func remoteVideoStream(_ remoteVideoStream: RemoteVideoStream, 
                           didChangeState args: VideoStreamStateChangedEventArgs)
    {
        view.OnVideoStreamStateChanged(args: args)
    }
}

class RawIncomingVideoStreamObserver: NSObject, RawIncomingVideoStreamDelegate
{
    private var view: ContentView
    var delegate: ((RawVideoFrameBuffer) -> Void)?

    init(view: ContentView)
    {
        self.view = view
    }
    
    func rawIncomingVideoStream(_ rawIncomingVideoStream: RawIncomingVideoStream, 
                                didChangeState args: VideoStreamStateChangedEventArgs)
    {
        view.OnVideoStreamStateChanged(args: args)
    }
    
    func rawIncomingVideoStream(_ rawIncomingVideoStream: RawIncomingVideoStream, 
                                didReceiveRawVideoFrame args: RawVideoFrameReceivedEventArgs)
    {
        let rawVideoFrameBuffer = args.frame as! RawVideoFrameBuffer
        
        delegate?(rawVideoFrameBuffer)
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
    
    func remoteParticipant(_ remoteParticipant: RemoteParticipant, 
                           didChangeVideoStreamState args: VideoStreamStateChangedEventArgs)
    {
        view.OnVideoStreamStateChanged(args: args)
    }
}
