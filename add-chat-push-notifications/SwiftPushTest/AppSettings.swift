//
//  AppSettings.swift
//  SwiftPushTest
//
//  Created by NINGXIN LAN on 2022-07-27.
//

import Foundation

class AppSettings {

    private var settings: [String: Any] = [:]

    var token: String {
        return settings["token"] as! String
    }
    
    var endpoint: String {
        return settings["endpoint"] as! String
    }

    init() {
        if let url = Bundle.main.url(forResource: "AppSettings", withExtension: "plist") {
            do {
                let data = try Data(contentsOf: url)
                settings = try (PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])!
            } catch {
                print(error)
            }
        }
    }

}
