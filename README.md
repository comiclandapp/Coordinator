[![](https://img.shields.io/github/tag/radianttap/Coordinator.svg?label=current)](https://github.com/radianttap/Coordinator/releases)
[![](https://img.shields.io/github/license/radianttap/Coordinator.svg)](https://github.com/radianttap/Coordinator/blob/master/LICENSE)
![](https://img.shields.io/badge/swift-6.0-223344.svg?logo=swift&labelColor=FA7343&logoColor=white)
\
![platforms: iOS|tvOS|watchOS|macOS|visionOS](https://img.shields.io/badge/platform-iOS_15_·_tvOS_15_·_visionOS_1-blue.svg)

# Coordinator

Implementation of _Coordinator_ design pattern. It is *the* application architecture pattern for iOS, carefully designed to fit into UIKit; so much it could easily become `UICoordinator`.

Since this is *core architectural pattern*, it’s not possible to explain its usage with one or two clever lines of code. Give it a day or two; analyze and play around. I’m pretty sure you’ll find it worthy of your time and future projects.

## Installation

- version 8.x is using Swift 6 language mode and has strict concurrency turned ON
- version 7.x and up is made with Swift 5.5 concurrency in mind (async / await)
- versions before that (6.x) use closures

### Migrating to 8.1.0

`Coordinator.init(rootViewController:)` now takes a non-optional `T` instead of `T?`. The previous signature crashed on `nil` via `preconditionFailure`, so the only callers affected are those passing an explicit `nil` (which would have crashed anyway). Subclasses that construct their own root VC should build it before calling `super.init(rootViewController:)`.

`CoordinatingQueuedMessage` is now `@MainActor () -> Void`. Closures passed to `enqueueMessage(_:)` already had to run on the main actor in practice; the annotation just makes the contract explicit.

`NavigationCoordinator` now offers `async` overloads of `present(_:animated:)` and `dismiss(animated:)` alongside the existing completion-based methods. They're purely additive — existing call sites keep working — but callers using structured concurrency can now write `await coord.present(vc)` instead of wrapping UIKit's completion API in a `withCheckedContinuation` themselves.

Just drag `Coordinator` folder into your project — it‘s only a handful of files.

Or add add this repo’s URL through Swift Package Manager.

## Documentation

The _why_ and _how_ and...

- the [Pattern](documentation/Pattern.md)
- the [Library](documentation/Library.md)
- the [Class](documentation/Class.md)
- recommended [Implementation](documentation/Implement.md)

## License

[MIT](https://choosealicense.com/licenses/mit/), as usual.

## Give back

If you found this code useful, please consider [buying me a coffee](https://www.buymeacoffee.com/radianttap) or two. ☕️😋
