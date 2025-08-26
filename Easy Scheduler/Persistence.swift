import CoreData
import Foundation

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // Seed some sample Events for previews
        for i in 0..<10 {
            let e = Event(context: viewContext)
            e.title = "Sample Event \(i + 1)"
            e.eventDate = Date()
            e.startTime = Date()
            e.endTime = Calendar.current.date(byAdding: .hour, value: 1, to: e.startTime!)
            e.useEndTime = true            // non-optional Bool → must set a value
            e.notes = "Preview seed"
            e.reminderIntervals = []       // Assign an empty array to satisfy [Int] type
        }

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Easy_Scheduler")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
