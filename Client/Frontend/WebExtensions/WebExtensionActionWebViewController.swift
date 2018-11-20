/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Shared
import SwiftyJSON
import WebKit

private let AllFramesAtDocumentStartJS: String = {
    let path = Bundle.main.path(forResource: "AllFramesAtDocumentStart", ofType: "js")!
    let source = try! NSString(contentsOfFile: path, encoding: String.Encoding.utf8.rawValue) as String
    return """
        (function() {
            const SECURITY_TOKEN = "\(UserScriptManager.securityToken)";
            \(source)
        })();
        """
}()

class WebExtensionActionWebViewController: UIViewController {
    let action: WebExtensionAction
    let url: URL

    let webView: WKWebView

    init?(action: WebExtensionAction) {
        guard let url = action.defaultURL else {
            return nil
        }

        self.action = action
        self.url = url

        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(WebExtensionSchemeHandler.default, forURLScheme: "moz-extension")

        self.webView = WKWebView(frame: .zero, configuration: configuration)

        let webExtension = action.webExtension

        super.init(nibName: nil, bundle: nil)

        let allFramesAtDocumentStartUserScript = WKUserScript(source: AllFramesAtDocumentStartJS, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        self.webView.configuration.userContentController.addUserScript(allFramesAtDocumentStartUserScript)
        self.webView.configuration.userContentController.addUserScript(action.apiUserScript)
        self.webView.configuration.userContentController.add(webExtension.interface, name: "webExtensionAPI")

        self.webView.allowsLinkPreview = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = action.defaultTitle
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("Done", comment: "Done button on left side of the WebExtension browser action view controller title bar"),
            style: .done,
            target: navigationController, action: #selector((navigationController as! ThemedNavigationController).done))
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = "AppSettingsTableViewController.navigationItem.leftBarButtonItem"

        view.addSubview(webView)
        webView.snp.remakeConstraints { make in
            make.edges.equalTo(self.view)
        }

        webView.load(URLRequest(url: url))
    }
}
