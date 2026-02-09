//
//  SmartReminderaWidgetsLiveActivity.swift
//  SmartReminderaWidgets
//
//  Created by Лейла Жунисбекова on 09.02.2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct SmartReminderaWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct SmartReminderaWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SmartReminderaWidgetsAttributes.self) { context in
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

extension SmartReminderaWidgetsAttributes {
    fileprivate static var preview: SmartReminderaWidgetsAttributes {
        SmartReminderaWidgetsAttributes(name: "World")
    }
}

extension SmartReminderaWidgetsAttributes.ContentState {
    fileprivate static var smiley: SmartReminderaWidgetsAttributes.ContentState {
        SmartReminderaWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: SmartReminderaWidgetsAttributes.ContentState {
         SmartReminderaWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: SmartReminderaWidgetsAttributes.preview) {
   SmartReminderaWidgetsLiveActivity()
} contentStates: {
    SmartReminderaWidgetsAttributes.ContentState.smiley
    SmartReminderaWidgetsAttributes.ContentState.starEyes
}
