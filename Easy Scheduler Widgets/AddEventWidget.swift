//
//  EasySchedulerLockScreenWidget.swift
//
//  This file should be added to a new Widget Extension target named "Easy Scheduler Widgets".
//  The main app must declare a URL scheme "easyscheduler" in Info > URL Types for the deep link to work.
//
//  Lock Screen accessory widget showing a calendar with a plus badge,
//  deep linking into the app via the URL scheme easyscheduler://create.
//

import WidgetKit
import SwiftUI

struct EasySchedulerEntry: TimelineEntry {
    let date: Date
}

struct EasySchedulerProvider: TimelineProvider {
    func placeholder(in context: Context) -> EasySchedulerEntry {
        EasySchedulerEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (EasySchedulerEntry) -> Void) {
        completion(EasySchedulerEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EasySchedulerEntry>) -> Void) {
        let entry = EasySchedulerEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct EasySchedulerWidgetEntryView: View {
    var entry: EasySchedulerEntry
    var body: some View {
        Image(systemName: "calendar.badge.plus")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.primary, .blue)
            .widgetURL(URL(string: "easyscheduler://create"))
    }
}

@main
struct EasySchedulerLockScreenWidget: Widget {
    let kind: String = "EasySchedulerLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EasySchedulerProvider()) { entry in
            EasySchedulerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Easy Scheduler")
        .description("Quickly create new schedules from the Lock Screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}
