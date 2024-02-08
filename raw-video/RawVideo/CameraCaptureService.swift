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

class CameraCaptureService : CaptureService, AVCaptureVideoDataOutputSampleBufferDelegate
{
    var camera: AVCaptureDevice?
    var captureSession: AVCaptureSession = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    func Start(camera: AVCaptureDevice) -> Void
    {
        self.camera = camera
        captureSession.sessionPreset = AVCaptureSession.Preset.vga640x480

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
        videoOutput.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey) : UInt(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)]

        captureSession.startRunning()
    }
    
    func Stop() -> Void
    {
        captureSession.stopRunning()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
    {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let format = rawOutgoingVideoStream.format
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
}
