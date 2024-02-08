//
//  CaptureServiceDelegate.swift
//  RawVideo
//
//  Created by Yassir Bisteni Aldana on 02/02/24.
//

import Foundation
import CoreVideo

protocol CaptureServiceDelegate : NSObject
{
    func OnRawVideoFrameCaptured(cvPixelBuffer: CVPixelBuffer) -> Void
}
