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

class UserTokenClient {
    private let tokenIssuerURL: URL
    private var acsUserId: String?
    private var userToken: String?
    private var acsEndpoint: String?
    
    init(acsUserId: String, tokenIssuerURL: String) {
        guard let endpointURL = URL(string: tokenIssuerURL) else {
            fatalError("Invalid URL endpoint")
        }
        self.tokenIssuerURL = endpointURL
        self.acsUserId = acsUserId
    }
    
    func getTokenForAcsUserId(completion: @escaping (Bool, Error?) -> Void) {
        var requestURL = tokenIssuerURL
        var urlComponents = URLComponents(url: requestURL, resolvingAgainstBaseURL: false)
        urlComponents?.queryItems = [URLQueryItem(name: "acsUserId", value: acsUserId)]
        
        guard let finalURL = urlComponents?.url else {
            completion(false, NSError(domain: "InvalidURL", code: 100, userInfo: nil))
            return
        }
        
        let task = URLSession.shared.dataTask(with: finalURL) { data, response, error in
            guard let data = data, error == nil else {
                completion(false, error)
                return
            }
            
            do {
                let userData = try JSONDecoder().decode(UserData.self, from: data)
                self.acsUserId = userData.acsUserId
                self.userToken = userData.userToken
                self.acsEndpoint = userData.acsEndpoint
                completion(true, nil)
            } catch {
                completion(false, error)
            }
        }
        task.resume()
    }
    
    var getacsUserId: String? {
        return acsUserId
    }
    
    var getUserToken: String? {
        return userToken
    }
    
    var getAcsEndpoint: String? {
        return acsEndpoint
    }
    
    private struct UserData: Codable {
        var acsEndpoint: String
        var acsUserId: String
        var userToken: String
    }
}
