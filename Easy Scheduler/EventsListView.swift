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
    @State private var showEditNotifications = false
    @State private var selectedIntervals: [Int] = []

    var body: some View {
        NavigationView {
            List {
                if events.isEmpty {
                    Text("No events yet.")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 40)
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
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteEvent(event)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                selectedIntervals = reminderIntervalsArray(from: event.reminderIntervals)
                                editingEvent = event
                                showEditNotifications = true
                            } label: {
                                Label("Edit Notifications", systemImage: "bell")
                            }.tint(.blue)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Your Events")
            .sheet(isPresented: $showEditNotifications) {
                if let editingEvent = editingEvent {
                    NotificationIntervalEditor(event: editingEvent, selectedIntervals: $selectedIntervals, onSave: { newIntervals in
                        updateNotificationIntervals(for: editingEvent, intervals: newIntervals)
                        showEditNotifications = false
                    })
                }
            }
        }
    }

    private func deleteEvent(_ event: Event) {
        viewContext.delete(event)
        do {
            try viewContext.save()
        } catch {
            // Handle error (show alert, etc.)
        }
    }

    private func updateNotificationIntervals(for event: Event, intervals: [Int]) {
        // Ensure 'reminderIntervals' is set as Transformable in the Core Data model to store an array.
        event.reminderIntervals = NSArray(array: intervals) as! [Int]
        do {
            try viewContext.save()
            rescheduleNotifications(for: event)
        } catch {
            // Handle error
        }
    }
    
    private func rescheduleNotifications(for event: Event) {
        guard let eventDate = event.eventDate else { return }
        let center = UNUserNotificationCenter.current()
        // Use event's objectID as the notification identifier root
        let identifierRoot = event.objectID.uriRepresentation().absoluteString
        
        // Remove all existing notifications for this event
        // Remove all with identifiers matching identifierRoot or identifierRoot-<interval>
        center.getPendingNotificationRequests { requests in
            let idsToRemove = requests.filter { $0.identifier.hasPrefix(identifierRoot) }.map { $0.identifier }
            center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
            
            let intervals = reminderIntervalsArray(from: event.reminderIntervals)
            
            for interval in intervals {
                guard interval > 0 else { continue }
                let triggerDate = Calendar.current.date(byAdding: .minute, value: -interval, to: eventDate)
                if let triggerDate {
                    let content = UNMutableNotificationContent()
                    content.title = event.title ?? "Event Reminder"
                    content.body = "Your event \(event.title ?? "") is coming up."
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
    }
}

// Editor sheet for picking intervals before the event (in minutes). Add this as a new struct in this file for now.
struct NotificationIntervalEditor: View {
    var event: Event
    @Binding var selectedIntervals: [Int]
    var onSave: ([Int]) -> Void
    @Environment(\.dismiss) private var dismiss

    // Example choices: 5, 10, 15, 30, 60 (customize as needed)
    let choices: [Int] = [5, 10, 15, 30, 60]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Remind me before event:")) {
                    ForEach(choices, id: \.self) { min in
                        Toggle("\(min) minutes", isOn: Binding(
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
            .navigationTitle("Edit Notifications")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(Array(Set(selectedIntervals)).sorted())
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Helper function to bridge transformable value to [Int]
private func reminderIntervalsArray(from obj: Any?) -> [Int] {
    (obj as? [NSNumber])?.map { $0.intValue } ?? []
}

#Preview {
    EventsListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
