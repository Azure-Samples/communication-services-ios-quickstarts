//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License.
//

import UIKit
import AzureCommunicationCommon
import AzureCommunicationUIChat

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let button = UIButton()
        button.contentEdgeInsets = UIEdgeInsets(top: 10.0, left: 20.0, bottom: 10.0, right: 20.0)
        button.layer.cornerRadius = 10
        button.backgroundColor = .systemBlue
        button.setTitle("Start Experience", for: .normal)
        button.addTarget(self, action: #selector(startChatComposite), for: .touchUpInside)

        button.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(button)
        button.widthAnchor.constraint(equalToConstant: 200).isActive = true
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        button.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
    }

    @objc private func startChatComposite() {
        let communicationIdentifier = CommunicationUserIdentifier("<USER_ID>")
        guard let communicationTokenCredential = try? CommunicationTokenCredential(
            token: "<USER_ACCESS_TOKEN>") else {
            return
        }

        let chatAdapter = ChatAdapter(
            endpoint: "<ENDPOINT_URL>", identifier: communicationIdentifier,
            credential: communicationTokenCredential,
            threadId: "<THREAD_ID>",
            displayName: "<DISPLAY_NAME>")

        Task {
            try await chatAdapter.connect()
            DispatchQueue.main.async {
                let chatCompositeViewController = ChatCompositeViewController(
                    with: chatAdapter)

                let closeItem = UIBarButtonItem(
                    barButtonSystemItem: .close,
                    target: nil,
                    action: #selector(self.onBackBtnPressed))
                chatCompositeViewController.title = "Chat"
                chatCompositeViewController.navigationItem.leftBarButtonItem = closeItem

                let navController = UINavigationController(rootViewController: chatCompositeViewController)
                navController.modalPresentationStyle = .fullScreen

                self.present(navController, animated: true, completion: nil)
            }
        }
    }

    @objc func onBackBtnPressed() {
        self.dismiss(animated: true, completion: nil)
    }
}
