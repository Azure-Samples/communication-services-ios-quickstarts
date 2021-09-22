//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License.
//

import UIKit
import AzureCommunicationCalling
import CallingComposite

class ViewController: UIViewController, CallingCompositeDelegate {

    private var callingComposite: CallingComposite?

    override func viewDidLoad() {
        super.viewDidLoad()

        let button = UIButton(frame: CGRect(x: 100, y: 100, width: 200, height: 50))
        button.contentEdgeInsets = UIEdgeInsets(top: 10.0, left: 20.0, bottom: 10.0, right: 20.0)
        button.layer.cornerRadius = 10
        button.backgroundColor = .systemBlue
        button.setTitle("Start Calling Composite", for: .normal)
        button.addTarget(self, action: #selector(startCallingComposite), for: .touchUpInside)

        button.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(button)
        button.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        button.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
    }

    @objc private func startCallingComposite() {
        let callingCompositeOptions = CallingCompositeOptions(
        logger: ConsoleLogger(minimumLogLevel: .info),
        themeConfiguration: nil,
        callingCompositeCallStateDelegate: self)

        callingComposite = ACSCallingComposite(withOptions: callingCompositeOptions)

        let communicationTokenCredential = try! CommunicationTokenCredential(token: "<USER_ACCESS_TOKEN>")

        let parameters = try! GroupCallParameters(communicationTokenCredential: communicationTokenCredential,
                                                  displayName: "<DISPLAY_NAME>",
                                                  groupId: "<GROUP_CALL_ID>")

        callingComposite?.startExperience(with: parameters)
    }
}
