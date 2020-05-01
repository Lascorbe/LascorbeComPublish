---
title: MVP + Coordinators in SwiftUI (part 1)
timeToRead: 15 minutes
date: 2020-04-27 12:00
description: We'll learn how to set up an entire screen with the MVP pattern, we'll create a base Coordinator protocol, and implement our first 2 coordinators. We'll see how to wrap our view in a `NavigationView`, and how we can implement `NavigationLink` so it doesn't depend on anything else in the view. Are you ready? Just press start!
tags: swiftui, coordinator, mvp, article, series, part1
---

![](/images/posts/2020-04-26-MVPCoordinators-SwiftUI/1.jpg)

*Public repo: For those of you who want to check out the code right away here is the repo: [https://github.com/Lascorbe/SwiftUI-MVP-Coordinator](https://github.com/Lascorbe/SwiftUI-MVP-Coordinator).*

**I didn't want to do much on SwiftUI until the next version is announced** due to my previous experience with Swift, I mean, it'll likely introduce a lot of breaking changes. I still remember the pain of migrating between Swift versions (Swift 3 to 4 anyone?), and I didn't want to live that again.

But all changed, quarantine arrived and I wanted to give a hand building a new app for a friend. I thought well, it could be nice to try SwiftUI making a real app. I liked what I saw about it until now, but after using it... what a great tool it is! **Something that took you 2 days to do with UIKit now you can do it in 2 hours**, it just boosts development so much. It's what we were waiting for while we were looking at things like hot reloading of our frontend colleagues, or React Native, or Flutter... Plus a declarative layout, nothing left to ask for.

But in SwiftUI not everything is a land of unicorns, specially when you discover that not only navigation is a bit tied to the views, but [there're](https://twitter.com/Dimillian/status/1184745928739184640?s=20) [some](https://twitter.com/tomatoterrorist/status/1242823885621350401?s=20) [broken](https://twitter.com/SwiftUILab/status/1156091686151475200?s=20) [things](https://twitter.com/ishabazz/status/1234274177231638529?s=20) [between iOS 13 minor versions](https://twitter.com/search?q=broken%20swiftui&src=typed_query) and other platforms.

I can't do much about how broken an Apple framework/tool is (above reporting ~~radars~~ [feedbacks](https://feedbackassistant.apple.com)), but I can explore **how navigation can be decoupled from Views**, or at least I can try. Also, [looks like there's some interest](https://twitter.com/Lascorbe/status/1253992068814430209?s=20). 

So in this post **I'm going to show you how to use SwiftUI with Coordinators**, and using the MVP design pattern.

I choose MVP and [Coordinators](https://khanlou.com/2015/10/coordinators-redux/), because I've worked with both, and because Coordinators became the defacto design pattern to route our navigation in a UIKit app ([thanks Soroush! 😊](https://vimeo.com/144116310)). I don't know if those 2 are the best design patterns to use with SwiftUI, maybe not, maybe something like redux would fit better, I don't know. But it doesn't hurt to try.

I'm not going to explain how coordinators work, [there're](https://khanlou.com/2015/10/coordinators-redux/) [several](https://www.hackingwithswift.com/articles/175/advanced-coordinator-pattern-tutorial-ios) [blog posts](https://khanlou.com/tag/advanced-coordinators/) explaining it far better and from smarter people than me, which I recommend you to check out if you haven't.

One more thing before we get started. **I created this project thinking in a big app, with testing in mind.** That's why you'll see an interface for most of the types (aka protocols), so everything can be mocked and tested.

Anyway, let's go for it, are you ready? Then create a new project and let's make our first view. **In the next section I'm going to explain how to set up our 1st screen with MVP (Model-View-Presenter)**.

## 1. ⌨️ Setting up our first screen with MVP

With our project created, let's define the 1st view of our app:

```swift
struct MasterView: View {
    var body: some View {
        Text("We will rock the stage at NSSpain again")
    }
}
```

I really want to try to void words like "just", "easy", "simple", "complex"... but this is literally *just* one label in the middle of the screen.

Now the model, *just* storing a date (I'll call them ViewModels because we're at the UI layer):

```swift
struct MasterViewModel {
    let date: Date
}
```

Now the presenter:

```swift
protocol MasterPresenting: ObservableObject { // Notice conformance to ObservableObject
    var viewModel: MasterViewModel { get }
}

final class MasterPresenter: MasterPresenting {
    @Published private(set) var viewModel: MasterViewModel
}
```

Yes, we're doing protocols all the way. This is going to be a small app, but let's treat it as if it was a big one. We declare the protocol of the presenter, so we can inject it in our view, which will make things like testing easier.

Using the power of Combine, we declared the protocol conformance to `ObservableObject`. Now we can observe the `@Published` properties from the view. 

Let's change our view to adopt this presenter protocol:

```swift
struct MasterView: View {
    @ObservedObject var presenter: MasterPresenting // check out @ObservedObject
  
    var body: some View {
        Text("\(viewModel.date, formatter: dateFormatter)")
    }
}
```

To bind this view to the presenter we need the `@ObservedObject` property wrapper. `dateFormatter` is just a global `DateFormatter` defined somewhere else. Now our view is "listening" for whenever our `viewModel` changes!

We've completed the MVP part of our first screen. **In the next section we're going to define our base Coordinator type and define our first 2 coordinators**.

This is what we've done so far:

```swift
struct MasterViewModel {
    let date: Date
}

protocol MasterPresenting: ObservableObject {
    var viewModel: MasterViewModel { get }
}

final class MasterPresenter: MasterPresenting {
    @Published private(set) var viewModel: MasterViewModel
}

struct MasterView: View {
    @ObservedObject var presenter: MasterPresenting
  
    var body: some View {
        Text("\(viewModel.date, formatter: dateFormatter)")
    }
}
```

## 2. 🧭 Creating Coordinators

With our MVP in place, now we are going to create protocols and implementations for coordinators. So how does our base Coordinator look like?

```swift
protocol Coordinator {
    func start()
}
```

Let's start with something like this. And we extend the protocol to define a coordinate function:

```swift
extension Coordinator {
    func coordinate(to coordinator: Coordinator) {
        coordinator.parent = self
        coordinator.start()
    }
}
```

Wait, how are you storing parent in a protocol extension? Where is it defined? Bear with me for a moment, we'll get there.

Next, we can try to implement `MasterView`'s coordinator:

```swift
protocol MasterCoordinator: Coordinator {} // empty for now

final class RootMasterCoordinator: MasterCoordinator {
    func start() {
        ??
    }
}
```

Hmmm, what can we do here? Let's go to the beginning of the app, the `SceneDelegate`, and see what we need.

```swift
func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    if let windowScene = scene as? UIWindowScene {
        let window = UIWindow(windowScene: windowScene)
        let coordinator = AppCoordinator(window: window) // <-- look here
        coordinator.start()                              // <-- and here
        self.window = window
    }
}
```

The important part is the 2 lines of the coordinator, the initialization, where we inject the window, and `coordinator.start()`. Now let's define our `AppCoordinator`, which is going to be the starting point of the app navigation:

```swift
final class AppCoordinator: Coordinator {
    private weak var window: UIWindow?
    
    init(window: UIWindow) {
        self.window = window
    }
    
    func start() {
        let coordinator = RootMasterCoordinator(window: window)
        coordinate(to: coordinator)
    }
}
```

We're injecting the `UIWindow` through the `init`, and then passing it to  `MasterView`'s coordinator. 

Next, we have to handle the presentation on the window. Let's go back to our `RootMasterCoordinator` and set up the `start()` function:

```swift
final class RootMasterCoordinator: MasterCoordinator {
    private weak var window: UIWindow?
    
    init(window: UIWindow?) {
        self.window = window
    }
    
    func start() {
        let view = MasterFactory.make(with: self)
        let hosting = UIHostingController(rootView: view)
        window?.rootViewController = hosting
        window?.makeKeyAndVisible()
    }
}
```

Here we just take the window and present the `rootViewController` (`UIHostingController` is what you need to bring SwiftUI Views to UIKit). The `AppCoordinator` and the `RootMasterCoordinator` are the only 2 coordinators where we need UIKit, maybe in *June* we get a new `UISceneDelegate`/`UIApplicationDelegate` API?

Cool! Coordinators are working via `AppCoordinator` and `RootMasterCoordinator`.

There's an interesting line in `RootMasterCoordinator`, what's behind that `MasterFactory`? As you can guess, a factory:

```swift
enum MasterFactory {
    static func make(with coordinator: Coordinator) -> some View {
        let presenter = MasterPresenter(coordinator: coordinator)
        let view = MasterView(presenter: presenter)
        return view
    }
}
```

I'm using an `enum` so it cannot be initialized, but a `struct` with an unavailable init also works. Here we get an interesting bit, notice we're returning `some View`, so we can get the SwiftUI view in `RootMasterCoordinator`.

Also, looks like we're injecting our coordinator into the presenter now, in `MasterPresenter(coordinator: coordinator)`, so let's implement that too:

```swift
final class MasterPresenter: MasterPresenting {
    @Published private(set) var viewModel: MasterViewModel
  
    private let coordinator: MasterCoordinator
    
    init(coordinator: MasterCoordinator) {
        self.coordinator = coordinator
        // You may want to bind your viewModel to a service/DB here, maybe using Combine/RxSwift
    }
}
```

As you can see, we inject the coordinator through the init as we did with the window in the coordinator. Then you may want to bind your model/entity here. I tried using `onAppear` on `MasterView` and report it back to the presenter as a way to bind the ViewModel, but it works as a `viewDidAppear` not like a `viewDidLoad`.

We've learned how to link everything together, the MVP with the coordinators, now we have the base structure of the UI. **In the next section we'll see how we can navigate to a view.**

This is what we've done so far:

```swift
// MARK: Coordinator

protocol Coordinator {
    func start()
}

extension Coordinator {
    func coordinate(to coordinator: Coordinator) {
        coordinator.start()
    }
}

// MARK: AppCoordinator

final class AppCoordinator: Coordinator {
    private weak var window: UIWindow?
    
    init(window: UIWindow) {
        self.window = window
    }
    
    func start() {
        let coordinator = RootMasterCoordinator(window: window)
        coordinate(to: coordinator)
    }
}

// MARK: MasterCoordinator

protocol MasterCoordinator: Coordinator {}

final class RootMasterCoordinator: MasterCoordinator {
    private weak var window: UIWindow?
    
    init(window: UIWindow?) {
        self.window = window
    }
    
    func start() {
        let view = MasterFactory.make(with: self)
        let hosting = UIHostingController(rootView: view)
        window?.rootViewController = hosting
        window?.makeKeyAndVisible()
    }
}

// MARK: Factory

enum MasterFactory {
    static func make(with coordinator: Coordinator) -> some View {
        let presenter = MasterPresenter(coordinator: coordinator)
        let view = MasterView(presenter: presenter)
        return view
    }
}

// MARK: MVP

struct MasterViewModel {
    let date: Date
}

protocol MasterPresenting: ObservableObject {
    var viewModel: MasterViewModel { get }
}

final class MasterPresenter: MasterPresenting {
    @Published private(set) var viewModel: MasterViewModel
  
    private let coordinator: MasterCoordinator
    
    init(coordinator: MasterCoordinator) {
        self.coordinator = coordinator
    }
}

struct MasterView: View {
    @ObservedObject var presenter: MasterPresenting
  
    var body: some View {
        Text("\(viewModel.date, formatter: dateFormatter)")
    }
}
```

## 3. 🗺 Navigating to another view

Now that we have our MVP and Coordinators in place, let's go to `MasterView` and see how we can navigate to another view with `NavigationLink`:

```swift
struct MasterView: View {
    @ObservedObject var presenter: MasterPresenting
  
    var body: some View {
        NavigationView {
            NavigationLink(destination: EmptyView()) {
                Text("\(viewModel.date, formatter: dateFormatter)")  
            }
        }
    }
}
```

What's going on here? We're telling `MasterView` that its content is wrapped in a `NavigationView`, kind of a `UINavigationController`. Then with `NavigationLink`, we create a `push` action to `EmptyView()` which is going to be triggered when `Text` is pressed.

But we don't want either `MasterView` to know that is being presented in a `NavigationView`, or that we're presenting `EmptyView()`, or that it must use `NavigationLink` to present it.

So first, we're going to move `NavigationView` out. Where should it go? Yup, the coordinator:

```swift
final class RootMasterCoordinator: MasterCoordinator {
    private weak var window: UIWindow?
    
    init(window: UIWindow?) {
        self.window = window
    }
    
    func start() {
        let view = MasterFactory.make(with: self)
        let navigation = NavigationView { view } // Hi! I'm new
        let hosting = UIHostingController(rootView: navigation)
        window?.rootViewController = hosting
        window?.makeKeyAndVisible()
    }
}

struct MasterView: View {
    @ObservedObject var presenter: MasterPresenting
  
    var body: some View {
        // NavigationView is no longer here
        NavigationLink(destination: EmptyView()) {
            Text("\(viewModel.date, formatter: dateFormatter)")  
        }
    }
}
```

Better. Next, we're going to move `NavigationLink` out too. It should be a function we can call on the presenter, something like:

```swift
struct MasterView: View {
    @ObservedObject var presenter: MasterPresenting
  
    var body: some View {
        presenter.presentSuperAmazingView {
            Text("\(viewModel.date, formatter: dateFormatter)")  
        }
    }
}
```

But there're 2 problems here. One, it's hard to understand what `presentSuperAmazingView` does, does it make `Text` a button? will it push the view? Second, we're working with `NavigationLink`, but what happens if we want to present a modal?

The way to present a modal is with a view modifier called `.sheet`. That's right, to push a view we have a View struct, `NavigationView`, and to present a modal we have a modifier, `.sheet`. If there's something I truly want to avoid is the lack of consistency. Maybe I'm too dumb to understand why it's been done like this, but I'm my humble opinion they both should work the same way (and I don't care if it's with structs or modifiers, or both, but use the same thing). So please, please 🙏🏻, if you're an Apple Engineer working in SwiftUI reading this, for the sake of consistency, expose them both the same way, thank you.

Anyway, how can we avoid this nicely? The best way I found is [using a `.background` view inside a Button's content](https://stackoverflow.com/a/61188788/736384). It's better to see it in code, so now our `MasterView` looks like this:

```swift
struct MasterView: View {
    @ObservedObject var presenter: MasterPresenting
  
    @State private var isPresented = false
  
    var body: some View {
        Button(action: {
            self.isPresented = true
        }) {
            Text("\(viewModel.date, formatter: dateFormatter)") 
                .background(
                    // this is the cool part
                    NavigationLink(destination: EmptyView(), isActive: $isPresented) {
                        EmptyView()
                    }
                )
        }
    }
}
```

Wooooow, ok, it looks weird at first, but it'll serve us perfectly and more importantly, it works! Essentially, we're hiding the `NavigationLink` in the Button Text's background, and the way it works is through `isActive`. Whenever the button is pressed, it'll switch `isPresented` to `true` which will trigger the `NavigationLink`.

Cool! We learned how to wrap our view in a `NavigationView` and how we can implement `NavigationLink` so it doesn't depend of anything else in the view, that way we can also easly change it to present a modal for example.

This is what we've done so far:

```swift
// MARK: Coordinator

protocol Coordinator {
    func start()
}

extension Coordinator {
    func coordinate(to coordinator: Coordinator) {
        coordinator.start()
    }
}

// MARK: AppCoordinator

final class AppCoordinator: Coordinator {
    private weak var window: UIWindow?
    
    init(window: UIWindow) {
        self.window = window
    }
  
    func start() {
        let coordinator = RootMasterCoordinator(window: window)
        coordinate(to: coordinator)
    }
}

// MARK: MasterCoordinator

protocol MasterCoordinator: Coordinator {}

final class RootMasterCoordinator: MasterCoordinator {
    private weak var window: UIWindow?
    
    init(window: UIWindow?) {
        self.window = window
    }
    
    func start() {
        let view = MasterFactory.make(with: self)
        let navigation = NavigationView { view }
        let hosting = UIHostingController(rootView: navigation)
        window?.rootViewController = hosting
        window?.makeKeyAndVisible()
    }
}

// MARK: Factory

enum MasterFactory {
    static func make(with coordinator: Coordinator) -> some View {
        let presenter = MasterPresenter(coordinator: coordinator)
        let view = MasterView(presenter: presenter)
        return view
    }
}

// MARK: MVP

struct MasterViewModel {
    let date: Date
}

protocol MasterPresenting: ObservableObject {
    var viewModel: MasterViewModel { get }
}

final class MasterPresenter: MasterPresenting {
    @Published private(set) var viewModel: MasterViewModel
  
    private let coordinator: MasterCoordinator
    
    init(coordinator: MasterCoordinator) {
        self.coordinator = coordinator
    }
}

struct MasterView: View {
    @ObservedObject var presenter: MasterPresenting
  
    @State private var isPresented = false
  
    var body: some View {
        Button(action: {
            self.isPresented = true
        }) {
            Text("\(viewModel.date, formatter: dateFormatter)") 
                .background(
                    // this is the cool part
                    NavigationLink(destination: EmptyView(), isActive: $isPresented) {
                        EmptyView()
                    }
                )
        }
    }
}
```

## 🏁 Conclusion

We've learned how to set up an entire screen with the MVP pattern, we created a base Coordinator protocol, and implemented our first 2 coordinators. We saw how to wrap our view in a `NavigationView`, and how to implement `NavigationLink` so it doesn't depend on anything else in the view.

That's it! **We've completed part 1 of this series.** In the next post we're going to see how to extract that `NavigationLink`  from `MasterView` and put it in a new Coordinator. We'll have to modify our current base Coordinator protocol, and we're going to see how to easily change from a navigation push to a modal presentation without touching the view, are you going to miss it? **Then head over to part 2!** 

**Go now to the next part of the series (part 2)!**: [https://lascorbe.com/posts/2020-04-28-MVPCoordinators-SwiftUI-part2](https://lascorbe.com/posts/2020-04-28-MVPCoordinators-SwiftUI-part2)

Thank you for reading, I hope you liked it.

Luis.

