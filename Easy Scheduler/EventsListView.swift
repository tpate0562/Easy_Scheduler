import SwiftUI
import CoreData
import UserNotifications

struct EventsListView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Event.eventDate, ascending: true), NSSortDescriptor(keyPath: \Event.startTime, ascending: true)],
        predicate: NSPredicate(format: "isArchived == false"),
        animation: .default)
    private var events: FetchedResults<Event>
    @Environment(\.managedObjectContext) private var viewContext

    @State private var editingEvent: Event?
    @State private var showEditEvent = false

    var body: some View {
        NavigationView {
            List {
                if events.isEmpty {
                    Text("No events yet.")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)
                } else {
                    ForEach(events) { event in
                        HStack(alignment: .top, spacing: 16) {
                            VStack {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 10, height: 10)
                                Rectangle()
                                    .fill(Color.accentColor.opacity(0.2))
                                    .frame(width: 2)
                                    .frame(maxHeight: .infinity)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text(event.title ?? "(No Title)")
                                    .font(.title3.bold())
                                if let date = event.eventDate {
                                    Text(date.formatted(date: .long, time: .omitted))
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                                if let start = event.startTime {
                                    HStack(spacing: 12) {
                                        Text("Start: " + start.formatted(date: .omitted, time: .shortened))
                                        if event.useEndTime, let end = event.endTime {
                                            Text("End: " + end.formatted(date: .omitted, time: .shortened))
                                        }
                                    }.font(.callout)
                                }
                                if let notes = event.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.footnote)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            Spacer()
                        }
                        .background(Color(.systemBackground))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteEvent(event)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                editingEvent = event
                                showEditEvent = true
                            } label: {
                                Label("Edit Event", systemImage: "pencil")
                            }.tint(.blue)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .padding(.top, 0)
            .navigationTitle("Your Events")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showEditEvent) {
                if let editingEvent = editingEvent {
                    EventEditForm(event: editingEvent) { updatedEvent in
                        // Save and reschedule notifications after editing
                        do {
                            try viewContext.save()
                            rescheduleNotifications(for: updatedEvent)
                        } catch {
                            // Handle error
                        }
                        showEditEvent = false
                    } onCancel: {
                        showEditEvent = false
                    }
                } else {
                    EmptyView()
                }
            }
        }
    }

    private func deleteEvent(_ event: Event) {
        // Also remove any pending notifications for this event
        let center = UNUserNotificationCenter.current()
        let identifierRoot = event.objectID.uriRepresentation().absoluteString
        center.getPendingNotificationRequests { requests in
            let idsToRemove = requests.filter { $0.identifier.hasPrefix(identifierRoot) }.map { $0.identifier }
            center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
        }

        viewContext.delete(event)
        do {
            try viewContext.save()
        } catch {
            // Handle error (show alert, etc.)
        }
    }

    // Merge eventDate and startTime into a single Date representing the actual start date/time.
    private func fullStartDate(for event: Event) -> Date? {
        guard let eventDate = event.eventDate, let startTime = event.startTime else { return nil }
        let calendar = Calendar.current
        let day = calendar.dateComponents([.year, .month, .day], from: eventDate)
        let time = calendar.dateComponents([.hour, .minute, .second], from: startTime)
        var combined = DateComponents()
        combined.year = day.year
        combined.month = day.month
        combined.day = day.day
        combined.hour = time.hour
        combined.minute = time.minute
        combined.second = time.second
        return calendar.date(from: combined)
    }

    private func rescheduleNotifications(for event: Event) {
        guard let startDate = fullStartDate(for: event) else { return }
        let center = UNUserNotificationCenter.current()
        let identifierRoot = event.objectID.uriRepresentation().absoluteString

        center.getPendingNotificationRequests { requests in
            let idsToRemove = requests.filter { $0.identifier.hasPrefix(identifierRoot) }.map { $0.identifier }
            center.removePendingNotificationRequests(withIdentifiers: idsToRemove)

            let intervals = event.reminderIntervals
            for interval in intervals {
                guard interval >= 0 else { continue }
                guard let triggerDate = Calendar.current.date(byAdding: .minute, value: -interval, to: startDate) else { continue }
                if triggerDate <= Date() { continue }

                let content = UNMutableNotificationContent()
                let title = event.title ?? "Event Reminder"
                content.title = title
                content.body = "\(title) starts in \(intervalDescription(minutes: interval))"
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate),
                    repeats: false)

                let requestID = "\(identifierRoot)-min-\(interval)"
                let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
                center.add(request) { err in
                    if let err = err {
                        print("Error scheduling notification for interval \(interval):", err)
                    }
                }
            }
        }
    }

    private func intervalDescription(minutes: Int) -> String {
        if minutes % 10080 == 0 {
            let weeks = minutes / 10080
            return weeks == 1 ? "1 week" : "\(weeks) weeks"
        } else if minutes % 1440 == 0 {
            let days = minutes / 1440
            return days == 1 ? "1 day" : "\(days) days"
        } else if minutes % 60 == 0 {
            let hours = minutes / 60
            return hours == 1 ? "1 hour" : "\(hours) hours"
        } else {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }
}

// Full edit form for an existing event
struct EventEditForm: View {
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
    @Environment(\.dismiss) private var dismiss

    var event: Event
    var onSave: (Event) -> Void
    var onCancel: () -> Void

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

    init(event: Event, onSave: @escaping (Event) -> Void, onCancel: @escaping () -> Void) {
        self.event = event
        self.onSave = onSave
        self.onCancel = onCancel
        // _state will be set in .onAppear to read latest values from Core Data
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Event Details")) {
                    TextField("Title", text: $title)
                    DatePicker("Date", selection: $eventDate, in: Date()..., displayedComponents: .date)
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                    Toggle("Set End Time", isOn: $useEndTime)
                    if useEndTime {
                        DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
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
            .navigationTitle("Edit Event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Event start time must be in the future.", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            }
            .alert("End time must be after start time.", isPresented: $invalidEndTimeAlert) {
                Button("OK", role: .cancel) { }
            }
            .onAppear {
                loadFromEvent()
            }
        }
    }

    private func loadFromEvent() {
        title = event.title ?? ""
        eventDate = event.eventDate ?? Date()
        startTime = event.startTime ?? Date()
        useEndTime = event.useEndTime
        endTime = event.endTime ?? Calendar.current.date(byAdding: .hour, value: 1, to: startTime) ?? startTime
        notes = event.notes ?? ""
        selectedIntervals = event.reminderIntervals
        repeatReminder = event.repeatReminder
        repeatFrequency = RepeatFrequency(rawValue: Int(event.repeatFrequency))
    }

    private func saveChanges() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            showAlert = true
            return
        }

        // Compute the full start date/time for validation
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

        // Apply changes to the existing event
        event.title = trimmedTitle
        event.eventDate = eventDate
        event.startTime = startTime
        event.useEndTime = useEndTime
        event.endTime = useEndTime ? endTime : nil
        event.notes = notes
        event.reminderIntervals = Array(Set(selectedIntervals)).sorted()
        event.repeatReminder = repeatReminder
        event.repeatFrequency = repeatFrequency.map { Int64($0.rawValue) } ?? 0

        onSave(event)
        dismiss()
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

#Preview {
    EventsListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
