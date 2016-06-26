//
//  ShowAllTableViewController.swift
//  DJ Me
//
//  Created by Shawn Kim on 6/12/16.
//  Copyright © 2016 Shawn. All rights reserved.
//

import Foundation
import ReactiveCocoa
import UIKit

class ShowAllTableViewController: UITableViewController {

    var lastLoadedPage = 0

    let scrollSignal: SignalProducer<Int, NSError>
    let scrollObserver: Observer<Int, NSError>

    var type: String
    var query: String
    var results: [AnyObject] = []

    // MARK: Implements UITableViewDataSource
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let row = indexPath.row
        let tableCell: AlbumCell = tableView.dequeueReusableCellWithIdentifier("AlbumCell") as? AlbumCell ?? AlbumCell()
        switch type {
        case "album":
            if let album = self.results[row] as? Album {
                if let images = album.images where images.count > 0 {
                    tableCell.coverImageView?.hidden = false
                    tableCell.coverImageView?.sd_setImageWithURL(images[0].URL)
                } else {
                    tableCell.coverImageView?.hidden = true
                }
                tableCell.nameLabel.text = album.name
            }
            break
        case "artist":
            if let artist = self.results[row] as? Artist {
                if let images = artist.images where images.count > 0 {
                    tableCell.coverImageView?.hidden = false
                    tableCell.coverImageView?.sd_setImageWithURL(images[0].URL)
                } else {
                    tableCell.coverImageView?.hidden = true
                }
                tableCell.nameLabel.text = artist.name
            }
            break
        case "track":
            if let track = self.results[row] as? Track {
                if let images = track.album?.images where images.count > 0 {
                    tableCell.coverImageView?.hidden = false
                    tableCell.coverImageView?.sd_setImageWithURL(images[0].URL)
                } else {
                    tableCell.coverImageView?.hidden = true
                }
                tableCell.nameLabel.text = track.name
            }
            break
        default:
            break
        }

        return tableCell
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }

    // Implements UIScrollViewDelegate
    override func scrollViewDidScroll(scrollView: UIScrollView) {
        let lastLoadedRow = lastLoadedPage * 50
        let indexPathToLoadAdditionalRowsIfVisible = NSIndexPath(forRow: lastLoadedRow - 5, inSection: 0)
        if let indexPathsForVisibleRows = self.tableView.indexPathsForVisibleRows
        where indexPathsForVisibleRows.contains(indexPathToLoadAdditionalRowsIfVisible) {
            scrollObserver.sendNext(self.lastLoadedPage)
            //lastLoadedPage += 1
        }
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        type = ""
        query = ""
        (scrollSignal, scrollObserver) = SignalProducer<Int, NSError>.buffer(1)
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder aDecoder: NSCoder) {
        self.type = ""
        self.query = ""
        (scrollSignal, scrollObserver) = SignalProducer<Int, NSError>.buffer(1)
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = self
        tableView.delegate = self

        func deserializeJSONResult(data: NSData, response: NSURLResponse) {
            var resultsAsJSONObject: [String: [String: AnyObject]]?
            do {
                resultsAsJSONObject = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions()) as? [String: [String: AnyObject]]
            }
            catch let error as NSError {
                print(error.localizedDescription)
                print(error.localizedFailureReason)
            }

            if let itemsAsJSON = resultsAsJSONObject?[self.type + "s"]?["items"] as? [[String: AnyObject]] {
                switch self.type {
                case "album":
                    self.results += [Album].fromJSONArray(itemsAsJSON) as [AnyObject]
                    break
                case "artist":
                    self.results += [Artist].fromJSONArray(itemsAsJSON) as [AnyObject]
                    break
                case "track":
                    self.results += [Track].fromJSONArray(itemsAsJSON) as [AnyObject]
                    break
                default:
                    break
                }

                let indices = [Int]((lastLoadedPage * 50)...(lastLoadedPage * 50 + itemsAsJSON.count - 1))
                let indexPaths = indices.map({ (index) -> NSIndexPath in
                    return NSIndexPath(forRow: index, inSection: 0)
                })

                dispatch_async(dispatch_get_main_queue(), {
                    self.tableView.insertRowsAtIndexPaths(indexPaths, withRowAnimation: UITableViewRowAnimation.None)
                })

                lastLoadedPage += 1
            }
        }

        func deserializeJSONResultAndReloadTable(data: NSData, response: NSURLResponse) {
            deserializeJSONResult(data, response: response)
            dispatch_async(dispatch_get_main_queue()) {
                self.tableView.reloadData()
            }
        }

        let baseURL = "https://api.spotify.com/v1/search?type=\(type)&limit=50&q="
        let escapedQuery = query.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())

        // Setup search on scroll
        scrollSignal.flatMap(.Latest) { (page) -> SignalProducer<(NSData, NSURLResponse), NSError> in
            let queryWithOffset = "\(baseURL)\(escapedQuery!)&offset=\(page * 50)"
            let URLForQueryWithOffset = NSURL(string: queryWithOffset)
            let RequestForQueryWithOffset = NSURLRequest(URL: URLForQueryWithOffset!);
            return NSURLSession.sharedSession().rac_dataWithRequest(RequestForQueryWithOffset)
        }.startWithNext(deserializeJSONResult)

        // Setup initial search
        let initialQuery = baseURL + escapedQuery!
        let URLForInitialQuery = NSURL(string: initialQuery)
        let RequestForInitialQuery = NSURLRequest(URL: URLForInitialQuery!);
        NSURLSession.sharedSession().rac_dataWithRequest(RequestForInitialQuery)
            .map(deserializeJSONResult)
            .start()
    }
}
