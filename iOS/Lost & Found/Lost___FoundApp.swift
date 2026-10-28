//
//  Lost___FoundApp.swift
//  Lost & Found
//
//  Created by Zyaire Bush on 9/3/26.
//

import SwiftUI

@main
struct Lost_FoundApp: App {
    @StateObject private var authSession = AuthSession()

    var body: some Scene {
        WindowGroup {
            AuthGateView()
                .environmentObject(authSession)
        }
    }
}
