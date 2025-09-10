// AddEventWidget.swift
// Easy Scheduler Widgets (Widget Extension)
//
// IMPORTANT:
// 1) Add this file to a new Widget Extension target named: "Easy Scheduler Widgets".
// 2) In the main app target (Easy Scheduler), add a URL Type with URL Schemes: "easyscheduler".
// 3) This widget uses .widgetURL(URL(string: "easyscheduler://create")) to deep link into the app.
// 4) Ensure the app handles the URL in SwiftUI via .onOpenURL in ContentView (already added).

import WidgetKit
import SwiftUI

// MARK: - Timeline
struct AddEventEntry: TimelineEntry {
    let date: Date
}

struct AddEventProvider: TimelineProvider {
    func placeholder(in context: Context) -> AddEventEntry { AddEventEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (AddEventEntry) -> Void) {
        completion(AddEventEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<AddEventEntry>) -> Void) {
        let entry = AddEventEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

// MARK: - Views
struct AddEventCircularView: View {
    var body: some View {
        ZStack {
            // Keep it simple for Lock Screen circular
            Image(systemName: "calendar.badge.plus")
                .symbolRenderingMode(.hierarchical)
        }
    }
}

struct AddEventRectangularView: View {
    var body: some View {
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
    }
}

// MARK: - Widget
struct AddEventWidget: Widget {
    let kind: String = "AddEventWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AddEventProvider()) { entry in
            // The container view chooses an appropriate subview per family
            GeometryReader { _ in
                Group {
                    switch WidgetFamily.current {
                    case .accessoryCircular:
                        AddEventCircularView()
                    case .accessoryRectangular:
                        AddEventRectangularView()
                    default:
                        // Fallback for other families if the widget is added to Home Screen
                        VStack(spacing: 8) {
                            Image(systemName: "calendar.badge.plus")
                                .imageScale(.large)
                            Text("New Event")
                                .font(.caption)
                        }
                    }
                }
                // Deep link into the app's create screen
                .widgetURL(URL(string: "easyscheduler://create"))
            }
        }
        .configurationDisplayName("Add Event")
        .description("Quickly create a new event from your Lock Screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .systemSmall])
    }
}

@main
struct EasySchedulerWidgetBundle: WidgetBundle {
    var body: some Widget {
        AddEventWidget()
    }
}
