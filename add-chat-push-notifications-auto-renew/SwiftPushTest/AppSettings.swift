// --------------------------------------------------------------------------
//
// Copyright (c) Microsoft Corporation. All rights reserved.
//
// The MIT License (MIT)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the ""Software""), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED *AS IS*, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.
//
// --------------------------------------------------------------------------

import Foundation

class AppSettings {

    private var settings: [String: Any] = [:]

    var initialToken: String {
        return settings["initialToken"] as! String
    }
    
    var tokenIssuerURL: String? {
        return settings["tokenIssuerURL"] as? String
    }
    
    var acsEndpoint: String {
        return settings["acsEndpoint"] as! String
    }

    init() {
        if let url = Bundle.main.url(forResource: "AppSettings", withExtension: "plist") {
            do {
                let data = try Data(contentsOf: url)
                settings = try (PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])!
            } catch {
                print("Error reading AppSettings.plist: \(error)")
            }
        }
    }

}
