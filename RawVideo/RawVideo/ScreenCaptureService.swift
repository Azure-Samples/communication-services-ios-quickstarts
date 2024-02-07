//
//  ScreenCaptureService.swift
//  RawVideo
//
//  Created by Yassir Bisteni Aldana on 01/02/24.
//

import Foundation
import ReplayKit
import AzureCommunicationCalling

class ScreenCaptureService : CaptureService
{
    var screenRecorder: RPScreenRecorder!
    
    func Start() -> Void
    {
        screenRecorder = RPScreenRecorder.shared()
        
        if (screenRecorder.isAvailable)
        {
            screenRecorder.startCapture(handler: captureOutput)
        }
    }
    
    func Stop() -> Void
    {
        if (screenRecorder != nil)
        {
            screenRecorder.stopCapture()
            screenRecorder = nil
        }
    }
    
    func captureOutput(sampleBuffer: CMSampleBuffer, sampleBufferType: RPSampleBufferType, error: Error?) -> Void
    {
        if (sampleBufferType != RPSampleBufferType.video)
        {
            return
        }
        
        let pixelBuffer: CVPixelBuffer! = CMSampleBufferGetImageBuffer(sampleBuffer)
        let format = rawOutgoingVideoStream.format
        
        if (pixelBuffer != nil && format != nil)
        {
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            
            let rawVideoFrameBuffer = RawVideoFrameBuffer()
            rawVideoFrameBuffer.buffer = pixelBuffer!
            
            format.width = Int32(width)
            format.height = Int32(height)
            format.stride1 = Int32(bytesPerRow)
            rawVideoFrameBuffer.streamFormat = format
            
            SendRawVideoFrame(rawVideoFrameBuffer: rawVideoFrameBuffer)
        }
    }
}
