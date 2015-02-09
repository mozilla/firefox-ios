/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import UIKit
import Storage

private let ReuseIdentifier = "cell"
private let SuggestionsLimitCount = 3

private enum SearchListSection: Int{
    case SuggestedSites = 0
    case BookmarksAndHistory
    case Search
}

// A delegate to support clicking on rows in the view controller
// This needs to be accessible to objc for UIViewControllers to call it
@objc
protocol UrlViewControllerDelegate: class {
    func didClickUrl(url: NSURL)
}

class SearchViewController: UIViewController {
    weak var delegate: UrlViewControllerDelegate?
    private var tableView = UITableView()
    private var sortedEngines = [OpenSearchEngine]()
    private var suggestClient: SearchSuggestClient?
    private var searchSuggestions = [String]()
    private var history: Cursor?
    var profile: Profile!

    var searchEngines: SearchEngines? {
        didSet {
            suggestClient?.cancelPendingRequest()

            if let searchEngines = searchEngines {
                // Show the default search engine first.
                sortedEngines = searchEngines.list.sorted { engine, _ in engine === searchEngines.defaultEngine }
                suggestClient = SearchSuggestClient(searchEngine: searchEngines.defaultEngine)
            } else {
                sortedEngines = []
                suggestClient = nil
            }

            querySuggestClient()

            // Reload the tableView to show the new list of search engines.
            tableView.reloadData()
        }
    }

    var searchQuery: String = "" {
        didSet {
            querySuggestClient()
            queryHistory()

            // Reload the tableView to show the updated text in each engine.
            tableView.reloadData()
        }
    }

    private func queryHistory() {
        println("Query history")
        profile.history.get(QueryOptions(filter: searchQuery)) { cursor in
            println("Query history \(cursor.count)")
            self.history = cursor
        }
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override init() {
        // The empty initializer of UIViewController creates the class twice (?!),
        // so override it here to avoid calling it.
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.registerClass(SearchTableViewCell.self, forCellReuseIdentifier: ReuseIdentifier)

        // Make the row separators span the width of the entire table.
        tableView.layoutMargins = UIEdgeInsetsZero
        tableView.separatorInset = UIEdgeInsetsZero

        view.addSubview(tableView)
        tableView.snp_makeConstraints { make in
            make.edges.equalTo(self.view)
            return
        }
    }

    private func querySuggestClient() {
        suggestClient?.cancelPendingRequest()

        if searchQuery.isEmpty {
            searchSuggestions = []
            return
        }

        suggestClient?.query(searchQuery, callback: { suggestions, error in
            if let error = error {
                let isSuggestClientError = error.domain == SearchSuggestClientErrorDomain

                switch error.code {
                case NSURLErrorCancelled where error.domain == NSURLErrorDomain:
                    // Request was cancelled. Do nothing.
                    break
                case SearchSuggestClientErrorInvalidEngine where isSuggestClientError:
                    // Engine does not support search suggestions. Do nothing.
                    break
                case SearchSuggestClientErrorInvalidResponse where isSuggestClientError:
                    println("Error: Invalid search suggestion data")
                default:
                    println("Error: \(error.description)")
                }

                self.searchSuggestions = []
            } else {
                self.searchSuggestions = suggestions!
                if self.searchSuggestions.count > SuggestionsLimitCount {
                    self.searchSuggestions.removeRange(SuggestionsLimitCount..<self.searchSuggestions.count)
                }
            }

            // Reload the tableView to show the new list of search suggestions.
            self.tableView.reloadData()
        })
    }
}

extension SearchViewController: UITableViewDataSource {
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(ReuseIdentifier, forIndexPath: indexPath) as SearchTableViewCell

        if indexPath.section == SearchListSection.SuggestedSites.rawValue {
            cell.textLabel?.text = searchSuggestions[indexPath.row]
            cell.imageView?.image = nil
            cell.isAccessibilityElement = false
            cell.accessibilityLabel = nil
        } else if indexPath.section == SearchListSection.BookmarksAndHistory.rawValue {
            if let history = history {
                if let site = history[indexPath.row] as? Site {
                    cell.textLabel?.text = site.url
                    cell.imageView?.image = nil
                    cell.isAccessibilityElement = false
                    cell.accessibilityLabel = nil
                }
            }
        } else if indexPath.section == SearchListSection.Search.rawValue {
            let searchEngine = sortedEngines[indexPath.row]
            cell.textLabel?.text = searchQuery
            cell.imageView?.image = searchEngine.image
            cell.isAccessibilityElement = true
            cell.accessibilityLabel = NSString(format: NSLocalizedString("%@ search for %@", comment: "E.g. \"Google search for Mars\". Please keep the first \"%@\" (which contains the search engine name) as close to the beginning of the translated phrase as possible (it is best to have it as the very first word). This is because the phrase is an accessibility label and VoiceOver users need to hear the search engine name first as that is the key information in the whole phrase (they know the search term because they typed it and from previous rows of the table)."), searchEngine.shortName, searchQuery)
        }

        // Make the row separators span the width of the entire table.
        cell.layoutMargins = UIEdgeInsetsZero

        return cell
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let currentSection = SearchListSection(rawValue: section) {
            switch(currentSection) {
            case .SuggestedSites:
                return searchSuggestions.count
            case .Search:
                return sortedEngines.count
            case .BookmarksAndHistory:
                if let history = history {
                    return history.count
                }
                return 0
            }
        }
        return 0
    }

    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if let currentSection = SearchListSection(rawValue: section) {
            switch(currentSection) {
            case .SuggestedSites:
                return "Suggested Sites"
            case .Search:
                return "Search"
            case .BookmarksAndHistory:
                return "Bookmarks & History"
            }
        }
        return ""
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        var sectionNum = 0
        if searchSuggestions.count > 0 {
            sectionNum++
        }
        if sortedEngines.count > 0{
            sectionNum++
        }
        if let history = history {
            if history.count > 0 {
                sectionNum++
            }
        }
        return sectionNum
    }
}

extension SearchViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        var url: NSURL?
        if indexPath.row < searchSuggestions.count {
            let suggestion = searchSuggestions[indexPath.row]

            url = URIFixup().getURL(suggestion)
            if url == nil {
                // Assume that only the default search engine can provide search suggestions.
                url = searchEngines?.defaultEngine.searchURLForQuery(suggestion)
            }
        } else {
            let engine = sortedEngines[indexPath.row - searchSuggestions.count]
            url = engine.searchURLForQuery(searchQuery)
        }

        if let url = url {
            delegate?.didClickUrl(url)
        }
    }
}

private class SearchTableViewCell: UITableViewCell {
    private override func layoutSubviews() {
        super.layoutSubviews()
        self.imageView?.bounds = CGRectMake(0, 0, 24, 24)
    }
}