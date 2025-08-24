//
//  Easy_SchedulerApp.swift
//  Easy Scheduler
//
//  Created by Tejas Patel on 8/24/25.
//

import SwiftUI
import CoreData

@main
struct Easy_SchedulerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
