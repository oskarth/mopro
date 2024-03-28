
//
//  ExampleAppApp.swift
//  ExampleApp
//
//  Created by User Name on 3/6/24.
//

import SwiftUI

@main
struct ExampleAppApp: App {
    var body: some Scene {
        WindowGroup {
            // Enable the view you want
            //MultiplierCircuitView()
            //KeccakCircuitView()
            KeccakDylibCircuitView()
        }
    }
}
