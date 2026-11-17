// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// The installed VMs, one large card each, paging vertically.
struct HomeScreen: View {
    @Environment(MachineStore.self) private var store
    @Environment(MachineRunner.self) private var runner

    let onStart: (Machine) -> Void
    let onInstall: () -> Void
    let onShowJIT: () -> Void

    @State private var deleting: Machine?
    @State private var editing: Machine?
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Each card's height, fixed while scrolling (see fixCardHeight).
    @State private var cardHeight: CGFloat?
    @State private var cardHeightScreen: CGSize = .zero

    var body: some View {
        NavigationStack {
            Group {
                if store.machines.isEmpty {
                    EmptyHome(onInstall: onInstall)
                } else {
                    cards
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("My VMs")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onShowJIT) {
                        JITBadge()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Install a VM", systemImage: "plus", action: onInstall)
                }
            }
            .confirmationDialog(
                "Delete \(deleting?.name ?? "")?",
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                titleVisibility: .visible,
                presenting: deleting
            ) { machine in
                Button("Delete VM", role: .destructive) {
                    // Not out from under it while it runs.
                    if runner.machineID == machine.id { runner.stop() }
                    store.delete(machine)
                }
            } message: { machine in
                Text("Its disk (\(Format.bytes(Int64(machine.diskUsedGB * 1e9)))) is removed from this iPhone. This can't be undone.")
            }
            .sheet(item: $editing) { machine in
                MachineSettingsSheet(machine: machine)
            }
        }
    }

    /// A card is 75% of the visible height, measured once per screen size.
    /// Measured continuously, cards grew as the title collapsed under a scroll.
    private func fixCardHeight(for viewport: Viewport) {
        guard cardHeight == nil || viewport.screen != cardHeightScreen else { return }
        cardHeightScreen = viewport.screen
        cardHeight = (viewport.visibleHeight * 0.75).rounded()
    }

    private var cards: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(store.machines) { machine in
                    MachineCard(
                        machine: machine,
                        onStart: { onStart(machine) },
                        onEditSettings: { editing = machine },
                        onDelete: { deleting = machine })
                    // At the accessibility text sizes a card grows to fit its text.
                    .frame(height: typeSize.isAccessibilitySize ? nil : cardHeight)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .onGeometryChange(for: Viewport.self) { proxy in
            Viewport(proxy)
        } action: { viewport in
            fixCardHeight(for: viewport)
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .contentMargins(.vertical, 12, for: .scrollContent)
    }
}

/// The scroll view's visible height, and the size of the whole screen area it
/// sits in. Scrolling collapses the large title, which grows the visible
/// height and shrinks the top inset by the same amount, so the whole stays put
/// until the screen really changes: rotation, or the Duo folding.
private struct Viewport: Equatable {
    let visibleHeight: CGFloat
    let screen: CGSize

    init(_ proxy: GeometryProxy) {
        visibleHeight = proxy.size.height
        let insets = proxy.safeAreaInsets
        screen = CGSize(width: proxy.size.width,
                        height: proxy.size.height + insets.top + insets.bottom)
    }
}

/// Whether this launch has JIT: a green dot and "JIT" when it does, gray when
/// it doesn't, a spinner while it's being checked or turned on. Color is never
/// the only sign: the label says it too.
struct JITBadge: View {
    @Environment(JITSession.self) private var jit
    @ScaledMetric(relativeTo: .subheadline) private var dotSize = 8

    var body: some View {
        HStack(spacing: 6) {
            if jit.isTurningOn || jit.state == .checking {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Circle()
                    .fill(jit.isOn ? AnyShapeStyle(.green) : AnyShapeStyle(.tertiary))
                    .frame(width: dotSize, height: dotSize)
            }
            Text("JIT")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(jit.isOn ? .primary : .secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(jit.isOn ? "JIT is on" : jit.isTurningOn ? "Turning JIT on" : "JIT is off")
        .accessibilityHint("Shows JIT settings")
    }
}

/// Home with nothing installed: points at the Install tab.
struct EmptyHome: View {
    let onInstall: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No VMs Yet", systemImage: "shippingbox")
        } description: {
            Text("Install Debian or Arch Linux to get started. It downloads once, then runs right on this iPhone.")
        } actions: {
            Button(action: onInstall) {
                Label("Install a VM", systemImage: "arrow.down.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
        }
    }
}
