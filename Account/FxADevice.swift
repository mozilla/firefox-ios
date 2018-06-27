/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Shared
import SwiftyJSON

public struct FxADevicePushParams {
    let callback: String
    let publicKey: String
    let authKey: String
}

public class FxADevice: RemoteDevice {
    let pushParams: FxADevicePushParams?

    fileprivate init(name: String, id: String?, type: String?, isCurrentDevice: Bool = false, push: FxADevicePushParams?, lastAccessTime: Timestamp?, availableCommands: [String : JSON]?) {
        self.pushParams = push
        super.init(id: id, name: name, type: type, isCurrentDevice: isCurrentDevice, lastAccessTime: lastAccessTime, availableCommands: availableCommands)
    }

    static func forRegister(_ name: String, type: String, availableCommands: [String : JSON], push: FxADevicePushParams?) -> FxADevice {
        return FxADevice(name: name, id: nil, type: type, push: push, lastAccessTime: nil, availableCommands: availableCommands)
    }

    static func forUpdate(_ name: String, id: String, availableCommands: [String : JSON], push: FxADevicePushParams?) -> FxADevice {
        return FxADevice(name: name, id: id, type: nil, push: push, lastAccessTime: nil, availableCommands: availableCommands)
    }

    func toJSON() -> JSON {
        var parameters = [String: Any]()
        parameters["name"] = name
        parameters["id"] = id
        parameters["type"] = type
        parameters["availableCommands"] = availableCommands
        if let push = self.pushParams {
            parameters["pushCallback"] = push.callback
            parameters["pushPublicKey"] = push.publicKey
            parameters["pushAuthKey"] = push.authKey
        }
        return JSON(parameters)
    }

    static func fromJSON(_ json: JSON) -> FxADevice? {
        guard json.error == nil,
            let id = json["id"].string,
            let name = json["name"].string else {
                return nil
        }

        let isCurrentDevice = json["isCurrentDevice"].bool ?? false
        let lastAccessTime = json["lastAccessTime"].uInt64
        let type = json["type"].string
        let availableCommands = json["availableCommands"].dictionaryObject as? [String : JSON]

        let push: FxADevicePushParams?
        if let pushCallback = json["pushCallback"].stringValue(),
            let publicKey = json["pushPublicKey"].stringValue(), publicKey != "",
            let authKey   = json["pushAuthKey"].stringValue(), authKey != "" {
            push = FxADevicePushParams(callback: pushCallback, publicKey: publicKey, authKey: authKey)
        } else {
            push = nil
        }

        return FxADevice(name: name, id: id, type: type, isCurrentDevice: isCurrentDevice, push: push, lastAccessTime: lastAccessTime, availableCommands: availableCommands)
    }
}
