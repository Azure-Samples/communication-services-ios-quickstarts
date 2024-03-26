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
    var screenRecorder: RPScreenRecorder = RPScreenRecorder.shared()
    
    func Start() -> Void
    {
        screenRecorder = RPScreenRecorder.shared()
        if screenRecorder.isAvailable
        {
            screenRecorder.startCapture(handler: captureOutput)
        }
    }
    
    func Stop() -> Void
    {
        screenRecorder.stopCapture()
    }
    
    func captureOutput(sampleBuffer: CMSampleBuffer, sampleBufferType: RPSampleBufferType, error: Error?) -> Void
    {
        if sampleBufferType != RPSampleBufferType.video
        {
            return
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else
        {
            return
        }
        
        let format = stream.format
        if format != nil
        {
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            
            let rawVideoFrameBuffer = RawVideoFrameBuffer()
            rawVideoFrameBuffer.buffer = pixelBuffer
            
            format.width = Int32(width)
            format.height = Int32(height)
            format.stride1 = Int32(bytesPerRow)
            rawVideoFrameBuffer.streamFormat = format
            
            SendRawVideoFrame(rawVideoFrameBuffer: rawVideoFrameBuffer)
        }
    }
}
