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
///	On iOS 18+ callers build each `UITab` themselves (so they can use
///	`UISearchTab`, `UITabGroup`, placement, images, badges, liquid-glass styling
///	— the full iOS 18+ tab surface without TabCoordinator mediating) and pair it
///	with the owning `Coordinating`. The typical pattern:
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
///	On iOS versions below 18 (down to the package minimum) there is no `UITab`,
///	so use the `Tab(title:image:badgeValue:coordinator:)` initializer instead.
///	TabCoordinator then synthesizes the per-version plumbing: a `UITabBarItem`
///	installed via `UITabBarController.viewControllers` pre-18, or a promoted
///	`UITab` on iOS 18+. The richer iOS 18 tab surface is unavailable through this
///	fallback — it carries only title, image, and badge.
///
///	TabCoordinator handles the lifecycle: starting each child on `start()`,
///	stopping them on `stop()`, installing the tabs on the root
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
	
	///	Pairing of a tab's presentation with the coordinator that drives its content.
	///
	///	Construct it either from a pre-built `UITab` (iOS 18+, full tab surface)
	///	or from plain title/image/badge primitives (iOS 15+ fallback).
	@MainActor
	public struct Tab {
		public let coordinator: Coordinating
		
		///	How this tab describes itself, kept version-neutral so the enclosing
		///	struct doesn't require iOS 18. The `.tab` case boxes a `UITab` (only
		///	reachable through the iOS 18-gated initializer); the `.item` case
		///	carries primitives usable on every supported OS version.
		private let descriptor: Descriptor
		
		private enum Descriptor {
			case tab(Any)	//	UITab, iOS 18+
			case item(title: String?, image: UIImage?, badgeValue: String?)
		}
		
		///	iOS 18+ tab built by the caller, giving full access to the modern tab
		///	surface (`UISearchTab`, `UITabGroup`, placement, liquid-glass, …).
		@available(iOS 18, tvOS 18, visionOS 2, *)
		public init(tab: UITab, coordinator: Coordinating) {
			self.coordinator = coordinator
			self.descriptor = .tab(tab)
		}
		
		///	iOS 15+ fallback. TabCoordinator builds the `UITabBarItem` (pre-18) or
		///	a synthesized `UITab` (18+) from these primitives.
		public init(title: String?, image: UIImage?, badgeValue: String? = nil, coordinator: Coordinating) {
			self.coordinator = coordinator
			self.descriptor = .item(title: title, image: image, badgeValue: badgeValue)
		}
		
		///	The caller-supplied `UITab`, or `nil` if this tab was built from the
		///	primitive fallback initializer.
		@available(iOS 18, tvOS 18, visionOS 2, *)
		public var tab: UITab? {
			if case let .tab(boxed) = descriptor { return boxed as? UITab }
			return nil
		}
		
		///	Returns the caller's `UITab` as-is, or synthesizes one from the
		///	primitives. Each call on a `.item` descriptor produces a fresh
		///	instance, so the result must be cached by the caller when instance
		///	identity matters (e.g. selection matching).
		@available(iOS 18, tvOS 18, visionOS 2, *)
		func makeUITab() -> UITab {
			switch descriptor {
				case let .tab(boxed):
					return boxed as! UITab
				case let .item(title, image, badgeValue):
					let uiTab = UITab(title: title ?? "", image: image, identifier: coordinator.identifier) { [coordinator] _ in
						coordinator.anyRootViewController
					}
					uiTab.badgeValue = badgeValue
					return uiTab
			}
		}
		
		///	Pre-18 installation: configures the content view controller's
		///	`tabBarItem` from the primitives. A `.tab` descriptor is unreachable
		///	here (its initializer is gated to iOS 18+), so it leaves whatever
		///	`tabBarItem` the view controller already has.
		func configureTabBarItem(at index: Int) {
			guard case let .item(title, image, badgeValue) = descriptor else { return }
			let item = UITabBarItem(title: title, image: image, tag: index)
			item.badgeValue = badgeValue
			coordinator.anyRootViewController.tabBarItem = item
		}
	}
	
	public private(set) var tabs: [Tab] = []
	
	///	The `UITab` instances installed on the root controller (iOS 18+), kept so
	///	selection can be matched back to the owning `Tab` by instance identity.
	private var installedTabs: [Any] = []
	
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
		
		if #available(iOS 18, tvOS 18, visionOS 2, *) {
			let built = tabs.map { $0.makeUITab() }
			installedTabs = built
			rootViewController.tabs = built
		} else {
			for (index, entry) in tabs.enumerated() {
				entry.configureTabBarItem(at: index)
			}
			rootViewController.viewControllers = tabs.map { $0.coordinator.anyRootViewController }
		}
		
		super.start()
	}
	
	open override func stop() {
		rootViewController.delegate = nil
		
		for entry in tabs {
			stopChild(coordinator: entry.coordinator)
		}
		tabs.removeAll()
		installedTabs.removeAll()
		
		super.stop()
	}
	
	//	MARK: Selection
	
	///	Activates the coordinator owning the newly-selected tab (iOS 18+).
	///
	///	It is strongly advised not to override this method; override
	///	`handleTabSelection(_:previous:)` instead if you need to react to
	///	tab switches.
	@available(iOS 18, tvOS 18, visionOS 2, *)
	open func tabBarController(
		_ tabBarController: UITabBarController,
		didSelectTab tab: UITab,
		previousTab: UITab?
	){
		guard let index = installedTabs.firstIndex(where: { ($0 as? UITab) === tab }) else { return }
		let selected = tabs[index]
		selected.coordinator.activate()
		
		let previous: Tab? = previousTab
			.flatMap { p in installedTabs.firstIndex(where: { ($0 as? UITab) === p }) }
			.map { tabs[$0] }
		handleTabSelection(selected, previous: previous)
	}
	
	///	Activates the coordinator owning the newly-selected tab (pre-18).
	///
	///	It is strongly advised not to override this method; override
	///	`handleTabSelection(_:previous:)` instead if you need to react to
	///	tab switches.
	open func tabBarController(
		_ tabBarController: UITabBarController,
		didSelect viewController: UIViewController
	){
		//	On iOS 18+ selection arrives through `didSelectTab:previousTab:`;
		//	bail so we don't activate twice when the modern tabs are installed.
		if #available(iOS 18, tvOS 18, visionOS 2, *), !installedTabs.isEmpty {
			return
		}
		
		guard let entry = tabs.first(where: { $0.coordinator.anyRootViewController === viewController }) else { return }
		entry.coordinator.activate()
		handleTabSelection(entry, previous: nil)
	}
	
	///	Hook for subclasses that need to react to tab switches (analytics,
	///	deep-link handoff, etc.). Default implementation does nothing.
	///
	///	`previous` is `nil` on iOS versions below 18, where the platform only
	///	reports the newly-selected tab.
	open func handleTabSelection(_ selected: Tab, previous: Tab?) {
	}
}
