//
//  Event+CoreDataProperties.swift
//  Easy Scheduler
//
//  Created by Tejas Patel on 8/25/25.
//
//

public import Foundation
public import CoreData


public typealias EventCoreDataPropertiesSet = NSSet

extension Event {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Event> {
        return NSFetchRequest<Event>(entityName: "Event")
    }

    @NSManaged public var title: String?
    @NSManaged public var eventDate: Date?
    @NSManaged public var startTime: Date?
    @NSManaged public var endTime: Date?
    @NSManaged public var useEndTime: Bool
    @NSManaged public var notes: String?
    @NSManaged public var reminderIntervals: Int64

}

extension Event : Identifiable {

}
