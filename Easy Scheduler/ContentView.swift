//
//  ContentView.swift
//  Easy Scheduler
//
//  Created by Tejas Patel on 8/24/25.
//

import SwiftUI
import CoreData
import UserNotifications

// MARK: - Global Notification Scheduling Function

/// Schedules notifications for the given event based on its reminder intervals.
/// This function is reusable across the app and ensures consistent notification management.
private func scheduleNotifications(for event: Event) {
    guard let title = event.title as String?, let startTime = event.startTime else { return }
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
        guard granted else { return }
        
        // Remove any existing notifications for this event to avoid duplicates
        let identifiers = event.reminderIntervals.map { interval in
            "\(event.objectID.uriRepresentation().absoluteString)-min-\(interval)"
        }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        
        // Schedule notifications for each reminder interval
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

/// Helper to create a human-readable description of the interval.
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

struct ContentView: View {
    enum SidebarItem: String, CaseIterable, Identifiable {
        case events = "Events"
        case settings = "Settings"
        case archived = "Archived"
        var id: String { self.rawValue }
    }
    @State private var selectedSidebar: SidebarItem? = .events
    @State private var showingAddEvent = false
    @State private var showTimeline = false // New state var to toggle timeline view
    @State private var timelineDate: Date = Calendar.current.startOfDay(for: Date())

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
                    VStack(spacing: 0) {
                        if showTimeline {
                            TimelineView(date: $timelineDate)
                                .transition(.move(edge: .top).combined(with: .opacity))
                                .padding(.bottom, 8)
                        }
                        EventsSection(showingAddEvent: $showingAddEvent, showTimeline: $showTimeline)
                    }
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

// Section: Events + Add button in toolbar + New Timeline toggle button
struct EventsSection: View {
    @Binding var showingAddEvent: Bool
    @Binding var showTimeline: Bool // Binding to toggle timeline

    var body: some View {
        EventsListView()
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showingAddEvent = true
                    } label: {
                        Label("Add Event", systemImage: "plus")
                    }
                    Button {
                        withAnimation {
                            showTimeline.toggle()
                        }
                    } label: {
                        Image(systemName: "calendar.day.timeline.leading")
                    }
                    .help(showTimeline ? "Hide Timeline" : "Show Timeline")
                }
            }
    }
}

// MARK: - New TimelineView for day's events

struct TimelineView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var date: Date
    
    // Colors palette for events
    private let eventColors: [Color] = [
        .blue, .green, .orange, .purple, .pink, .red, .yellow, .teal, .indigo
    ]
    
    // Helper to get color for event by index
    private func color(for index: Int) -> Color {
        eventColors[index % eventColors.count]
    }
    
    // Fetch today's events sorted by startTime for the bound date
    @FetchRequest private var todayEvents: FetchedResults<Event>
    
    init(date: Binding<Date>) {
        _date = date
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date.wrappedValue)
        let endOfDay = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay)!
        
        let predicate = NSPredicate(format: "eventDate >= %@ AND eventDate <= %@ AND isArchived == false", startOfDay as NSDate, endOfDay as NSDate)
        let sortDescriptor = NSSortDescriptor(keyPath: \Event.startTime, ascending: true)
        _todayEvents = FetchRequest<Event>(entity: Event.entity(), sortDescriptors: [sortDescriptor], predicate: predicate)
    }
    
    // Converts a Date to a vertical offset in points (in 24h view)
    private func yOffset(for time: Date) -> CGFloat {
        // Map time of day to y position within 24h, 600 points height
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: time)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = components.second ?? 0
        let totalSeconds = hour * 3600 + minute * 60 + second
        let maxHeight: CGFloat = timelineHeight
        return CGFloat(totalSeconds) / 86400 * maxHeight
    }
    
    // Layout constants
    private let timelineHeight: CGFloat = 600
    private let containerPadding: CGFloat = 16
    private let maxWidth: CGFloat = 280
    private let minBarHeight: CGFloat = 30
    
    // Arrow side inset: decrease to move arrows outward (closer to edges), increase to move inward
    private let arrowSideInset: CGFloat = 6
    
    // Helper to determine if a color is dark (for text contrast)
    private func isColorDark(_ color: Color) -> Bool {
        // Approximate brightness calculation
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        // Perceived brightness formula
        let brightness = (red * 299 + green * 587 + blue * 114) / 1000
        return brightness < 0.5
    }
    
    // MARK: Overlap detection and grouping for events
    
    private struct PositionedEvent: Identifiable {
        let id: NSManagedObjectID
        let event: Event
        let index: Int
        let startY: CGFloat
        let height: CGFloat
        let endY: CGFloat
    }
    
    // Groups of overlapping events (each group is [PositionedEvent])
    private func groupOverlappingEvents(_ positionedEvents: [PositionedEvent]) -> [[PositionedEvent]] {
        var groups: [[PositionedEvent]] = []
        var currentGroup: [PositionedEvent] = []
        
        // Events are sorted by startY ascending
        for event in positionedEvents {
            if currentGroup.isEmpty {
                currentGroup.append(event)
            } else {
                // Check if event overlaps with any in currentGroup
                let overlaps = currentGroup.contains { $0.endY > event.startY }
                if overlaps {
                    currentGroup.append(event)
                } else {
                    groups.append(currentGroup)
                    currentGroup = [event]
                }
            }
        }
        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }
        return groups
    }
    
    @State private var showDatePicker = false
    
    var body: some View {
        VStack(spacing: 4) {
            // Header with tappable date (opens a date picker)
            HStack {
                Spacer()
                Button {
                    showDatePicker = true
                } label: {
                    Text(dateHeader)
                        .font(.headline.bold())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showDatePicker, arrowEdge: .top) {
                    VStack {
                        DatePicker(
                            "",
                            selection: $date,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .padding()
                    }
                    .frame(minWidth: 320, minHeight: 360)
                }
                Spacer()
            }
            .padding(.top, 4)
            .padding(.horizontal)
            .onChange(of: date) { _ in
                // Close picker after selecting a date
                showDatePicker = false
            }
            
            ZStack {
                // Scrollable timeline
                ScrollView(.vertical, showsIndicators: true) {
                    ZStack(alignment: .topLeading) {
                        // Background timeline with hour marks
                        VStack(spacing: 0) {
                            ForEach(0..<24) { hour in
                                HStack(spacing: 0) {
                                    Text("\(hour):00")
                                        .font(.caption2)
                                        .frame(width: 40, alignment: .trailing)
                                        .foregroundColor(.secondary)
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 1)
                                        .frame(maxWidth: .infinity)
                                }
                                .frame(height: timelineHeight / 24)
                            }
                        }
                        .frame(height: timelineHeight)
                        
                        // Prepare positions and sizes for events
                        let positionedEvents: [PositionedEvent] = todayEvents.enumerated().compactMap { index, event in
                            guard let start = event.startTime else {
                                return nil
                            }
                            let startY = yOffset(for: start)
                            var endY: CGFloat
                            if event.useEndTime, let end = event.endTime, end > start {
                                endY = yOffset(for: end)
                            } else {
                                endY = startY + minBarHeight
                            }
                            let height = max(endY - startY, minBarHeight)
                            
                            return PositionedEvent(id: event.objectID, event: event, index: index, startY: startY, height: height, endY: endY)
                        }.sorted { $0.startY < $1.startY }
                        
                        // Group events by overlapping vertical ranges
                        let groups = groupOverlappingEvents(positionedEvents)
                        
                        ForEach(groups.indices, id: \.self) { groupIndex in
                            let group = groups[groupIndex]
                            let groupStartY = group.map(\.startY).min() ?? 0
                            let groupEndY = group.map(\.endY).max() ?? 0
                            let groupHeight = groupEndY - groupStartY
                            
                            // Use a fixed-height ZStack to place items with exact vertical offsets
                            ZStack(alignment: .topLeading) {
                                ForEach(group) { positionedEvent in
                                    let fillColor = color(for: positionedEvent.index).opacity(0.6)
                                    let isDarkText = isColorDark(fillColor)
                                    let fgColor: Color = isDarkText ? .white : .black
                                    let fontSize: CGFloat = max(min(positionedEvent.height / 3, 14), 10)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(positionedEvent.event.title ?? "Untitled")
                                            .font(.system(size: fontSize, weight: .semibold))
                                            .foregroundColor(fgColor)
                                            .lineLimit(1)
                                        if let start = positionedEvent.event.startTime {
                                            if positionedEvent.event.useEndTime, let end = positionedEvent.event.endTime {
                                                HStack(spacing: 4) {
                                                    Text(start, formatter: timeFormatter)
                                                    Text("-")
                                                    Text(end, formatter: timeFormatter)
                                                }
                                                .font(.system(size: fontSize * 0.8))
                                                .foregroundColor(fgColor.opacity(0.85))
                                            } else {
                                                Text(start, formatter: timeFormatter)
                                                    .font(.system(size: fontSize * 0.8))
                                                    .foregroundColor(fgColor.opacity(0.85))
                                            }
                                        }
                                        if let notes = positionedEvent.event.notes, !notes.isEmpty {
                                            Text(notes)
                                                .font(.system(size: fontSize * 0.8))
                                                .foregroundColor(fgColor.opacity(0.85))
                                                .lineLimit(2)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(6)
                                    .frame(width: (maxWidth - CGFloat(group.count - 1) * 8) / CGFloat(group.count),
                                           height: positionedEvent.height,
                                           alignment: .topLeading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(fillColor)
                                            .shadow(radius: 2)
                                    )
                                    .offset(y: positionedEvent.startY - groupStartY) // precise vertical placement
                                }
                            }
                            .frame(width: maxWidth, height: groupHeight, alignment: .topLeading)
                            .position(x: 40 + maxWidth / 2 + containerPadding, y: groupStartY + groupHeight / 2)
                        }
                    }
                    .frame(minHeight: timelineHeight + 20)
                    .padding(.horizontal, containerPadding)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .shadow(radius: 4)
                )
                .padding([.leading, .trailing])
                // Re-enable only leftward swipes (right-to-left) starting away from the left edge
                .gesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .onEnded { value in
                            let horizontal = abs(value.translation.width) > abs(value.translation.height)
                            let startedAwayFromLeftEdge = value.startLocation.x > 60
                            if horizontal && value.translation.width < -40 && startedAwayFromLeftEdge {
                                withAnimation {
                                    date = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
                                }
                            }
                        }
                )
                
                // Overlay navigation arrows centered vertically
                HStack {
                    Button {
                        withAnimation {
                            date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
                        }
                    } label: {
                        Image(systemName: "arrow.left.circle")
                            .font(.title2)
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Previous Day")
                    
                    Spacer()
                    
                    Button {
                        withAnimation {
                            date = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
                        }
                    } label: {
                        Image(systemName: "arrow.right.circle")
                            .font(.title2)
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Next Day")
                }
                .padding(.horizontal, arrowSideInset) // tweak this to move arrows in/out
                .allowsHitTesting(true)
            }
        }
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    private var dateHeader: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: date)
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
    enum RepeatFrequency: Int, CaseIterable, Identifiable {
        case hour = 60
        case day = 1440
        case week = 10080
        case twoWeeks = 20160
        case month = 43200 // 30 days
        
        var id: Int { self.rawValue }
        var description: String {
            switch self {
            case .hour: return "1 Hour"
            case .day: return "1 Day"
            case .week: return "1 Week"
            case .twoWeeks: return "2 Weeks"
            case .month: return "1 Month"
            }
        }
    }
    
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
    
    @State private var repeatReminder: Bool = false
    @State private var repeatFrequency: RepeatFrequency? = nil
    
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
                Section {
                    Toggle("Repeat Reminder", isOn: $repeatReminder)
                    if repeatReminder {
                        ForEach(RepeatFrequency.allCases) { freq in
                            Button {
                                if repeatFrequency == freq {
                                    repeatFrequency = nil
                                } else {
                                    repeatFrequency = freq
                                }
                            } label: {
                                HStack {
                                    Text(freq.description)
                                    Spacer()
                                    if repeatFrequency == freq {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
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

        // Save repeatReminder and repeatFrequency
        newEvent.repeatReminder = repeatReminder
        newEvent.repeatFrequency = repeatFrequency.map { Int64($0.rawValue) } ?? 0

        do {
            try viewContext.save()
            // Use global function to schedule notifications
            scheduleNotifications(for: newEvent)
            isPresented = false
        } catch {
            // Handle error (show alert, etc.)
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
                    // If the event has repeatReminder and repeatFrequency > 0, create new event for next occurrence
                    if event.repeatReminder && event.repeatFrequency > 0 {
                        // Clone event and create next occurrence with updated dates/times
                        let newEvent = Event(context: context)
                        newEvent.title = event.title
                        newEvent.notes = event.notes
                        newEvent.isArchived = false
                        newEvent.repeatReminder = event.repeatReminder
                        newEvent.repeatFrequency = event.repeatFrequency
                        newEvent.reminderIntervals = event.reminderIntervals
                        newEvent.useEndTime = event.useEndTime
                        
                        // Calculate new startTime, endTime, and eventDate by adding repeatFrequency (in minutes)
                        let freqMinutes = Int(event.repeatFrequency)
                        if let oldStartTime = event.startTime {
                            if let newStartTime = Calendar.current.date(byAdding: .minute, value: freqMinutes, to: oldStartTime) {
                                newEvent.startTime = newStartTime
                                
                                // eventDate should be adjusted to the new startTime's day
                                newEvent.eventDate = Calendar.current.startOfDay(for: newStartTime)
                            }
                        }
                        if event.useEndTime, let oldEndTime = event.endTime {
                            if let newEndTime = Calendar.current.date(byAdding: .minute, value: freqMinutes, to: oldEndTime) {
                                newEvent.endTime = newEndTime
                            }
                        } else {
                            newEvent.endTime = nil
                        }
                        
                        // Schedule notifications for the new repeated event
                        scheduleNotifications(for: newEvent)
                        
                        updated = true
                    }
                    event.isArchived = true
                    updated = true
                } else if !event.useEndTime, let eventDate = event.eventDate, let startTime = event.startTime {
                    let calendar = Calendar.current
                    let eventDayComponents = calendar.dateComponents([.year, .month, .day], from: eventDate)
                    let startTimeComponents = calendar.dateComponents([.hour, .minute, .second], from: startTime)
                    var fullStartComponents = DateComponents()
                    fullStartComponents.year = eventDayComponents.year
                    fullStartComponents.month = eventDayComponents.month
                    fullStartComponents.day = eventDayComponents.day
                    fullStartComponents.hour = startTimeComponents.hour
                    fullStartComponents.minute = startTimeComponents.minute
                    fullStartComponents.second = startTimeComponents.second
                    if let fullStartDate = calendar.date(from: fullStartComponents), fullStartDate < now {
                        // If the event has repeatReminder and repeatFrequency > 0, create new event for next occurrence
                        if event.repeatReminder && event.repeatFrequency > 0 {
                            // Clone event and create new occurrence with updated dates/times
                            let newEvent = Event(context: context)
                            newEvent.title = event.title
                            newEvent.notes = event.notes
                            newEvent.isArchived = false
                            newEvent.repeatReminder = event.repeatReminder
                            newEvent.repeatFrequency = event.repeatFrequency
                            newEvent.reminderIntervals = event.reminderIntervals
                            newEvent.useEndTime = event.useEndTime
                            
                            // Calculate new startTime, endTime, and eventDate by adding repeatFrequency (in minutes)
                            let freqMinutes = Int(event.repeatFrequency)
                            if let oldStartTime = event.startTime {
                                if let newStartTime = Calendar.current.date(byAdding: .minute, value: freqMinutes, to: oldStartTime) {
                                    newEvent.startTime = newStartTime
                                    // eventDate should be adjusted to the new startTime's day
                                    newEvent.eventDate = Calendar.current.startOfDay(for: newStartTime)
                                }
                            }
                            if event.useEndTime, let oldEndTime = event.endTime {
                                if let newEndTime = Calendar.current.date(byAdding: .minute, value: freqMinutes, to: oldEndTime) {
                                    newEvent.endTime = newEndTime
                                }
                            } else {
                                newEvent.endTime = nil
                            }
                            
                            // Schedule notifications for the new repeated event
                            scheduleNotifications(for: newEvent)
                            
                            updated = true
                        }
                        event.isArchived = true
                        updated = true
                    }
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

// Reminder: Add `repeatReminder` Bool and `repeatFrequency` String attributes to your Core Data Event entity and regenerate your Core Data classes to match.

// Note: Future repeated notifications will be handled by the notification delegate; this code only schedules the initial notification(s).
