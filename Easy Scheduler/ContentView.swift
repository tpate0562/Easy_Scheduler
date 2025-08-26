//
//  ContentView.swift
//  Easy Scheduler
//
//  Created by Tejas Patel on 8/24/25.
//

import SwiftUI
import CoreData
import UserNotifications

struct ContentView: View {
    enum SidebarItem: String, CaseIterable, Identifiable {
        case events = "Events"
        case settings = "Settings"
        case archived = "Archived"
        var id: String { self.rawValue }
    }
    @State private var selectedSidebar: SidebarItem? = .events
    @State private var showingAddEvent = false

    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selectedSidebar) { item in
                Label(item.rawValue, systemImage: {
                    switch item {
                    case .events:
                        return "calendar"
                    case .settings:
                        return "gear"
                    case .archived:
                        return "archivebox"
                    }
                }())
                .tag(item)
            }
            .navigationTitle("Menu")
        } detail: {
            Group {
                switch selectedSidebar {
                case .events:
                    EventsSection(showingAddEvent: $showingAddEvent)
                case .settings:
                    SettingsView()
                case .archived:
                    ArchivedEventsView()
                case nil:
                    Text("Select a menu item")
                }
            }
        }
        .sheet(isPresented: $showingAddEvent) {
            EventInputForm(isPresented: $showingAddEvent)
                .environment(\.managedObjectContext, viewContext)
        }
        .onAppear {
            autoArchivePastEvents(context: viewContext)
        }
    }
}

// Section: Events + Add button in toolbar
struct EventsSection: View {
    @Binding var showingAddEvent: Bool
    var body: some View {
        EventsListView()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddEvent = true
                    } label: {
                        Label("Add Event", systemImage: "plus")
                    }
                }
            }
    }
}

// Placeholder for Settings
struct SettingsView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "gear").font(.largeTitle)
            Text("Settings go here")
                .font(.title2)
            Spacer()
        }.padding()
    }
}

// Event input form as a modal sheet
struct EventInputForm: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var isPresented: Bool
    @State private var title: String = ""
    @State private var eventDate: Date = Date()
    @State private var startTime: Date = Date()
    @State private var useEndTime: Bool = false
    @State private var endTime: Date = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    @State private var notes: String = ""
    @State private var selectedIntervals: [Int] = []
    @State private var showAlert = false
    @State private var invalidEndTimeAlert = false
    let availableIntervals = [1, 5, 10, 15, 30, 60, 120, 360, 720, 1440, 2880, 10080, 20160]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Event Details")) {
                    TextField("Title", text: $title)
                    DatePicker("Date", selection: $eventDate, in: Date()..., displayedComponents: .date)
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                    Toggle("Set End Time", isOn: $useEndTime)
                    if useEndTime {
                        DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                    }
                    TextEditor(text: $notes)
                        .frame(height: 70)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                }
                Section(header: Text("Reminders (time before)")) {
                    ForEach(availableIntervals, id: \.self) { min in
                        Toggle(intervalLabel(for: min), isOn: Binding(
                            get: { selectedIntervals.contains(min) },
                            set: { isOn in
                                if isOn {
                                    selectedIntervals.append(min)
                                } else {
                                    selectedIntervals.removeAll { $0 == min }
                                }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("Add Event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEvent() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Event start time must be in the future.", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            }
            .alert("End time must be after start time.", isPresented: $invalidEndTimeAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }
    func saveEvent() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            showAlert = true
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let eventComponents = calendar.dateComponents([.year, .month, .day], from: eventDate)
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        var combinedComponents = DateComponents()
        combinedComponents.year = eventComponents.year
        combinedComponents.month = eventComponents.month
        combinedComponents.day = eventComponents.day
        combinedComponents.hour = startComponents.hour
        combinedComponents.minute = startComponents.minute
        guard let fullEventDate = calendar.date(from: combinedComponents), fullEventDate > now else {
            showAlert = true
            return
        }
        
        if useEndTime && !(endTime > startTime) {
            invalidEndTimeAlert = true
            return
        }
        let newEvent = Event(context: viewContext)
        newEvent.title = trimmedTitle
        newEvent.eventDate = eventDate
        newEvent.startTime = startTime
        newEvent.useEndTime = useEndTime
        newEvent.endTime = useEndTime ? endTime : nil
        newEvent.notes = notes
        newEvent.reminderIntervals = selectedIntervals.sorted()
        newEvent.isArchived = false
        do {
            try viewContext.save()
            scheduleNotifications(for: newEvent)
            isPresented = false
        } catch {
            // Handle error (show alert, etc.)
        }
    }
    
    private func scheduleNotifications(for event: Event) {
        guard let title = event.title as String?, let startTime = event.startTime else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            for interval in event.reminderIntervals {
                let triggerDate = Calendar.current.date(byAdding: .minute, value: -interval, to: startTime)
                guard let triggerDate, triggerDate > Date() else { continue }
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = "\(title) starts in \(intervalDescription(minutes: interval))"
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate),
                    repeats: false)
                let identifier = "\(event.objectID.uriRepresentation().absoluteString)-min-\(interval)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                center.add(request)
            }
        }
    }
    
    private func intervalDescription(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours) hour\(hours == 1 ? "" : "s")"
            } else {
                return "\(hours) hour\(hours == 1 ? "" : "s") \(mins) minute\(mins == 1 ? "" : "s")"
            }
        }
    }
    
    private func intervalLabel(for minutes: Int) -> String {
        if minutes % 10080 == 0 {
            let weeks = minutes / 10080
            if weeks == 1 {
                return "1 week"
            } else {
                return "\(weeks) weeks"
            }
        } else if minutes % 1440 == 0 {
            let days = minutes / 1440
            if days == 1 {
                return "1 day"
            } else {
                return "\(days) days"
            }
        } else if minutes % 60 == 0 {
            let hours = minutes / 60
            if hours == 1 {
                return "1 hour"
            } else {
                return "\(hours) hours"
            }
        } else {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }
}

// New View for Archived Events
struct ArchivedEventsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Event.eventDate, ascending: true)],
        predicate: NSPredicate(format: "isArchived == true")
    ) private var archivedEvents: FetchedResults<Event>
    
    var body: some View {
        List {
            if archivedEvents.isEmpty {
                Text("No archived events.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(archivedEvents, id: \.self) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title ?? "Untitled")
                            .font(.headline)
                        if let date = event.eventDate {
                            Text(date, style: .date)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        if let start = event.startTime {
                            Text("Start: \(start, formatter: timeFormatter)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        if event.useEndTime, let end = event.endTime {
                            Text("End: \(end, formatter: timeFormatter)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        if let notes = event.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("Archived Events")
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - Auto-archive past events

extension View {
    func autoArchivePastEvents(context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<Event> = Event.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isArchived == false")
        do {
            let events = try context.fetch(fetchRequest)
            var updated = false
            let now = Date()
            for event in events {
                if event.useEndTime, let end = event.endTime, end < now {
                    event.isArchived = true
                    updated = true
                } else if !event.useEndTime, let start = event.startTime, start < now {
                    event.isArchived = true
                    updated = true
                }
            }
            if updated {
                try context.save()
            }
        } catch {
            // Handle error appropriately if needed
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

// Reminder: Add `isArchived` Bool attribute to your Core Data Event entity with a default value of false and regenerate your Core Data classes to match.

