// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case install
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .home: "Home"
        case .install: "Install"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .install: "arrow.down.circle"
        case .settings: "gearshape"
        }
    }
}

/// The three tabs, and the running VM over them.
struct RootView: View {
    @Environment(JITSession.self) private var jit
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKey.jitAtLaunch) private var jitAtLaunch = true
    @AppStorage(SettingsKey.jitMethod) private var jitMethod = JITMethod.standard.rawValue

    /// Crate reopens on the tab it was left on.
    @SceneStorage("tab") private var tab = AppTab.home
    @State private var running: Machine?
    @State private var didLaunch = false
    @State private var fold = FoldSignals()
    /// A tab to open on regardless, from a launch argument.
    private let launchTab: AppTab?
    private let forceRail: Bool

    init(launchTab: AppTab? = nil, forceRail: Bool = false) {
        self.launchTab = launchTab
        self.forceRail = forceRail
    }

    /// The tabs go in a column on the right whenever the Duo is open in
    /// portrait, so they stay where they are when it's closed. Closed (and open
    /// in landscape) the system puts its own tab bar in that column; open in
    /// portrait it would put it at the bottom, so Crate draws the column itself.
    private var usesRail: Bool {
        forceRail || (fold.hasHinge && fold.verticalEdge == nil)
    }

    var body: some View {
        HStack(spacing: 0) {
            tabs
            if usesRail {
                TabRail(selection: $tab)
            }
        }
        .readFoldSignals($fold)
        .environment(\.hasHinge, fold.hasHinge)
        .fullScreenCover(item: $running) { machine in
            MachineScreen(machine: machine)
        }
        // Over the tabs; the VM screen, when it's up, shows its own.
        .sheet(isPresented: running == nil ? Bindable(jit).showingSetup : .constant(false)) {
            JITSetupView()
                .environment(jit)
        }
        .task { openLaunchTab() }
        .onChange(of: jit.state, initial: true) { launchSettled() }
        // Back from LocalDevVPN, if turning JIT on was waiting for it.
        .onChange(of: scenePhase) { if scenePhase == .active { jit.cameToFront() } }
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            HomeScreen(
                onStart: { running = $0 },
                onInstall: { tab = .install },
                onShowJIT: { tab = .settings })
            .tabItem {
                Label(AppTab.home.title, systemImage: AppTab.home.systemImage)
            }
            .tag(AppTab.home)
            .toolbar(usesRail ? .hidden : .automatic, for: .tabBar)

            InstallScreen(onShowHome: { tab = .home })
            .tabItem {
                Label(AppTab.install.title, systemImage: AppTab.install.systemImage)
            }
            .tag(AppTab.install)
            .toolbar(usesRail ? .hidden : .automatic, for: .tabBar)

            SettingsScreen()
            .tabItem {
                Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage)
            }
            .tag(AppTab.settings)
            .toolbar(usesRail ? .hidden : .automatic, for: .tabBar)
        }
    }

    private func openLaunchTab() {
        if let launchTab { tab = launchTab }
    }

    /// With nothing attached and "Turn on JIT when crate opens" set, JIT goes
    /// on at launch, once the launch's own check settles. No VM starts by
    /// itself: that's left to Start.
    private func launchSettled() {
        guard !didLaunch, jit.state != .checking else { return }
        didLaunch = true
        if !jit.isOn, jit.state == .off(.noDebugger), jitAtLaunch {
            Task { await jit.turnOn(JITMethod(rawValue: jitMethod) ?? .standard, interactive: false) }
        }
    }
}

private struct HasHingeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var hasHinge: Bool {
        get { self[HasHingeKey.self] }
        set { self[HasHingeKey.self] = newValue }
    }
}
