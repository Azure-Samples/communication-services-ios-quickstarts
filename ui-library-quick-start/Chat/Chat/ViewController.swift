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

        let button = UIButton(frame: CGRect(x: 100, y: 100, width: 200, height: 50))
        button.contentEdgeInsets = UIEdgeInsets(top: 10.0, left: 20.0, bottom: 10.0, right: 20.0)
        button.layer.cornerRadius = 10
        button.backgroundColor = .systemBlue
        button.setTitle("Start Experience", for: .normal)
        button.addTarget(self, action: #selector(startChatComposite), for: .touchUpInside)

        button.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(button)
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
            identifier: communicationIdentifier,
            credential: communicationTokenCredential,
            endpoint: "<ENDPOINT_URL>",
            displayName: "<DISPLAY_NAME>")

        chatAdapter.connect(threadId: "<THREAD_ID>") { [weak self] _ in
            print("Chat connect completionHandler called")
            DispatchQueue.main.async {
                let chatCompositeViewController = ChatCompositeViewController(
                    with: chatAdapter)
                chatCompositeViewController.title = "Chat"
                let closeItem = UIBarButtonItem(
                    barButtonSystemItem: .close,
                    target: nil,
                    action: #selector(self?.onBackBtnPressed))
                chatCompositeViewController.navigationItem.leftBarButtonItem = closeItem

                let navController = UINavigationController(rootViewController: chatCompositeViewController)
                navController.modalPresentationStyle = .fullScreen
                self?.present(navController, animated: true, completion: nil)
            }
        }
    }

    @objc func onBackBtnPressed() {
        self.dismiss(animated: true, completion: nil)
    }
}
