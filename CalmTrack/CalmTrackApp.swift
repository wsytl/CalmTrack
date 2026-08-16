//
//  CalmTrackApp.swift
//  CalmTrack
//
//  Created by tianli on 2026/5/2.
//

import SwiftUI
import Foundation
import CoreData

@main
struct CalmTrackApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            LaunchSplashGate {
                ContentView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            }
        }
    }
}
