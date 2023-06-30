//
//  CallKitHelper.swift
//  iOSVideo
//
//  Created by Sanath Rao on 6/28/23.
//

import Foundation
import CallKit

final class CallKitHelper {

    static func createCXProvideConfiguration() -> CXProviderConfiguration {
        let providerConfig = CXProviderConfiguration()
        providerConfig.supportsVideo = true
        providerConfig.maximumCallsPerCallGroup = 1
        providerConfig.includesCallsInRecents = true
        providerConfig.supportedHandleTypes = [.phoneNumber, .generic]
        return providerConfig
    }
}
