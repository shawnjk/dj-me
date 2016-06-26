//
//  ViewController.swift
//  DJ Me
//
//  Created by Shawn Kim on 4/5/16.
//  Copyright © 2016 Shawn. All rights reserved.
//

import UIKit
import ReactiveCocoa
import WebImage

class SearchViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private struct Static {
        static var onceToken = 0
        static var scrollSignalProducer: SignalProducer<(String, Int), NSError>?
        static var scrollObserver: Observer<(String, Int), NSError>?
    }

    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var tableView: UITableView!

    var albums: [Album] = [Album]()
    var tracks: [Track] = [Track]()
    var artists: [Artist] = [Artist]()

    // MARK: Implements UITableViewDataSource
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Artists"
        case 1:
            return "Albums"
        case 2:
            return "Tracks"
        default:
            return nil
        }
    }

    func tableView(tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let width = UIScreen.mainScreen().bounds.width
        let frame = CGRect(x: 0, y: 0, width: width, height: 20)

        let label = UILabel(frame: frame)
        var tapGestureRecognizer: UITapGestureRecognizer
        switch section {
        case 0:
            tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(showAllArtists))
            label.text = "Show all artists"
            break
        case 1:
            tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(showAllAlbums))
            label.text = "Show all albums"
            break
        case 2:
            tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(showAllTracks))
            label.text = "Show all tracks"
            break
        default:
            return nil
        }

        let footer = UIView(frame: frame)
        footer.addGestureRecognizer(tapGestureRecognizer)
        footer.addSubview(label)
        return footer
    }

    func showAllArtists() {
        self.performSegueWithIdentifier("ShowAllSegue", sender: "artist")
    }

    func showAllAlbums() {
        self.performSegueWithIdentifier("ShowAllSegue", sender: "album")
    }

    func showAllTracks() {
        self.performSegueWithIdentifier("ShowAllSegue", sender: "track")
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let showAllTableViewController = segue.destinationViewController as? ShowAllTableViewController, type = sender as? String, query = self.textField.text {
            showAllTableViewController.type = type
            showAllTableViewController.query = query
        }
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let section = indexPath.section
        let row = indexPath.row

        let tableCell: AlbumCell = tableView.dequeueReusableCellWithIdentifier("AlbumCell") as? AlbumCell ?? AlbumCell()

        switch section {
        case 0:
            let artist = self.artists[row]
            if let images = artist.images where images.count > 0 {
                tableCell.coverImageView?.sd_setImageWithURL(images[0].URL)
            }
            tableCell.nameLabel.text = artist.name
            break
        case 1:
            let album = self.albums[row]
            if let images = album.images where images.count > 0 {
                tableCell.coverImageView?.sd_setImageWithURL(images[0].URL)
            }
            tableCell.nameLabel.text = album.name
            break
        case 2:
            let track = self.tracks[row]
            if let images = track.album?.images where images.count > 0 {
                tableCell.coverImageView.sd_setImageWithURL(images[0].URL)
            }
            tableCell.nameLabel.text = track.name
            break
        default:
            break
        }
        return tableCell
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return self.artists.count
        case 1:
            return self.albums.count
        case 2:
            return self.tracks.count
        default:
            return 0
        }
    }

    // MARK: Implements UITableViewDelegate
    func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 20;
    }

    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 20;
    }

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 3
    }

    // MARK: Implements: UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.dataSource = self
        self.tableView.delegate = self

        let signalProducer = self.textField.rac_textSignal().toSignalProducer().map { $0 as! String }

        let signalProducer2 = signalProducer.flatMap(.Latest) { (query) -> SignalProducer<SignalProducer<(NSData, NSURLResponse), NSError>, NSError> in
            let (searchByTypeSignal, searchByTypeObserver) = SignalProducer<SignalProducer<(NSData, NSURLResponse), NSError>, NSError>.buffer(3)
            for type in ["album", "artist", "track"] {
                let baseURL = "https://api.spotify.com/v1/search?type=\(type)&limit=5&q="
                let escapedQuery = query.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
                let URL = NSURL(string: baseURL + escapedQuery!)
                let URLRequest = NSURLRequest(URL: URL!)
                searchByTypeObserver.sendNext(NSURLSession.sharedSession().rac_dataWithRequest(URLRequest))
            }

            return searchByTypeSignal;
        }

        signalProducer2.flatten(.Merge).observeOn(UIScheduler()).startWithNext { (data, response) in
            var resultsAsJSONObject: [String: [String: AnyObject]]?
            do {
                resultsAsJSONObject = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions()) as? [String: [String: AnyObject]]
            }
            catch let error as NSError {
                print(error.localizedDescription)
                print(error.localizedFailureReason)
            }

            for type in ["albums", "artists", "tracks"] {
                if let itemsAsJSON = resultsAsJSONObject?[type]?["items"] as? [[String: AnyObject]] {
                    switch type {
                    case "albums":
                        self.albums = [Album].fromJSONArray(itemsAsJSON)
                        self.tableView.reloadData()
                        break
                    case "artists":
                        self.artists = [Artist].fromJSONArray(itemsAsJSON)
                        self.tableView.reloadData()
                        break
                    case "tracks":
                        self.tracks = [Track].fromJSONArray(itemsAsJSON)
                        self.tableView.reloadData()
                        break
                    default:
                        break
                    }
                }
            }
        }
    }
}

