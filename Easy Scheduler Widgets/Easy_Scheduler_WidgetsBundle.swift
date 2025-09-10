//
//  Easy_Scheduler_WidgetsBundle.swift
//  Easy Scheduler Widgets
//
//  Created by Tejas Patel on 9/9/25.
//

import WidgetKit
import SwiftUI

@main
struct Easy_Scheduler_WidgetsBundle: WidgetBundle {
    var body: some Widget {
        Easy_Scheduler_Widgets()
        Easy_Scheduler_WidgetsControl()
        Easy_Scheduler_WidgetsLiveActivity()
    }
}
