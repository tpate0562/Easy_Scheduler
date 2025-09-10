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

private extension View {
    @ViewBuilder
    func widgetContainerBackground() -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) {
                Color.clear
            }
        } else {
            self
        }
    }
}

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
    @Environment(\.widgetFamily) var family
    var entry: EasySchedulerEntry
    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                Image(systemName: "calendar.badge.plus")
                    .symbolRenderingMode(.hierarchical)
            case .accessoryRectangular:
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .symbolRenderingMode(.hierarchical)
                        .imageScale(.large)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("New Event")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                        Text("Tap to add")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            default:
                VStack(spacing: 6) {
                    Image(systemName: "calendar.badge.plus")
                        .imageScale(.large)
                    Text("New Event")
                        .font(.caption)
                }
            }
        }
        .widgetContainerBackground()
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
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .systemSmall, .systemMedium])
    }
}

