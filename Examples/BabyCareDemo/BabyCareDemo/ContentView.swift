//
//  ContentView.swift
//  BabyCareDemo
//
//  Main tab-based navigation
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("홈", systemImage: "house.fill")
                }
                .tag(0)

            RemindersView()
                .tabItem {
                    Label("미리 알림", systemImage: "checklist")
                }
                .tag(1)

            EventsView()
                .tabItem {
                    Label("일정", systemImage: "calendar")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("설정", systemImage: "gear")
                }
                .tag(3)
        }
    }
}

#Preview {
    ContentView()
}
