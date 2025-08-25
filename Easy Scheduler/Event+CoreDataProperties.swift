import Foundation
import CoreData

extension Event: Identifiable {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Event> {
        return NSFetchRequest<Event>(entityName: "Event")
    }
    
    @NSManaged public var title: String
    @NSManaged public var eventDate: Date
    @NSManaged public var startTime: Date
    @NSManaged public var endTime: Date?
    @NSManaged public var useEndTime: Bool
    @NSManaged public var notes: String
    @NSManaged public var reminderIntervals: [Int]
    
    public var id: NSManagedObjectID {
        return objectID
    }
}
