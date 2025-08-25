import Foundation
import CoreData

@objc(Event)
public class Event: NSManagedObject {
    @NSManaged public var title: String
    @NSManaged public var eventDate: Date
    @NSManaged public var startTime: Date
    @NSManaged public var endTime: Date?
    @NSManaged public var useEndTime: Bool
    @NSManaged public var notes: String
    @NSManaged public var reminderIntervals: [Int]
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        title = ""
        eventDate = Date()
        startTime = Date()
        endTime = nil
        useEndTime = false
        notes = ""
        reminderIntervals = []
    }
}

extension Event {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Event> {
        return NSFetchRequest<Event>(entityName: "Event")
    }
}
