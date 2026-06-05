//
//  UIKit-CoordinatingExtensions.swift
//  Radiant Tap Essentials
//
//  Copyright © 2016 Radiant Tap
//  MIT License · http://choosealicense.com/licenses/mit/
//

import UIKit

/**
 Injects `parentCoordinator` property into `UIViewController`.
 */

extension UIViewController {
    private class WeakCoordinatingTrampoline: NSObject {
        weak var coordinating: Coordinating?
    }

	@MainActor
    private struct AssociatedKeys {
		//	per: https://github.com/atrick/swift-evolution/blob/diagnose-implicit-raw-bitwise/proposals/nnnn-implicit-raw-bitwise-conversion.md#workarounds-for-common-cases
		static var ParentCoordinator: Void?
    }

    public weak var parentCoordinator: Coordinating? {
        get {
            let trampoline = objc_getAssociatedObject(self, &AssociatedKeys.ParentCoordinator) as? WeakCoordinatingTrampoline
            return trampoline?.coordinating
        }
        set {
            let trampoline = WeakCoordinatingTrampoline()
            trampoline.coordinating = newValue
            objc_setAssociatedObject(self, &AssociatedKeys.ParentCoordinator, trampoline, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}




extension UIResponder {
	/**
	 Driving vessel for easy method calling and value passing *upwards* and *downwards* through any hierarchy in the app.
	 
	 It piggy-backs on the `UIResponder.next` in order to pass the message through UIView/UIVC hierarchy of any depth and complexity.
	 However, it does not interfere with the regular `UIResponder` functionality.
	 
	 At the `UIViewController` level (see its extension in this same file), it‘s intercepted to switch up to the Coordinator, if the UIVC is owned by one.
	 Once that happens, it stays in the `Coordinator` hierarchy, since Coordinator can be nested only inside other Coordinators.
	 
	 ## How to make good use of it
	 
	 To use this new property, 	you write open methods on `UIResponder` which, by default, simply call the same method on `coordinatingResponder` thus continue passing the method through the responder chain.
	 
	 Here are of many possible implementations of the custom message:
	 
	 ```
	 @objc func messageTemplate(args: Whatever, sender: Any? = nil) {
	   coordinatingResponder?.messageTemplate(args: args, sender: sender)
	 }
	 
	 @objc func asyncFetcherExample(args: Whatever, sender: Any? = nil) async -> SomeResult {
	   return await coordinatingResponder?.asyncFetcherExample(args: args, sender: sender)
	 }
	 ```
	 */
	@objc open var coordinatingResponder: UIResponder? {
		return next
	}
}

extension UIResponder {
	///	Searches upwards the responder chain for the `Coordinator` instance that manages current `UIViewController`.
	public var containingCoordinator: Coordinating? {
		if let vc = self as? UIViewController, let pc = vc.parentCoordinator {
			return pc
		}
		
		return coordinatingResponder?.containingCoordinator
	}
}


extension UIViewController {
/**
	Returns `parentCoordinator` if this controller has one,
	or its parent `UIViewController` if it has one,
	or its view's `superview`.

	Copied from `UIResponder.next` documentation:

	- The `UIResponder` class does not store or set the next responder automatically, instead returning nil by default.
	- Subclasses must override this method to set the next responder.
	- `UIViewController` implements the method by returning its `view`’s `superview`;
	- `UIWindow` returns the application object, and `UIApplication` returns nil.
*/
	override open var coordinatingResponder: UIResponder? {
		guard let parentCoordinator = self.parentCoordinator else {
			guard let parentController = self.parent else {
				guard let presentingController = self.presentingViewController else {
					return view.superview
				}
				return presentingController as UIResponder
			}
			return parentController as UIResponder
		}
		return parentCoordinator as? UIResponder
	}
}

