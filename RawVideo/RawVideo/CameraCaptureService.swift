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
    var camera: AVCaptureDevice!
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    func Start(camera: AVCaptureDevice) -> Void
    {
        self.camera = camera
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.vga640x480

        do
        {
            let videoInput = try AVCaptureDeviceInput(device: camera)
            captureSession.addInput(videoInput)
        }
        catch let ex
        {
            let msg = ex.localizedDescription
            print(msg)
            
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)

        let videoOutput = AVCaptureVideoDataOutput()
        if (captureSession.canAddOutput(videoOutput))
        {
            captureSession.addOutput(videoOutput)
        }
        
        let queue = DispatchQueue(__label: "CameraCaptureDelegate", attr: nil)
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        videoOutput.videoSettings = ["kCVPixelBufferPixelFormatTypeKey" : UInt(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)]

        captureSession.startRunning()
    }
    
    func Stop() -> Void
    {
        if (captureSession != nil)
        {
            captureSession.stopRunning()
            captureSession = nil
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
    {
        let pixelBuffer: CVPixelBuffer! = CMSampleBufferGetImageBuffer(sampleBuffer)
        let format = rawOutgoingVideoStream.format
        
        if (pixelBuffer != nil && format != nil)
        {
            let rawVideoFrameBuffer = RawVideoFrameBuffer()
            rawVideoFrameBuffer.buffer = pixelBuffer!
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
