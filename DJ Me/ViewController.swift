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

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private struct Static {
        static var onceToken = 0
        static var scrollSignalProducer: SignalProducer<(String, Int), NSError>?
        static var scrollObserver: Observer<(String, Int), NSError>?
    }

    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!

    var currentPage: Int = 1
    var searchResultsSignalProducer: SignalProducer<(String, Int), NSError>?
    var albumsInSearch: [Album] = [Album]()
    var myObserver: Observer<SignalProducer<(String, Int), NSError>, NSError>?
    var pageToItems = Dictionary<Int, [Album]>()

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let page = indexPath.row/20
        let row = indexPath.row % 20
        let albums = self.pageToItems[page]
        let album = albums?[row];
        let tableCell: AlbumCell = tableView.dequeueReusableCellWithIdentifier("AlbumCell") as? AlbumCell ?? AlbumCell()
        if album?.images?.count > 0 {
            let albumImage:Image = album!.images![0]
            tableCell.coverImageView.sd_cancelCurrentImageLoad()
            tableCell.coverImageView.sd_setImageWithURL(albumImage.URL)
        }
        tableCell.nameLabel.text = album?.name
        return tableCell
    }

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.pageToItems.values.count * 20
    }

    func scrollViewDidScroll(scrollView: UIScrollView) {
        print("Scroll view did scroll");
        if self.tableView.indexPathsForVisibleRows?.contains(NSIndexPath(forItem: 15 * self.currentPage, inSection: 0)) == true {
            print("Can see row 15")

            dispatch_once(&Static.onceToken, {
                let (scrollProducer, scrollObserver) = SignalProducer<(String, Int), NSError>.buffer(5)
                Static.scrollSignalProducer = scrollProducer
                Static.scrollObserver = scrollObserver
            })

            if (self.pageToItems[self.currentPage] == nil) {
            //self.searchResultsSignalProducer?.
            //let (signal, observer) = Signal<(String, Int), NSError>.pipe()
                self.myObserver?.sendNext(Static.scrollSignalProducer!)
                Static.scrollObserver?.sendNext((self.textField.text!, self.currentPage));
            /*self.searchResultsSignalProducer?.startWithSignal({ (signal, disposable) in
                return ()
            })*/
                self.currentPage += 1
            }
            //self.searchForNextPage()
        }
    }

    func searchForNextPage() {

    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.dataSource = self
        self.tableView.delegate = self

        let (signalProducer, observer) = SignalProducer<SignalProducer<(String, Int), NSError>, NSError>.buffer(5)
        self.myObserver = observer

        /*var tefd = Observer<String, NSError>.ini
        self.textField.rac_textSignal().toSignalProducer().start(<#T##observer: Observer<AnyObject?, NSError>##Observer<AnyObject?, NSError>#>)*/

        self.textField.rac_textSignal().toSignalProducer().map { text -> SignalProducer<(String, Int), NSError> in
            SignalProducer<(String, Int), NSError>.init(value: (text as! String, 0))
        }.startWithNext { (signalProducer) in
            observer.sendNext(signalProducer)
        }


        let (signalProducer2, observer2) = SignalProducer<(String, Int), NSError>.buffer(5)
        self.textField.rac_textSignal().toSignalProducer().map { (text) -> (String, Int) in
            (text as! String, 1)
        }.startWithNext { (string, page) in
            observer2.sendNext((string, page))
        }

        //.map { text -> (String, Int) in ( text as! String, 1 ) }.combineLatestWith(signalProducer)
        let searchResults = signalProducer.flatten(.Latest)
            .flatMap(.Latest) { (query: String, page: Int) -> SignalProducer<(NSData, NSURLResponse), NSError> in
                //let URLRequest = self.searchRequestWithEscapedQuery(query)
                //let baseURL = "https://api.spotify.com/v1/search?type=artist,album,track&q="
                let baseURL = String.init(format:"https://api.spotify.com/v1/search?type=album&limit=20&offset=%d&q=", page * 20)
                let escapedQuery = query.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
                let URL = NSURL(string: baseURL + escapedQuery!)
                let URLRequest = NSURLRequest(URL: URL!)
                return NSURLSession.sharedSession().rac_dataWithRequest(URLRequest)
            }.map { (data, URLResponse) -> String in
                let string = String(data: data, encoding: NSUTF8StringEncoding)!
                //return self.parseJSONResultsFromString(string)
                return string
        }//.observeOn(UIScheduler())
        // Do any additional setup after loading the view, typically from a nib.

        let searchResultsAsObjects = searchResults.map { results in
            var albums: [Album] = []
            if let resultsAsData = results.dataUsingEncoding(NSUTF8StringEncoding) {
                var resultsAsJSONObject: [String: [String: AnyObject]]?
                do {
                    resultsAsJSONObject = try NSJSONSerialization.JSONObjectWithData(resultsAsData, options: NSJSONReadingOptions()) as? [String: [String: AnyObject]]
                }
                catch let error as NSError {
                    print(error.localizedDescription)
                    print(error.localizedFailureReason)
                }

                var page: Int
                if let offset = resultsAsJSONObject?["albums"]?["offset"] as? Int {
                    page = offset / 20
                } else {
                    return
                }

                // let test = resultsAsJSONObject?["albums"]
                if let albumsInResults = (resultsAsJSONObject?["albums"]?["items"] as? [AnyObject]) {
                    for album in albumsInResults {
                        if let album = album as? [String: AnyObject] {
                            if let album = Album(json: album) {
                                albums.append(album)
                            }
                        }
                    }
                }
                self.pageToItems[page] = albums
            }
        }.observeOn(UIScheduler())

        searchResultsAsObjects.startWithNext {
            self.tableView.reloadData()
        }

        //self.rac_liftSelector(<#T##selector: Selector##Selector#>, withSignalsFromArray: <#T##[AnyObject]!#>)

           /* .startWithNext { results in
            if let resultsAsData = results.dataUsingEncoding(NSUTF8StringEncoding) {
                var resultsAsJSONObject: [String: AnyObject]?;
                do {
                    resultsAsJSONObject = try NSJSONSerialization.JSONObjectWithData(resultsAsData, options:NSJSONReadingOptions()) as? [String : AnyObject]
                }
                catch let error as NSError {
                    print(error.localizedDescription)
                    print(error.localizedFailureReason)
                }

                //let test = resultsAsJSONObject?["albums"]
                if let albumsInResults = resultsAsJSONObject?["albums"]?["items"] as? [AnyObject] {
                    for album in albumsInResults {
                        if let album = album as? [String: AnyObject] {
                            print(Album.init(json: album)?.name!)
                        }
                    }
                }
            }
            //print("Search results: \(results)")
            //self.textView.text = results
        }*/
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }



}

