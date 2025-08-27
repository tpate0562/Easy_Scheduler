import Foundation
import CoreData

extension Event {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Event> {
        NSFetchRequest<Event>(entityName: "Event")
    }

    @NSManaged public var title: String?
    @NSManaged public var eventDate: Date?
    @NSManaged public var startTime: Date?
    @NSManaged public var endTime: Date?
    @NSManaged public var useEndTime: Bool
    @NSManaged public var notes: String?
    @NSManaged public var reminderIntervals: [Int]
    @NSManaged public var isArchived: Bool
    @NSManaged public var repeatReminder: Bool
    @NSManaged public var repeatFrequency: Int64
}

extension Event: Identifiable { }

