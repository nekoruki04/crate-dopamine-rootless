// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import UIKit

/// A connected display, by cable or AirPlay, as the VM's own screen rather
/// than a mirror of the iPhone's.
///
/// iOS mirrors an app onto a connected display until the app puts a window of
/// its own in the display's scene, one of the external display's role
/// (UISceneSession.Role.windowExternalDisplayNonInteractive). Up to iOS 26 iOS
/// offers that scene to every app, which takes it with a configuration for the
/// role in Info.plist (project.yml); crate's one scene at a time
/// (UIApplicationSupportsMultipleScenes off) doesn't stop it. From iOS 27, to
/// an app built with its SDK, iOS offers it only while one of the app's view
/// controllers has registered a scene accessory for it, which
/// ExternalDisplayRegistration does while MachineScreen is up. Either way the
/// scene comes to ExternalDisplaySceneDelegate, and the rest is the same.
///
/// crate's window goes on the display while MachineScreen is up, and comes off
/// once it's gone, when iOS mirrors again: crate's other screens are the
/// iPhone's. While it's on, the display shows the VM's screen, as big as fits
/// with its shape kept, and the guest's desktop takes the display's shape and
/// size instead of the view's (DisplayBridge.fitExternal). It's a picture only:
/// the iPhone or iPad stays where the person touches and types, over its own
/// copy of the picture.
///
/// An iPad using the display as a second desktop (Stage Manager) can have
/// crate's own window there instead, and the VM's screen takes that window's
/// shape as it would anywhere else.
@MainActor
final class ExternalDisplay {
    static let shared = ExternalDisplay()

    /// The VM's screen, while MachineScreen is up.
    private var bridge: DisplayBridge?
    /// The display's scene, while one is connected.
    private var scene: UIWindowScene?
    /// crate's window on it, while there are both.
    private var window: UIWindow?

    /// MachineScreen is up, its VM's screen in `bridge`, or gone (nil).
    func show(_ bridge: DisplayBridge?) {
        guard bridge !== self.bridge else { return }
        takeWindowOff()
        self.bridge = bridge
        putWindowOn()
    }

    fileprivate func connected(_ scene: UIWindowScene) {
        takeWindowOff()
        self.scene = scene
        let pixels = Self.pixels(of: scene.screen)
        AppLog.write("external display: connected, \(Int(pixels.width))x\(Int(pixels.height)) px")
        putWindowOn()
    }

    fileprivate func disconnected(_ scene: UIWindowScene) {
        guard scene === self.scene else { return }
        AppLog.write("external display: disconnected")
        takeWindowOff()
        self.scene = nil
    }

    private func putWindowOn() {
        guard let scene, let bridge, window == nil else { return }
        let screen = ExternalScreenController()
        let window = UIWindow(windowScene: scene)
        window.rootViewController = screen
        window.overrideUserInterfaceStyle = .dark
        // Shown, not made key: the keys stay with the iPhone's window.
        window.isHidden = false
        self.window = window
        bridge.connect(.external) { [weak screen] image in screen?.show(image) }
        bridge.fitExternal(Self.pixels(of: scene.screen))
    }

    private func takeWindowOff() {
        guard let window else { return }
        window.isHidden = true
        self.window = nil
        bridge?.disconnect(.external)
        bridge?.fitExternal(nil)
    }

    /// The display's size in pixels, in the mode it's in.
    private static func pixels(of screen: UIScreen) -> CGSize {
        screen.currentMode?.size ?? screen.nativeBounds.size
    }
}

/// The external display's scene, from Info.plist up to iOS 26 and from
/// ExternalDisplayRegistration's scene accessory after, handed to
/// ExternalDisplay.
final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        ExternalDisplay.shared.connected(scene)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        guard let scene = scene as? UIWindowScene else { return }
        ExternalDisplay.shared.disconnected(scene)
    }
}

/// What the external display shows: the VM's screen on black, as big as fits
/// with its shape kept. Before there's one, or once the VM has stopped, the
/// app's name, small.
final class ExternalScreenController: UIViewController {
    private let picture = CALayer()
    private let name = UILabel()

    override func loadView() {
        let view = UIView()
        view.backgroundColor = .black
        view.isUserInteractionEnabled = false
        picture.contentsGravity = .resizeAspect
        picture.magnificationFilter = .linear
        view.layer.addSublayer(picture)
        name.text = "crate"
        name.font = .preferredFont(forTextStyle: .headline)
        name.textColor = .secondaryLabel
        name.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(name)
        NSLayoutConstraint.activate([
            name.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            name.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        self.view = view
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        picture.frame = view.bounds
        CATransaction.commit()
    }

    func show(_ image: CGImage?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        picture.contents = image
        CATransaction.commit()
        name.isHidden = image != nil
    }
}

/// MachineScreen's part: while it's up, a connected display shows its VM's
/// screen. From iOS 27 it's also what has iOS offer the display's scene at
/// all, which takes a scene accessory registered on one of the app's view
/// controllers (UIViewController.registerSceneAccessory): this one. SwiftUI's
/// own sceneAccessory would make a scene of its own, where UIKit's brings it
/// to the same delegate as Info.plist does up to iOS 26.
struct ExternalDisplayRegistration: UIViewControllerRepresentable {
    let bridge: DisplayBridge

    func makeUIViewController(context: Context) -> Registrar {
        ExternalDisplay.shared.show(bridge)
        return Registrar()
    }

    func updateUIViewController(_ registrar: Registrar, context: Context) {}

    static func dismantleUIViewController(_ registrar: Registrar, coordinator: ()) {
        ExternalDisplay.shared.show(nil)
        registrar.unregister()
    }

    final class Registrar: UIViewController {
        /// The UISceneAccessoryRegistration, from iOS 27.
        private var registration: AnyObject?

        override func viewDidLoad() {
            super.viewDidLoad()
            view.isUserInteractionEnabled = false
        }

        func unregister() {
            registration = nil
        }
    }
}
