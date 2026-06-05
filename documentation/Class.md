[Coordinator](../README.md) : the [Pattern](Pattern.md) · the [Library](Library.md) · the **Class** · recommended [Implementation](Implement.md)

## Coordinator: the class

`Coordinator` class is parameterized with UIViewController subclass it uses as root VC. 
(`Coordinating` protocol exists mainly to avoid issues with generic classes and collections.)

```swift
open class Coordinator<T: UIViewController>: UIResponder, Coordinating {
	public init(rootViewController: T) { ... }
	
	open override var coordinatingResponder: UIResponder? {
		return parent as? UIResponder
	}
}
```

Since apps can be fairly complex, each Coordinator can have an unlimited number of child Coordinators. Thus you can have `AccountCoordinator`, `PaymentCoordinator`, `CartCoordinator`, `CatalogCoordinator` and so on. There are no rules nor guidelines: group your related app screens under particular Coordinator umbrella as you see fit.

When you instantiate a Coordinator instance, you call `start()` to use it and `stop()` when it’s no longer needed.

In the Coordinator subclass, you’ll override the method you defined in the UIResponder extension and actually do something useful instead of just calling the same method on next `coordinatingResponder`.

### NavigationCoordinator

The first concrete subclass this library offers, and the one you'll subclass most often.

It uses `UINavigationController` as root VC and it keeps references to shown UIVCs in its own `viewControllers` property. This property shadows UINavigationController’s property of the same name but it is not cleared out until the NavigationCoordinator is stopped. This allows you to replace one NavigationCoordinator instance with another and saving and restoring their stack of UIVC instances in the process.

If offers all the methods you may need when working with navigation pattern:

· `root(_ vc: UIViewController)‌` — replaces entire navigation stack with just this one given UIVC. Perfect when switching from one multi-screen user flow (like say account creation process) to single view (say account confirmation code screen)

· `show(_ vc: UIViewController)` — same as navigationController.show().

· `top(_ vc: UIViewController)‌` — replace the visible UIVC with the given one. Does not replace entire navigation stack, just the last UIVC (which is currently visible)

· `‌pop(to vc: UIViewController, animated: Bool = true)` — programmatically pop the stack to the given UIVC instance, which should exist in the navigation stack.

· `‌present(_ vc: UIViewController, animated: Bool = true, completion: (() -> Void)? = nil)` — `NavigationCoordinator` will setup itself as `parentCoordinator` for the given `vc` and then its root UINavigationController will present that `vc`. An `async` overload `present(_:animated:)` is also available for callers using structured concurrency.

· `‌dismiss(animated: Bool = true, completion: (() -> Void)? = nil)` — dismiss the currently presented UIVC. An `async` overload `dismiss(animated:)` is also available.

NavigationController gives you a chance to react to the customer tap on the Back button. Simply override this method and update your internal state:

· `‌handlePopBack(to vc: UIViewController?)`

### TabCoordinator

Manages a `UITabBarController` where each tab is backed by its own child coordinator (typically a `NavigationCoordinator`).

On iOS 18, tvOS 18, visionOS 2 and later, callers build each `UITab` themselves — including `UISearchTab`, `UITabGroup` for the iPad sidebar, placement, badges, and the iOS 26 liquid-glass styling — and pair it with the owning `Coordinating`:

```swift
let home = HomeCoordinator(...)
let homeTab = UITab(title: "Home", image: UIImage(systemName: "house"),
                    identifier: "home") { _ in
    home.anyRootViewController
}
tabCoordinator.setTabs([
    .init(tab: homeTab, coordinator: home),
    // ...
])
tabCoordinator.start()
```

On iOS versions below 18 (down to the package minimum) there is no `UITab`. Use the primitive fallback initializer instead, supplying title, image, and optional badge:

```swift
tabCoordinator.setTabs([
    .init(title: "Home", image: UIImage(systemName: "house"), coordinator: home),
    // ...
])
```

`TabCoordinator` then synthesizes the per-version plumbing: a `UITabBarItem` installed via `UITabBarController.viewControllers` pre-18, or a promoted `UITab` on iOS 18+. The richer iOS 18 tab surface (`UISearchTab`, `UITabGroup`, …) is unavailable through this fallback — it carries only title, image, and badge.

`TabCoordinator.start()` then starts each child, installs the tabs on the root `UITabBarController`, and assigns itself as the delegate. When the customer switches tabs, the owning coordinator receives `activate()` so the responder chain and any pop-back bookkeeping point at the right place.

It deliberately does **not** expose `present` / `dismiss`: modal presentation from inside a tab is the child navigation coordinator's job. It also keeps the inherited default for `coordinatorDidFinish`, since tabs don't "finish" the way a pushed flow does.

Override this hook to react to tab switches without touching the delegate method:

· `‌handleTabSelection(_ selected: Tab, previous: Tab?)` — `previous` is `nil` on iOS versions below 18, where the platform only reports the newly-selected tab.

The `anyRootViewController` property used in the `UITab` provider above is a type-erased accessor on the `Coordinating` protocol. Concrete coordinators continue to expose their strongly-typed `rootViewController: T` property; `anyRootViewController` exists for code that holds a `Coordinating` existential and needs to reach the underlying view controller without casting.