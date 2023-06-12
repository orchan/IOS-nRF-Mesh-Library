/*
* Copyright (c) 2019, Nordic Semiconductor
* All rights reserved.
*
* Redistribution and use in source and binary forms, with or without modification,
* are permitted provided that the following conditions are met:
*
* 1. Redistributions of source code must retain the above copyright notice, this
*    list of conditions and the following disclaimer.
*
* 2. Redistributions in binary form must reproduce the above copyright notice, this
*    list of conditions and the following disclaimer in the documentation and/or
*    other materials provided with the distribution.
*
* 3. Neither the name of the copyright holder nor the names of its contributors may
*    be used to endorse or promote products derived from this software without
*    specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
* ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
* IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
* INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
* NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
* PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
* WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
* ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
* POSSIBILITY OF SUCH DAMAGE.
*/

import UIKit
import nRFMeshProvision

protocol NetworkKeyDelegate {
    /// This method is called when a new Network Key has been added to the Node.
    func keyAdded()
}

class NodeAddNetworkKeyViewController: ProgressViewController {
    
    // MARK: - Outlets and Actions
    
    @IBOutlet weak var doneButton: UIBarButtonItem!
    
    @IBAction func cancelTapped(_ sender: UIBarButtonItem) {
        dismiss(animated: true)
    }
    @IBAction func doneTapped(_ sender: UIBarButtonItem) {
        guard let selectedIndexPath = selectedIndexPath else {
            return
        }
        let selectedNetworkKey = keys[selectedIndexPath.row]
        addKey(selectedNetworkKey)
    }
    
    // MARK: - Properties
    
    var node: Node!
    var delegate: NetworkKeyDelegate?
    
    private var keys: [NetworkKey]!
    private var selectedIndexPath: IndexPath?
    
    // MARK: - View Controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let presentNetworkKeysSettings = UIButtonAction(title: "Settings") { [weak self] in
            guard let self = self else { return }
            let tabBarController = self.presentingViewController as? RootTabBarController
            self.dismiss(animated: true) {
                tabBarController?.presentNetworkKeysSettings()
            }
        }
        tableView.setEmptyView(title: "No keys available",
                               message: "Go to Settings to create a new key.",
                               messageImage: #imageLiteral(resourceName: "baseline-key"),
                               action: presentNetworkKeysSettings)
        
        MeshNetworkManager.instance.delegate = self
        
        let meshNetwork = MeshNetworkManager.instance.meshNetwork!
        keys = meshNetwork.networkKeys.notKnownTo(node: node)
        if keys.isEmpty {
            tableView.showEmptyView()
        }
        // Initially, no key is checked.
        doneButton.isEnabled = false
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return keys.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let key = keys[indexPath.row]
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = key.name
        cell.accessoryType = indexPath == selectedIndexPath ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        var rows: [IndexPath] = []
        if let selectedIndexPath = selectedIndexPath {
            rows.append(selectedIndexPath)
        }
        rows.append(indexPath)
        selectedIndexPath = indexPath
        tableView.reloadRows(at: rows, with: .automatic)
        
        doneButton.isEnabled = true
    }
}

private extension NodeAddNetworkKeyViewController {
    
    /// Adds the given Network Key to the target Node.
    ///
    /// - parameter networkKey: The Network Key to be added.
    func addKey(_ networkKey: NetworkKey) {
        guard let node = node else {
            return
        }
        start("Adding Network Key...") {
            let message = ConfigNetKeyAdd(networkKey: networkKey)
            return try MeshNetworkManager.instance.send(message, to: node)
        }
    }
    
}

extension NodeAddNetworkKeyViewController: MeshNetworkDelegate {
    
    func meshNetworkManager(_ manager: MeshNetworkManager,
                            didReceiveMessage message: MeshMessage,
                            sentFrom source: Address, to destination: Address) {
        // Has the Node been reset remotely.
        guard !(message is ConfigNodeReset) else {
            (UIApplication.shared.delegate as! AppDelegate).meshNetworkDidChange()
            done {
                let rootViewControllers = self.presentingViewController?.children
                self.dismiss(animated: true) {
                    rootViewControllers?.forEach {
                        if let navigationController = $0 as? UINavigationController {
                            navigationController.popToRootViewController(animated: true)
                        }
                    }
                }
            }
            return
        }
        // Is the message targeting the current Node?
        guard node.primaryUnicastAddress == source else {
            return
        }
        
        // Handle the message based on its type.
        switch message {
            
        case let status as ConfigNetKeyStatus:
            done {
                if status.status == .success {
                    self.dismiss(animated: true)
                    self.delegate?.keyAdded()
                } else {
                    self.presentAlert(title: "Error", message: status.message)
                }
            }
            
        default:
            // Ignore
            break
        }
    }
    
    func meshNetworkManager(_ manager: MeshNetworkManager,
                            failedToSendMessage message: MeshMessage,
                            from localElement: Element, to destination: Address,
                            error: Error) {
        // Ignore messages sent using model publication.
        guard message is ConfigNetKeyAdd else {
            return
        }
        done {
            self.presentAlert(title: "Error", message: error.localizedDescription)
        }
    }
    
}
