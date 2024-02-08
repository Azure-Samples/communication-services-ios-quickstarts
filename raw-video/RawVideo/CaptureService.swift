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
    let rawOutgoingVideoStream: RawOutgoingVideoStream
    var delegate: ((RawVideoFrameBuffer) -> Void)?
    
    init(rawOutgoingVideoStream: RawOutgoingVideoStream)
    {
        self.rawOutgoingVideoStream = rawOutgoingVideoStream
    }
    
    func SendRawVideoFrame(rawVideoFrameBuffer: RawVideoFrameBuffer) -> Void
    {
        if (CanSendRawVideoFrames())
        {
            rawOutgoingVideoStream.send(frame: rawVideoFrameBuffer) { error in
                
            }
            
            if (delegate != nil)
            {
                delegate!(rawVideoFrameBuffer)
            }
        }
    }
    
    private func CanSendRawVideoFrames() -> Bool
    {
        return rawOutgoingVideoStream != nil &&
        rawOutgoingVideoStream.format != nil &&
        rawOutgoingVideoStream.state == .started
    }
}
