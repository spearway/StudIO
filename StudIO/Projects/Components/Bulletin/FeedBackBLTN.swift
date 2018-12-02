//
//  FeedBackBLTN.swift
//  StudIO
//
//  Created by Arthur Guiot on 2/12/18.
//  Copyright © 2018 Arthur Guiot. All rights reserved.
//

import UIKit
import BLTNBoard

/**
 * A subclass of page bulletin item that plays an haptic feedback when the buttons are pressed.
 *
 * This class demonstrates how to override `PageBLTNItem` to customize button tap handling.
 */

class FeedbackPageBLTNItem: BLTNPageItem {
    
    private let feedbackGenerator = UISelectionFeedbackGenerator()
    
    override func actionButtonTapped(sender: UIButton) {
        
        // Play an haptic feedback
        feedbackGenerator.prepare()
        feedbackGenerator.selectionChanged()
        
        // Call super
        super.actionButtonTapped(sender: sender)
        
    }
    
    override func alternativeButtonTapped(sender: UIButton) {
        
        // Play an haptic feedback
        feedbackGenerator.prepare()
        feedbackGenerator.selectionChanged()
        
        // Call super
        super.alternativeButtonTapped(sender: sender)
        
    }
    
}
