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
import CoreBluetooth
import nRFMeshProvision

class ProxyCell: UITableViewCell {

    //MARK: - Outlets and Actions
    
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var rssiIcon: UIImageView!
    
    // MARK: - Properties
    
    private var lastUpdateTimestamp = Date()
    
    // MARK: - Implementation
    
    func setupView(withProxy proxy: GattBearer, andRSSI rssi: Int) {
        name.text = proxy.name ?? "Unknown Proxy"
        updateRssi(rssi)
    }
    
    func deviceDidUpdate(_ device: GattBearer, andRSSI rssi: Int) {
        if Date().timeIntervalSince(lastUpdateTimestamp) > 1.0 {
            lastUpdateTimestamp = Date()
            setupView(withProxy: device, andRSSI: rssi)
            
            // Hide the RSSI icon when the device is no longer advertising.
            // Timeout is around 5 seconds.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                guard let self = self else { return }
                if Date().timeIntervalSince(self.lastUpdateTimestamp) > 4.5 {
                    self.setupView(withProxy: device, andRSSI: -128)
                }
            }
        }
    }
    
    private func updateRssi(_ rssi: Int) {
        switch rssi {
        case -128:
            rssiIcon.image = nil
        case -127 ..< -80:
            rssiIcon.image = #imageLiteral(resourceName: "rssi_1")
        case -80 ..< -60:
            rssiIcon.image = #imageLiteral(resourceName: "rssi_2")
        case -60 ..< -40:
            rssiIcon.image = #imageLiteral(resourceName: "rssi_3")
        default:
            rssiIcon.image = #imageLiteral(resourceName: "rssi_4")
        }
    }

}
