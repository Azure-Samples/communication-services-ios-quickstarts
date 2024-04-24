//
//  VideoFrameGeneratorService.swift
//  RawVideo
//
//  Created by Yassir Bisteni Aldana on 11/03/24.
//

import Foundation
import AzureCommunicationCalling

class VideoFrameGeneratorService : CaptureService
{
    private var frameIteratorThread: Thread?
    private var stopFrameIterator: Bool
    let w: Double
    let h: Double
    let framerate: Float
    
    override init(stream: RawOutgoingVideoStream)
    {
        let format = stream.format
        self.w = Double(format.width)
        self.h = Double(format.height)
        self.framerate = format.framesPerSecond
        self.stopFrameIterator = false
        
        super.init(stream: stream)
    }
    
    func Start() -> Void
    {
        stopFrameIterator = false
        frameIteratorThread = Thread(target: self,
                                     selector: #selector(FrameIterator),
                                     object: "com.azure.communication.calling.ios.FrameIterator")
        frameIteratorThread?.start()
    }
    
    func Stop() -> Void
    {
        if let thread = frameIteratorThread
        {
            stopFrameIterator = true
            thread.cancel()
            frameIteratorThread = nil
        }
    }
    
    @objc func FrameIterator() -> Void
    {
        while (!stopFrameIterator)
        {
            if let cvPixelBuffer = GenerateBufferNV12()
            {
                let format = stream.format
                if format != nil
                {
                    let rawVideoFrameBuffer = RawVideoFrameBuffer()
                    rawVideoFrameBuffer.buffer = cvPixelBuffer
                    rawVideoFrameBuffer.streamFormat = format
                    
                    SendRawVideoFrame(rawVideoFrameBuffer: rawVideoFrameBuffer)
                }
            }
            
            let rate = 0.1 / framerate
            let second: Float = 1000000
            usleep(useconds_t(rate * second))
        }
    }
    
    func GenerateBufferNV12() -> CVPixelBuffer?
    {
        var cvPixelBufferRef: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault,
                            Int(w),
                            Int(h),
                            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                            nil,
                            &cvPixelBufferRef) == kCVReturnSuccess else
        {
            return nil
        }
        
        guard let cvPixelBuffer = cvPixelBufferRef else
        {
            return nil
        }
        
        guard CVPixelBufferLockBaseAddress(cvPixelBuffer, .readOnly) == kCVReturnSuccess else
        {
            return nil
        }
        
        guard let yBufferArray = CVPixelBufferGetBaseAddressOfPlane(cvPixelBuffer, 0) else
        {
            return nil
        }
        
        guard let uvBufferArray = CVPixelBufferGetBaseAddressOfPlane(cvPixelBuffer, 1) else
        {
            return nil
        }
        
        var halfX: Double = 0, halfY: Double = 0
        var rVal: Double = 0, gVal: Double = 0, bVal: Double = 0
        var yVal: Double, uVal: Double = 0, vVal: Double = 0

        for y in 0 ..< Int(h)
        {
            halfY = Double(y) / 2
            for x  in 0 ..< Int(w)
            {
                halfX = Double(x) / 2
                
                let randomVal = Double.random(in: 1 ..< 255)
                rVal = randomVal
                gVal = randomVal
                bVal = randomVal
                
                yVal =  0.257 * rVal + 0.504 * gVal + 0.098 * bVal + 16;
                uVal = -0.148 * rVal - 0.291 * gVal + 0.439 * bVal + 128;
                vVal =  0.439 * rVal - 0.368 * gVal - 0.071 * bVal + 128;
                
                yBufferArray.storeBytes(of: Clip(val: yVal), toByteOffset: Int((y * Int(w)) + x), as: UInt8.self)
                uvBufferArray.storeBytes(of: Clip(val: uVal), toByteOffset: Int((halfY * w) + (halfX + 0)), as: UInt8.self)
                uvBufferArray.storeBytes(of: Clip(val: vVal), toByteOffset: Int((halfY * w) + (halfX + 1)), as: UInt8.self)
            }
        }
        
        guard CVPixelBufferUnlockBaseAddress(cvPixelBuffer, .readOnly) == kCVReturnSuccess else
        {
            return nil
        }
        
        return cvPixelBuffer
    }
    
    func Clip(val: Double) -> UInt8
    {
        return UInt8(val > 255 ? 255 : val < 0 ? 0 : val)
    }
}
