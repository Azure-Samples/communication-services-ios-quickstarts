//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License.
//

import UIKit
import AzureCommunicationCalling
import AzureCommunicationUICalling

class ViewController: UIViewController {

    private var callComposite: CallComposite?

    override func viewDidLoad() {
        super.viewDidLoad()

        let button = UIButton(frame: CGRect(x: 100, y: 100, width: 200, height: 50))
        button.contentEdgeInsets = UIEdgeInsets(top: 10.0, left: 20.0, bottom: 10.0, right: 20.0)
        button.layer.cornerRadius = 10
        button.backgroundColor = .systemBlue
        button.setTitle("Start Experience", for: .normal)
        button.addTarget(self, action: #selector(startCallComposite), for: .touchUpInside)

        button.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(button)
        button.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        button.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
    }

    @objc private func startCallComposite() {
        let callCompositeOptions = CallCompositeOptions()

        callComposite = CallComposite(withOptions: callCompositeOptions)

        let communicationTokenCredential = try! CommunicationTokenCredential(token: "<USER_ACCESS_TOKEN>")

        let remoteOptions = RemoteOptions(
            for: .groupCall(groupId: UUID(uuidString: "<GROUP_CALL_ID>")!),
            credential: communicationTokenCredential,
            displayName: "<DISPLAY_NAME>")

        /*
        // Optional parameter - localOptions
        //    - to customize participant view data such as avatar image and display name 
        //    - and to customize navigation bar's title and subtitle
            let participantViewData = ParticipantViewData(avatar: UIImage(named: "<AVATAR_IMAGE>"),
                                                          displayName: "<USER_DISPLAY_NAME>")
            let navigationBarViewData = NavigationBarViewData(title: "<NAV_TITLE>",
                                                              subtitle: "<NAV_SUBTITLE>")
            let localOptions = LocalOptions(participantViewData: participantViewData,
                                            navigationBarViewData: navigationBarViewData)
            callComposite?.launch(remoteOptions: remoteOptions, localOptions: localOptions)
        */
        callComposite?.launch(remoteOptions: remoteOptions)
    }
}
