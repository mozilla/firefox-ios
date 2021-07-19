/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import AuthenticationServices

protocol CredentialListViewProtocol: AnyObject {
    var credentialExtensionContext: ASCredentialProviderExtensionContext? { get }
    var searchIsActive: Bool { get }
}

class CredentialListViewController: UIViewController, CredentialListViewProtocol, UISearchControllerDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    
    var dataSource = [(ASPasswordCredentialIdentity, ASPasswordCredential)]() {
        didSet {
            presenter?.loginsData = dataSource
            tableView?.reloadData()
        }
    }
    
    private var presenter: CredentialListPresenter?
    private var searchController: UISearchController?
    
    private var cancelButton: UIButton {
        let button = UIButton(type: UIButton.ButtonType.system)
        button.setTitle(.LoginsListSearchCancel, for: .normal)
        button.titleLabel?.font = .navigationButtonFont
        button.accessibilityIdentifier = "cancel.button"
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addConstraint(NSLayoutConstraint(
                                item: button,
                                attribute: .width,
                                relatedBy: .equal,
                                toItem: nil,
                                attribute: .notAnAttribute,
                                multiplier: 1.0,
                                constant: 60))
        button.addTarget(self, action: #selector(self.cancelAction), for: .touchUpInside)
        return button
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    var searchIsActive: Bool {
        guard let searchCtr = searchController, searchCtr.isActive && searchCtr.searchBar.text != ""  else {
            return false
        }
        return true
    }
    
    var credentialExtensionContext: ASCredentialProviderExtensionContext? {
        return (navigationController?.parent as? CredentialProviderViewController)?.extensionContext
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.presenter = CredentialListPresenter(view: self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setNeedsStatusBarAppearanceUpdate()
        setupTableView()
        styleNavigationBar()
    }
    
    
    func reloadData() {
        tableView.reloadData()
    }
    
    private func setupTableView() {
        let backgroundView = UIView(frame: self.view.bounds)
        tableView.backgroundView = backgroundView
        tableView.keyboardDismissMode = .onDrag
    }
    
    private func styleNavigationBar() {
        navigationItem.title = "Firefox"
        navigationItem.largeTitleDisplayMode = .never
        navigationController?.navigationBar.accessibilityIdentifier = "firefox.navigationBar"
        navigationController?.navigationBar.titleTextAttributes = [
            .font: UIFont.navigationTitleFont
        ]
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: cancelButton)
        searchController = self.getStyledSearchController()
        searchController?.delegate = self
        extendedLayoutIncludesOpaqueBars = true // Fixes tapping the status bar from showing partial pull-to-refresh
    }
    
    private func getStyledSearchController() -> UISearchController {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = true
        searchController.searchResultsUpdater = self
        searchController.delegate = self
        searchController.isActive = true
        searchController.searchBar.sizeToFit()
        searchController.searchBar.searchBarStyle = UISearchBar.Style.minimal
        self.navigationItem.searchController = searchController
        self.navigationItem.hidesSearchBarWhenScrolling = false
        self.definesPresentationContext = true
        
        let searchIcon = UIImage(named: "search-icon")?.withRenderingMode(.alwaysTemplate).tinted(UIColor.systemBlue)
        let clearIcon = UIImage(named: "clear-icon")?.withRenderingMode(.alwaysTemplate).tinted(UIColor.systemBlue)
        searchController.searchBar.setImage(searchIcon, for: UISearchBar.Icon.search, state: .normal)
        searchController.searchBar.setImage(clearIcon, for: UISearchBar.Icon.clear, state: .normal)
        
        searchController.searchBar.searchTextPositionAdjustment = UIOffset(horizontal: 5.0, vertical: 0) // calling setSearchFieldBackgroundImage removes the spacing between the search icon and text
        if let searchField = searchController.searchBar.value(forKey: "searchField") as? UITextField {
            if let backgroundview = searchField.subviews.first {
                backgroundview.layer.cornerRadius = 10
                backgroundview.clipsToBounds = true
            }
        }
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).attributedPlaceholder = NSAttributedString(string: .LoginsListSearchPlaceholder, attributes: [:]) // Set the placeholder text and color
        return searchController
    }
    
    
    @objc func cancelAction() {
        presenter?.cancelRequest()
    }
}

extension CredentialListViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        guard let presenter = presenter else { return 1 }
        return presenter.numberOfSections()
        
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let presenter = presenter else { return 1 }
        return presenter.numberOfRows(for: section)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch presenter?.getItemsType(in: indexPath.section, for: indexPath.row) {
        case .emptyCredentialList:
            let cell = tableView.dequeueReusableCell(withIdentifier: "emptylistplaceholder", for: indexPath) as? EmptyPlaceholderCell
            return cell ?? UITableViewCell()
        case .emptySearchResult:
           let cell = tableView.dequeueReusableCell(withIdentifier: "noresultsplaceholder", for: indexPath) as? NoSearchResultCell
            return cell ?? UITableViewCell()
        case .selectPassword:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "selectapasswordhelptext", for: indexPath) as? SelectPasswordCell else {
                return UITableViewCell()
            }
            return cell
        case .displayItem(let credentialIdentity):
            let cell = tableView.dequeueReusableCell(withIdentifier: "itemlistcell", for: indexPath) as? ItemListCell
            cell?.titleLabel.text = credentialIdentity.serviceIdentifier.identifier.titleFromHostname
            cell?.detailLabel.text = credentialIdentity.user
            let backgroundView = UIView()
            backgroundView.backgroundColor = UIColor.lightGray
            cell?.selectedBackgroundView = backgroundView
            return cell ?? UITableViewCell()
        case .none:
            return UITableViewCell()
        }
    }
}

extension CredentialListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 {
            presenter?.selectItem(for: indexPath.row)
        }
    }
}


extension CredentialListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        presenter?.filterCredentials(for: searchController.searchBar.text ?? "")
        tableView.reloadData()
    }
}
