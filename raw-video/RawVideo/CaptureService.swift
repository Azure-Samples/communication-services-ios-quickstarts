//
//  CaptureService.swift
//  RawVideo
//
//  Created by Yassir Bisteni Aldana on 01/02/24.
//

import Foundation
import AzureCommunicationCalling

class CaptureService : NSObject
{
    let stream: RawOutgoingVideoStream
    var delegate: ((RawVideoFrameBuffer) -> Void)?
    
    init(stream: RawOutgoingVideoStream)
    {
        self.stream = stream
    }
    
    func SendRawVideoFrame(rawVideoFrameBuffer: RawVideoFrameBuffer) -> Void
    {
        if (CanSendRawVideoFrames())
        {
            stream.send(frame: rawVideoFrameBuffer) { error in
                
            }
            
            if (delegate != nil)
            {
                delegate!(rawVideoFrameBuffer)
            }
        }
    }
    
    private func CanSendRawVideoFrames() -> Bool
    {
        return stream != nil &&
        stream.format != nil &&
        stream.state == .started
    }
}
