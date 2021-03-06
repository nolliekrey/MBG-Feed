//
//  MBGMainViewController.swift
//  MBG Feed
//
//  Created by Jon Whitmore on 11/19/15.
//  Copyright © 2015 Jon Whitmore. All rights reserved.
//

import UIKit

// The VC class used to display the initial list of articles at startup
// See README.md for AWS concerns
class MBGMainViewController: UITableViewController {

    // HTTPS URL for the JSON payload representing the list of articles
    // Surprisingly the HTTPS certificate was rejected by iOS and therefore 
    // it was necessary to add AWS as an App Transport Security Setting exception 
    // in info.plist  
    // See README.md for AWS concerns
    let kArticleJSONURL = "https://s3.amazonaws.com/mbgd/feed/prod-test-7fc12640-6f09-4461-b683-3e55acdfd4f4.json";
    
    // Article JSON realised as an array of dictionaries, etc.
    var articleArray = [];
    
    // Feed images already downloaded are cached for table redraws
    var articleFeedImageCache = [String : UIImage]()
    
    // Used in case the user is on a slow connection
    let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
    
    // Show the user an activity indicator while the article feed is downloaded
    override func viewDidLoad() {
        super.viewDidLoad()
        
        activityIndicator.center = view.center
        view.addSubview(activityIndicator)
        activityIndicator.startAnimating()
        
        loadInitialJSON()
    }
    
    // Download the article feed and tell our tableView to reload
    func loadInitialJSON() {
        let url = NSURL(string: kArticleJSONURL)!
        
        asynchronousDataFromUrl(url, completion: {(data, response, error) in
            
            self.activityIndicator.stopAnimating()
            
            if (error != nil) {
                print(error?.localizedDescription)
                let title = "Problem fetching articles"
                let message = "Articles do not appear to be available at this time"
                let alertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
                self.presentViewController(alertController, animated: true, completion: nil)
                
            } else {
                self.articleArray = self.jsonDataToObjects(data!)!
                print("size is \(self.articleArray.count)")
                
                // Update in the main thread
                dispatch_async(dispatch_get_main_queue()) {
                    self.tableView.reloadData()
                }
            }
        })
    }
    
    // Convience method to create an NSURLSession data task and start it
    func asynchronousDataFromUrl(url: NSURL,
        completion: ((data: NSData?, response: NSURLResponse?, error: NSError? ) -> Void)) {
            
            NSURLSession.sharedSession().dataTaskWithURL(url) { (data, response, error) in
                completion(data: data, response: response, error: error)
                
        }.resume()
    }
    
    func downloadImage(url: NSURL, name: String, indexPath: NSIndexPath){
        print("Started downloading \"\(url.URLByDeletingPathExtension!.lastPathComponent!)\".")
        // download in the background
        asynchronousDataFromUrl(url) { (data, response, error)  in
            // update on the main thread
            dispatch_async(dispatch_get_main_queue()) { () -> Void in
                guard let data = data where error == nil
                    else {return} // consider trying the download again. An error message would be annoying
                
                print("Finished downloading \"\(url.URLByDeletingPathExtension!.lastPathComponent!)\".")
                self.articleFeedImageCache[name] = UIImage(data: data)
                let paths = [indexPath]
                self.tableView.reloadRowsAtIndexPaths(paths, withRowAnimation: .Fade)
            }
        }
    }

    // Convert from NSData to an NSArray of NSDictionaries, etc.
    func jsonDataToObjects(data: NSData) -> NSArray? {
        do {
            return try (
                NSJSONSerialization.JSONObjectWithData(data, options: .MutableContainers) as? NSArray
            )
        } catch let myJSONError {
            // TODO add UIAlertControl. 
            print(myJSONError)
        }
        return nil
    }
    
    // There is only one section in the table showing all articles
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    // When the app opens this will return 0, and once the article download task has
    // completed it will repsond with the number of articles
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return articleArray.count
    }
    
    // Return a properly initialized cell. Images are always overwritten
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("MBGArticleTVCell") as! MBGArticleFeedTableViewCell
        
        let dict = self.articleArray[indexPath.row] as! [String : AnyObject]
        let title = dict["title"] as! String
        let authorDict = dict["author"] as! [String : String]
        let author = authorDict["name"]
        let imageURLString = dict["image"] as! String
        
        cell.articleAuthor.text = author
        cell.articleTitle.text = title
        
        if ((self.articleFeedImageCache[imageURLString]) != nil) {
            cell.articleImage.image = self.articleFeedImageCache[imageURLString]
        } else {
            // reused cells will have the wrong image, blank it out
            cell.articleImage.image = nil;
            let url = NSURL(string: imageURLString)!
            downloadImage(url, name: imageURLString, indexPath: indexPath);
        }
        return cell
    }
    
    // Dump the image cache.
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        articleFeedImageCache.removeAll();
        
    }
    

    // MARK: - Navigation
    
     //In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        if (segue.identifier == "MBGArticleDetailsSegue") {
        
            let fullArticleController = segue.destinationViewController as! MBGFullArticleTableViewController
            
            let iPath = self.tableView.indexPathForSelectedRow
        
            //Pass the selected object to the new view controller.
            fullArticleController.articleDictionary = articleArray[(iPath?.row)!] as! [String : AnyObject]
            let imageURLString = fullArticleController.articleDictionary["image"] as! String
            fullArticleController.image = self.articleFeedImageCache[imageURLString]!
        }
        
        if (segue.identifier == "MBGWebViewSegue") {
            
            let webArticleController = segue.destinationViewController as! MBGWebViewController
            
            let iPath = self.tableView.indexPathForSelectedRow
            
            // Pass the article id to the new view controller
            let articleDictionary = articleArray[(iPath?.row)!] as! [String : AnyObject]
            webArticleController.articleIdString = articleDictionary["id"] as! String;
            
            
        }
        
    }

}

