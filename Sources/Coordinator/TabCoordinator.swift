//
//  TabCoordinator.swift
//  Radiant Tap Essentials
//
//  Copyright © 2026 Radiant Tap
//  MIT License · http://choosealicense.com/licenses/mit/
//

import UIKit

///	Coordinator that manages a `UITabBarController` where each tab is backed
///	by its own child coordinator.
///
///	Callers build each `UITab` themselves (so they can use `UISearchTab`,
///	`UITabGroup`, placement, images, badges, liquid-glass styling — the full
///	iOS 18+ tab surface without TabCoordinator mediating) and pair it with
///	the owning `Coordinating`. The typical pattern:
///
///	```swift
///	let home = HomeCoordinator(...)
///	let homeTab = UITab(title: "Home", image: UIImage(systemName: "house"),
///	                    identifier: "home") { _ in
///	    home.anyRootViewController
///	}
///	tabCoordinator.setTabs([
///	    .init(tab: homeTab, coordinator: home),
///	    // ...
///	])
///	```
///
///	TabCoordinator then handles the lifecycle: starting each child on `start()`,
///	stopping them on `stop()`, installing the `UITab` array on the root
///	`UITabBarController`, and calling `activate()` on the coordinator that
///	owns the newly-selected tab so the responder chain and any pop-back
///	bookkeeping point at the right place.
///
///	Intentionally thin:
///	- Modal presentation from within a tab is the child navigation
///	  coordinator's job, not this one's.
///	- `coordinatorDidFinish` keeps the inherited default: tabs don't "finish"
///	  the way a pushed flow does, so there's nothing tab-specific to do.
@MainActor
open class TabCoordinator: Coordinator<UITabBarController>, UITabBarControllerDelegate {

	///	Pairing of a pre-built `UITab` with the coordinator that drives its content.
	public struct Tab {
		public let tab: UITab
		public let coordinator: Coordinating

		public init(tab: UITab, coordinator: Coordinating) {
			self.tab = tab
			self.coordinator = coordinator
		}
	}

	public private(set) var tabs: [Tab] = []

	//	MARK: Configuration

	///	Install the ordered set of tabs. Call this before `start()`.
	open func setTabs(_ tabs: [Tab]) {
		self.tabs = tabs
	}

	//	MARK: Lifecycle

	open override func start() {
		rootViewController.delegate = self

		for entry in tabs {
			startChild(coordinator: entry.coordinator)
		}
		rootViewController.tabs = tabs.map(\.tab)

		super.start()
	}

	open override func stop() {
		rootViewController.delegate = nil

		for entry in tabs {
			stopChild(coordinator: entry.coordinator)
		}
		tabs.removeAll()

		super.stop()
	}

	//	MARK: Selection

	///	Activates the coordinator owning the newly-selected tab.
	///
	///	It is strongly advised not to override this method; override
	///	`handleTabSelection(_:previous:)` instead if you need to react to
	///	tab switches.
	open func tabBarController(_ tabBarController: UITabBarController,
							   didSelectTab tab: UITab,
							   previousTab: UITab?) {
		guard let entry = tabs.first(where: { $0.tab === tab }) else { return }
		entry.coordinator.activate()
		handleTabSelection(tab, previous: previousTab)
	}

	///	Hook for subclasses that need to react to tab switches (analytics,
	///	deep-link handoff, etc.). Default implementation does nothing.
	open func handleTabSelection(_ tab: UITab, previous: UITab?) {
	}
}
