//
//  SmartReminderaWidgetsBundle.swift
//  SmartReminderaWidgets
//
//  Created by Лейла Жунисбекова on 09.02.2026.
//

import WidgetKit
import SwiftUI

@main
struct SmartReminderaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ReminderLiveActivity()
        if #available(iOS 17.0, *) {
            UpcomingReminderWidget()
        }
    }
}
