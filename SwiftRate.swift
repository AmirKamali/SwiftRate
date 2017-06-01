/*
 This file is part of SwiftRate.
 
 Copyright (c) 2017, Amir Kamali
 All rights reserved.
 
 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without
 restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following
 conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.
 */
/*
 * SwiftRate.swift
 * Get Latest version from
 * https://github.com/amirmc3/SwiftRate
 *
 * Created by Amir Kamali on 01/06/2017.
 * http://Kamali.io
 * Copyright 2017 Arash Payan. All rights reserved.
 */
import Foundation
import UIKit
import SystemConfiguration


class SwiftRate
{
    //MARK: - Constants
    let kSRFirstUseDate				= "kSRFirstUseDate"
    let kSRUseCount					= "kSRUseCount"
    let kSRShortTermEventCount		= "kSRLongEventCount"
    let kSRLongTermEventCount		= "kSRShortEventCount"
    let kSRCurrentVersion			= "kSRCurrentVersion"
    let kSRRatedCurrentVersion		= "kSRRatedCurrentVersion"
    let kSRDeclinedToRate			= "kSRDeclinedToRate"
    let kSRReminderRequestDate		= "kSRReminderRequestDate"
    
    let templateReviewURL = "itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=APP_ID&onlyLatestVersion=true&pageNumber=0&sortOrdering=1&type=Purple+Software"
    
    //MARK: variables
    private  var appId = ""
    private  var daysUntilPrompt:Double = -1
    private var usesUntilPrompt:Int = 3
    private var shortTermSignificantEventsUntilPrompt = -1
    private var longTermSignificantEventsUntilPrompt = -1
    private var timeBeforeReminding:Double = 1
    private var debug = false
    
    var delegate:swiftRateProtocol?
    
    var alwaysUseMainBundle = false
    
    var alertTitle:String = "Thank you!"
    var alertMessage:String = "If you enjoy using this app, would you please take a moment and rate this app on AppStore?"
    var alertCancelTitle:String = "Cancel"
    var alertRateTitle:String = "Rate"
    var alertRateLaterTitle:String = "Remind me later"
    var eventQueue:OperationQueue?
    var ratingAlert:UIAlertController?
    var isAlertViewShowing:Bool = false
    private static  var _sharedInstance:SwiftRate?;
    static func RegisterSwiftRate(debug:Bool = false)
    {
        _ = sharedInstance
        config_DebugMode(debug: debug)
        appLaunched(canPromptForRating: true)
    }
    static var sharedInstance:SwiftRate
    {
        get
        {
            if (_sharedInstance == nil)
            {
                _sharedInstance = SwiftRate()
                _sharedInstance?.eventQueue = OperationQueue()
                _sharedInstance?.eventQueue?.maxConcurrentOperationCount = 1
                NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
                NotificationCenter.default.addObserver(self, selector: #selector(appEnteredForeground(canPromptForRating:)), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
                //Reset short term events
                UserDefaults.standard.set(0, forKey: _sharedInstance!.kSRShortTermEventCount)
                UserDefaults.standard.synchronize()
                
            }
            
            return _sharedInstance!;
        }
    }
    
    
    //MARK:- SwiftRate Configurations
    static func config_AppID(appID:String)
    {
        SwiftRate.sharedInstance.appId = appID
    }
    static func config_DaysUntilPrompt(days:Double) {
        SwiftRate.sharedInstance.daysUntilPrompt = days
    }
    
    static func config_DaysUntilPrompt(value:Double) {
        SwiftRate.sharedInstance.daysUntilPrompt = value;
    }
    
    static func config_UsesUntilPrompt(value:Int) {
        SwiftRate.sharedInstance.usesUntilPrompt = value;
    }
    
    static func config_shortTermSignificantEventsUntilPrompt(value:NSInteger) {
        SwiftRate.sharedInstance.shortTermSignificantEventsUntilPrompt = value;
    }
    
    static func config_longTermSignificantEventsUntilPrompt(value:NSInteger) {
        SwiftRate.sharedInstance.longTermSignificantEventsUntilPrompt = value;
    }
    static func config_TimeBeforeReminding(value:Double) {
        SwiftRate.sharedInstance.timeBeforeReminding = value
    }
    
    static func config_CustomAlertTitle(title:String)
    {
        SwiftRate.sharedInstance.alertTitle = title;
    }
    
    static func config_CustomAlertMessage(message:String)
    {
        SwiftRate.sharedInstance.alertMessage = message;
    }
    
    static func config_CustomAlertCancelButtonTitle(cancelTitle:String)
    {
        SwiftRate.sharedInstance.alertCancelTitle = cancelTitle;
    }
    
    static func config_CustomAlertRateButtonTitle(rateTitle:String)
    {
        SwiftRate.sharedInstance.alertRateTitle = rateTitle;
    }
    
    static func config_CustomAlertRateLaterButtonTitle(rateLaterTitle:String)
    {
        SwiftRate.sharedInstance.alertRateLaterTitle = rateLaterTitle;
    }
    
    static func config_DebugMode(debug:Bool)
    {
        SwiftRate.sharedInstance.debug = debug;
    }
    
    static func config_AlwaysUseMainBundle(alwaysUseMainBundle:Bool) {
        SwiftRate.sharedInstance.alwaysUseMainBundle = alwaysUseMainBundle;
    }
    //MARK: - Swift Rate Logics
    
    // is this an ok time to show the alert? (regardless of whether the rating conditions have been met)
    //
    // things checked here:
    // * connectivity with network
    // * whether user has rated before
    // * whether user has declined to rate
    // * whether rating alert is currently showing visibly
    // things NOT checked here:
    // * time since first launch
    // * number of uses of app
    // * number of significant events
    // * time since last reminder
    func ratingAlertIsAppropriate()->Bool
    {
        return (self.isConnectedToNetwork()
            && !self.userHasDeclinedToRate()
            && !self.isAlertViewShowing
            && !self.userHasRatedCurrentVersion());
    }
    
    // have the rating conditions been met/earned? (regardless of whether this would be a moment when it's appropriate to show a new rating alert)
    //
    // things checked here:
    // * time since first launch
    // * number of uses of app
    // * number of significant events
    // * time since last reminder
    // things NOT checked here:
    // * connectivity with network
    // * whether user has rated before
    // * whether user has declined to rate
    // * whether rating alert is currently showing visibly
    func ratingConditionsHaveBeenMet()->Bool
    {
        if (debug)
        {
            return true;
        }
        
        let userDefaults = UserDefaults.standard
        
        let firstUse = userDefaults.double(forKey: kSRFirstUseDate)
        let dateOfFirstLaunch = NSDate(timeIntervalSince1970: firstUse)
        
        let timeSinceFirstLaunch = NSDate().timeIntervalSince(dateOfFirstLaunch as Date);
        let timeUntilRate = 60 * 60 * 24 * daysUntilPrompt
        if (timeSinceFirstLaunch < timeUntilRate)
        {
            return false
        }
        
        // check if the app has been used enough
        let useCount = userDefaults.integer(forKey: kSRUseCount);
        if (useCount < usesUntilPrompt)
        {
            return false;
        }
        
        // check if the user has done enough significant events in Total
        let sigEventCount = userDefaults.integer(forKey:kSRLongTermEventCount)
        if (sigEventCount < longTermSignificantEventsUntilPrompt)
        {
            return false;
        }
        // check if the user has done enough significant events in recently
        let sigShortEventCount = userDefaults.integer(forKey:kSRShortTermEventCount)
        if (sigShortEventCount < shortTermSignificantEventsUntilPrompt)
        {
            return false;
        }
        // if the user wanted to be reminded later, has enough time passed?
        let reminderRequestDate = NSDate(timeIntervalSince1970: userDefaults.double(forKey: kSRReminderRequestDate))
        
        let timeSinceReminderRequest = NSDate().timeIntervalSince(reminderRequestDate as Date)
        let timeUntilReminder = 60 * 60 * 24 * timeBeforeReminding;
        if (timeSinceReminderRequest < timeUntilReminder)
        {
            return false
        }
        
        return true
    }
    
    func incrementUseCount()
    {
        // get the app's version
        let version = getVersion()
        
        // get the version number that we've been tracking
        let userDefaults = UserDefaults.standard
        
        var trackingVersion = userDefaults.string(forKey: kSRCurrentVersion)
        if (trackingVersion == nil)
        {
            
            trackingVersion = version;
            userDefaults.set(version, forKey: kSRCurrentVersion)
            userDefaults.synchronize()
        }
        
        if (debug)
        {
            print("APPIRATER Tracking version: \(trackingVersion ?? "-")");
        }
        
        if (trackingVersion == version)
        {
            // check if the first use date has been set. if not, set it.
            var timeInterval = userDefaults.double(forKey:kSRFirstUseDate);
            if (timeInterval == 0)
            {
                timeInterval = NSDate().timeIntervalSince1970
                userDefaults.set(timeInterval, forKey: kSRFirstUseDate)
            }
            
            // increment the use count
            var useCount = userDefaults.integer(forKey: kSRUseCount)
            useCount += 1;
            userDefaults.set(useCount, forKey: kSRUseCount)
            userDefaults.synchronize()
            if (debug)
            {
                print("APPIRATER Use count: \(useCount)");
            }
        }
        else
        {
            
            // it's a new version of the app, so restart tracking
            InitializeSettings(version: version)
            userDefaults.set(1, forKey: kSRUseCount)
            userDefaults.synchronize()
        }
        
    }
    func InitializeSettings(version:String)
    {
        // it's a new version of the app, so restart tracking
        let userDefaults = UserDefaults.standard
        userDefaults.set(version, forKey: kSRCurrentVersion)
        userDefaults.set(NSDate().timeIntervalSince1970, forKey: kSRFirstUseDate)
        userDefaults.set(0, forKey: kSRUseCount)
        userDefaults.set(0, forKey: kSRLongTermEventCount)
        userDefaults.set(0, forKey: kSRShortTermEventCount)
        userDefaults.set(false, forKey: kSRRatedCurrentVersion)
        userDefaults.set(false, forKey: kSRDeclinedToRate)
        userDefaults.set(0, forKey: kSRReminderRequestDate)
        userDefaults.synchronize()
    }
    func incrementSignificantEventCount(shortTerm:Bool)
    {
        // get the app's version
        let version = getVersion()
        
        // get the version number that we've been tracking
        let userDefaults = UserDefaults.standard
        var trackingVersion = userDefaults.string(forKey: kSRCurrentVersion)
        if (trackingVersion == nil)
        {
            
            trackingVersion = version;
            userDefaults.set(version, forKey: kSRCurrentVersion)
        }
        if (debug)
        {
            print("APPIRATER Tracking version: \(trackingVersion ?? "-")");
        }
        if (trackingVersion == version)
        {
            // check if the first use date has been set. if not, set it.
            var timeInterval = userDefaults.double(forKey:kSRFirstUseDate);
            if (timeInterval == 0)
            {
                timeInterval = NSDate().timeIntervalSince1970
                userDefaults.set(timeInterval, forKey: kSRFirstUseDate)
            }
            
            
            // increment the significant event count
            var sigShortEventCount = userDefaults.integer(forKey:kSRShortTermEventCount);
            sigShortEventCount += 1;
            userDefaults.set(sigShortEventCount, forKey:kSRShortTermEventCount);
            userDefaults.synchronize()
            if (debug)
            {
                print("APPIRATER short term event count: \(sigShortEventCount)");
            }
            
            
        }
        else
        {
            InitializeSettings(version: version)
            var shorTermCount = 0
            var longTermCount = 0
            if (shortTerm)
            {
                shorTermCount = 1
            }
            else
            {
                longTermCount = 1
            }
            // it's a new version of the app, so restart tracking
            userDefaults.set(shorTermCount, forKey: kSRShortTermEventCount)
            userDefaults.set(longTermCount, forKey: kSRLongTermEventCount)
            userDefaults.synchronize()
        }
    }
    
    
    func checkForRate(canPromptForRating:Bool)
    {
        if (canPromptForRating &&
            self.ratingConditionsHaveBeenMet() &&
            self.ratingAlertIsAppropriate())
        {
            DispatchQueue.main.async {
                self.showRatingAlert(displayRateLaterButton: true)
            }
            
        }
    }
    
    
    func userHasDeclinedToRate()->Bool {
        return UserDefaults.standard.bool(forKey: kSRDeclinedToRate)
    }
    
    func userHasRatedCurrentVersion() -> Bool {
        return UserDefaults.standard.bool(forKey: kSRRatedCurrentVersion)
    }
    
    
    
    
    static func userDidSignificantEvent(eventType:swiftRateSignificantEventType)
    {
        let instance = SwiftRate.sharedInstance
        instance.eventQueue?.addOperation {
            instance.incrementSignificantEventCount(shortTerm: (eventType == .shortTerm));
            instance.checkForRate(canPromptForRating: true)
            
        }
    }
    static func rateApp()
    {
        
        let userDefaults = UserDefaults.standard
        userDefaults.set(true, forKey: SwiftRate.sharedInstance.kSRRatedCurrentVersion)
        
        userDefaults.synchronize()
        
        
        let reviewURL:String = SwiftRate.sharedInstance.templateReviewURL.replacingOccurrences(of: "APP_ID", with: "\(sharedInstance.appId)")
        UIApplication.shared.open(URL(string: reviewURL)!, options: [:], completionHandler: nil)
    }
    
    
    //MARK: - AppDelegate Events
    static func appLaunched(canPromptForRating:Bool)
    {
        DispatchQueue.main.async {
            
            let instance = SwiftRate.sharedInstance;
            if (instance.debug) {
                instance.showRatingAlert(displayRateLaterButton: true)
            }
            else {
                instance.incrementUseCount()
                instance.checkForRate(canPromptForRating: canPromptForRating)
            }
        }
    }
    
    @objc static func appWillResignActive() {
        if (SwiftRate.sharedInstance.debug)
        {
            print("APPIRATER appWillResignActive")
        }
        SwiftRate.sharedInstance.hideRatingAlert()
        
    }
    @objc static func appEnteredForeground(canPromptForRating:Bool) {
        
        let instance = SwiftRate.sharedInstance
        instance.eventQueue?.addOperation {
            instance.incrementUseCount()
            instance.checkForRate(canPromptForRating: canPromptForRating)
        }
    }
    
    
    
    //MARK: - Network
    func isConnectedToNetwork() -> Bool {
        
        var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }
        
        var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags(rawValue: 0)
        if SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) == false {
            return false
        }
        
        /* Only Working for WIFI
         let isReachable = flags == .reachable
         let needsConnection = flags == .connectionRequired
         
         return isReachable && !needsConnection
         */
        
        // Working for Cellular and WIFI
        let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        let ret = (isReachable && !needsConnection)
        
        return ret
        
    }
    
    //MARK: - UI
    func showRatingAlert(displayRateLaterButton:Bool)
    {
        let alertView = UIAlertController(title: self.alertTitle, message: self.alertMessage, preferredStyle: .alert)
        
        let action_Rate = UIAlertAction(title: self.alertRateTitle, style: .default, handler: { (action) in
            //User accepted rating
            SwiftRate.rateApp()
            if(self.delegate != nil){
                self.delegate?.didOptForRating()
            }
            self.isAlertViewShowing = false
        })
        alertView.addAction(action_Rate)
        
        if (displayRateLaterButton) {
            
            //Maybe later
            let action = UIAlertAction(title: self.alertRateLaterTitle, style: .default, handler: { (action) in
                
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: self.kSRReminderRequestDate)
                UserDefaults.standard.synchronize()
                if (self.delegate != nil)
                {
                    self.delegate?.DidOptToRemindLater()
                }
                
                self.isAlertViewShowing = false
            })
            alertView.addAction(action)
        }
        let action_Cancel = UIAlertAction(title: self.alertCancelTitle, style: .cancel, handler: { (action) in
            //Cancel Rate
            UserDefaults.standard.set(true, forKey: self.kSRDeclinedToRate)
            UserDefaults.standard.synchronize()
            
            if (self.delegate != nil)
            {
                self.delegate?.DidDeclineToRate()
            }
            
            self.isAlertViewShowing = false
        })
        alertView.addAction(action_Cancel)
        
        self.ratingAlert = alertView
        isAlertViewShowing = true
        topMostViewController()?.present(ratingAlert!, animated: true, completion: nil)
        if (delegate != nil)
        {
            delegate?.SwiftRateDidDisplayAlert(alert: ratingAlert!)
        }
        
    }
    
    func hideRatingAlert() {
        if (isAlertViewShowing) {
            if (debug)
            {
                print("APPIRATER Hiding Alert")
            }
            ratingAlert?.dismiss(animated: false, completion: nil)
            
        }
    }
    func topMostViewController() ->UIViewController?
    {
        if var topController = UIApplication.shared.keyWindow?.rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            return topController
        }
        return nil
    }
    //MARK: - App Info
    func getVersion()->String
    {
        return  Bundle.main.object(forInfoDictionaryKey: String( kCFBundleVersionKey)) as! String
        
    }
    static var bundle:Bundle
    {
        get
        {
            var bundle:Bundle?
            
            if (SwiftRate.sharedInstance.alwaysUseMainBundle) {
                bundle = Bundle.main;
            }
            else
            {
                if let bundleURL = Bundle.main.url(forResource: "SwiftRate", withExtension: "bundle")
                {
                    // SwiftRate.bundle will likely only exist when used via CocoaPods
                    bundle = Bundle(url: bundleURL)
                }
                else {
                    bundle = Bundle.main;
                }
            }
            
            return bundle!
        }
    }
    
    
}
//MARK:- Protocols
protocol swiftRateProtocol {
    func SwiftRateDidDisplayAlert(alert:UIAlertController)
    func didOptForRating()
    func DidOptToRemindLater()
    func DidDeclineToRate()
}
enum swiftRateSignificantEventType
{
    case shortTerm
    case longTerm
}
