//
//  Easy_Scheduler_WidgetsLiveActivity.swift
//  Easy Scheduler Widgets
//
//  Created by Tejas Patel on 9/9/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct Easy_Scheduler_WidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct Easy_Scheduler_WidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: Easy_Scheduler_WidgetsAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension Easy_Scheduler_WidgetsAttributes {
    fileprivate static var preview: Easy_Scheduler_WidgetsAttributes {
        Easy_Scheduler_WidgetsAttributes(name: "World")
    }
}

extension Easy_Scheduler_WidgetsAttributes.ContentState {
    fileprivate static var smiley: Easy_Scheduler_WidgetsAttributes.ContentState {
        Easy_Scheduler_WidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: Easy_Scheduler_WidgetsAttributes.ContentState {
         Easy_Scheduler_WidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: Easy_Scheduler_WidgetsAttributes.preview) {
   Easy_Scheduler_WidgetsLiveActivity()
} contentStates: {
    Easy_Scheduler_WidgetsAttributes.ContentState.smiley
    Easy_Scheduler_WidgetsAttributes.ContentState.starEyes
}
