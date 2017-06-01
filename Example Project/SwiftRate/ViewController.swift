//
//  ViewController.swift
//  SwiftRate
//
//  Created by Amir on 5/31/17.
//  Copyright © 2017 Amir Kamali. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
       
        SwiftRate.config_DaysUntilPrompt(value:1)
        SwiftRate.config_UsesUntilPrompt(value: 10)
        SwiftRate.config_longTermSignificantEventsUntilPrompt(value: -1)
        SwiftRate.config_shortTermSignificantEventsUntilPrompt(value: -1)
        SwiftRate.config_TimeBeforeReminding(value: 2)
        SwiftRate.config_DebugMode(debug: true)
        
        //Significant event
        SwiftRate.userDidSignificantEvent(eventType: .shortTerm)
        SwiftRate.userDidSignificantEvent(eventType: .longTerm)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

