//
//  CameraCaptureService.swift
//  RawVideo
//
//  Created by Yassir Bisteni Aldana on 01/02/24.
//

import Foundation
import AVFoundation
import CoreMedia
import UIKit
import SwiftUI
import AzureCommunicationCalling

extension Array where Element: Hashable
{
    func unique() -> [Element]
    {
        Array(Set(self))
    }
}

extension CGSize : Hashable
{
    public func hash(into hasher: inout Hasher)
    {
        hasher.combine(width)
        hasher.combine(height)
    }
}

struct VideoFormatBundle : Hashable
{
    let size: CGSize
    let format: AVCaptureDevice.Format
    
    public func hash(into hasher: inout Hasher)
    {
        hasher.combine(size)
    }
    
    static func == (lo: VideoFormatBundle, ro: VideoFormatBundle) -> Bool
    {
        return lo.size == ro.size
    }
}

class CameraCaptureService : CaptureService, AVCaptureVideoDataOutputSampleBufferDelegate
{
    var camera: AVCaptureDevice
    var captureSession: AVCaptureSession
    var previewLayer: AVCaptureVideoPreviewLayer?
    var format: AVCaptureDevice.Format
    
    init(stream: RawOutgoingVideoStream, camera: AVCaptureDevice, format: AVCaptureDevice.Format)
    {
        self.camera = camera
        self.format = format
        captureSession = AVCaptureSession()
        
        super.init(stream: stream)
    }
    
    func Start() -> Void
    {
        do
        {
            let videoInput = try AVCaptureDeviceInput(device: camera)
            captureSession.addInput(videoInput)
        }
        catch
        {
            print(error.localizedDescription)
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)

        let videoOutput = AVCaptureVideoDataOutput()
        if (captureSession.canAddOutput(videoOutput))
        {
            captureSession.addOutput(videoOutput)
        }
        
        let queue = DispatchQueue(label: "com.microsoft.RawVideo.CameraCaptureDelegate")
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        videoOutput.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey) : 
                                        UInt(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)]
        
        captureSession.beginConfiguration()
        do
        {
            try camera.lockForConfiguration()
            camera.activeFormat = format
            camera.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 30)
            camera.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: 30)
            camera.unlockForConfiguration()
        }
        catch
        {
            print(error.localizedDescription)
            return
        }
        
        captureSession.commitConfiguration()
        captureSession.startRunning()
    }
    
    func Stop() -> Void
    {
        captureSession.stopRunning()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, 
                       from connection: AVCaptureConnection)
    {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else
        {
            return
        }
        
        let format = stream.format
        if format != nil
        {
            let rawVideoFrameBuffer = RawVideoFrameBuffer()
            rawVideoFrameBuffer.buffer = pixelBuffer
            rawVideoFrameBuffer.streamFormat = format
            
            SendRawVideoFrame(rawVideoFrameBuffer: rawVideoFrameBuffer)
        }
    }
    
    public static func GetCameraList() -> [AVCaptureDevice]
    {
        let session = AVCaptureDevice.DiscoverySession(
                deviceTypes: [
                    .builtInWideAngleCamera,
                    .builtInTelephotoCamera,
                    .builtInUltraWideCamera
                ],
                mediaType: .video,
                position: .unspecified)
        
        return session.devices
    }
    
    public static func GetSuportedVideoFormats(camera: AVCaptureDevice) -> Array<VideoFormatBundle>
    {
        let resolutionList = [
            VideoStreamResolution.p1080,
            VideoStreamResolution.p720,
            VideoStreamResolution.p540,
            VideoStreamResolution.p480,
            VideoStreamResolution.p360,
            VideoStreamResolution.p270,
            VideoStreamResolution.p240,
            VideoStreamResolution.p108,
            VideoStreamResolution.fullHd,
            VideoStreamResolution.hd,
            VideoStreamResolution.vga,
            VideoStreamResolution.qvga
        ]
        
        let acsFormatList = resolutionList
            .map({ x in
                let format = VideoStreamFormat()
                format.resolution = x
                
                return CGSize(width: Double(format.width), 
                              height: Double(format.height))
            })
            .unique()
        
        return camera.formats
            .map { x in
                
                let dimensions = CMVideoFormatDescriptionGetDimensions(x.formatDescription)
                let size = CGSize(width: Double(dimensions.width), 
                                  height: Double(dimensions.height))

                return VideoFormatBundle(size: size, format: x)
            }
            .filter { x in
                return acsFormatList.contains(x.size)
            }
            .unique()
            .sorted(by: { s1, s2 in
                return s1.size.width > s2.size.width
            })
    }
}
