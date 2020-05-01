---
title: MVP + Coordinators in SwiftUI (part 2)
timeToRead: 15 minutes
date: 2020-04-28 13:00
description: We'll see how to extract NavigationLink from MasterView. How to set up our Coordinator so we can return SwiftUI Views from the start function. How to easily change presenting a view as a modal instead of in a navigation stack. And we'll take a look at how to present several views from the same view. Let's go!
tags: swiftui, coordinator, mvp, article, series, part2
---

![](/images/posts/2020-04-26-MVPCoordinators-SwiftUI/1.jpg)

*Public repo: For those of you who want to check out the code right away here is the repo: [https://github.com/Lascorbe/SwiftUI-MVP-Coordinator](https://github.com/Lascorbe/SwiftUI-MVP-Coordinator).*

Welcome back! This is the second part of the blog posts on creating an MVP+Coordinators app with SwiftUI. **If you're looking for the first part, please go here instead:** [lascorbe.com/posts/2020-04-27-MVPCoordinators-SwiftUI-part1](https://lascorbe.com/posts/2020-04-27-MVPCoordinators-SwiftUI-part1).

**In the 1st part**, we learned how to set up an entire screen with the MVP pattern, we created a base `Coordinator` protocol, and implemented our first 2 coordinators. We saw how to wrap our view in a `NavigationView`, and how to implement `NavigationLink` so it doesn't depend on anything else in the view.

**In this part, part 2**, we're going to see how to extract that `NavigationLink` from `MasterView`. We'll see how to set up our `Coordinator` so we can return SwiftUI Views from the `start()` function. We'll learn how to easily change presenting a view as a modal instead of in a navigation stack. And we'll take a look at how to present several views from the same view.

Here's what we completed in [the first part of this series](https://lascorbe.com/posts/2020-04-27-MVPCoordinators-SwiftUI-part1), our starting point for this second part:

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
    static func make(with coordinator: MasterCoordinator) -> some View {
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
        self.viewModel = MasterViewModel(date: Date())
    }
}

struct MasterView<T: MasterPresenting>: View {
    @ObservedObject var presenter: T
  
    @State private var isPresented = false
  
    var body: some View {
        Button(action: {
            self.isPresented = true
        }) {
            Text("\(presenter.viewModel.date, formatter: dateFormatter)") 
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

## 1. 🥊 Extracting `NavigationLink` 

The last thing we did in *[part 1](https://lascorbe.com/posts/2020-04-27-MVPCoordinators-SwiftUI-part1)* was moving `NavigationView` out of the `MasterView` and "hidding" `NavigationLink` as the background view of the Button's text:

```swift
struct MasterView<T: MasterPresenting>: View {
    @ObservedObject var presenter: T
  
    @State private var isPresented = false
  
    var body: some View {
        Button(action: {
            self.isPresented = true
        }) {
            Text("\(presenter.viewModel.date, formatter: dateFormatter)") 
                .background(
                    NavigationLink(destination: EmptyView(), isActive: $isPresented) {
                        EmptyView()
                    }
                )
        }
    }
}
```

First let's see if we can make all that Button/background dance look better, so lets create a new view that handles it for us:

```swift
struct NavigationButton<CV: View, NV: View>: View {
    @State private var isPresented = false
    
    var contentView: CV
    var navigationView: (Binding<Bool>) -> NV
    
    var body: some View {
        Button(action: {
            self.isPresented = true
        }) {
            contentView
                .background(
                    navigationView($isPresented)
                )
        }
    }
}
```

Our new `NavigationButton` accepts one view, to present it as the button's content, and one constructor, a closure, for the navigation view. We have to use a closure so we can pass `isPresented` back and bind it.

This is how our `MasterView` looks now:

```swift
struct MasterView<T: MasterPresenting>: View {
    @ObservedObject var presenter: T
  
    var body: some View {
        NavigationButton(contentView: Text("\(presenter.viewModel.date, formatter: dateFormatter)") ,
                         navigationView: { isPresented in
                             NavigationLink(destination: EmptyView(), isActive: $isPresented) {
                                 EmptyView()
                             }
        })
    }
}
```

We switched the `Button` that was there before with our newly created `NavigationButton`. Notice that now we don't have to have a property to store `isPresented` because that's now handled by `NavigationButton`.

Now we can extract `NavigationLink`! Let's define what we really would like to have in the button in `MasterView`:

```swift
NavigationButton(contentView: Text("\(presenter.viewModel.date, formatter: dateFormatter)") ,
                 navigationView: { isPresented in
                     self.presenter.onButtonPressed(isPresented: $isPresented)
})
```

See how we switched `NavigationLink` with a presenter's function. And now I ask, where do we move `NavigationLink` to? The presenter? Hmmm, maybe better to the coordinator! 

But first, let's implement this method in the presenter:

```swift
protocol MasterPresenting: ObservableObject {
    associatedtype U: View                                
    var viewModel: MasterViewModel { get }
    func onButtonPressed(isPresented: Binding<Bool>) -> U // we return a View
}

final class MasterPresenter: MasterPresenting {
    @Published private(set) var viewModel: MasterViewModel
  
    private let coordinator: MasterCoordinator
    
    init(coordinator: MasterCoordinator) {
        self.coordinator = coordinator
        self.viewModel = MasterViewModel(date: Date())
    }
  
  	// using `some` we don't have to specify the MasterPresenting's associatedtype
    func onButtonPressed(isPresented: Binding<Bool>) -> some View { 
        return coordinator.presentDetailView(isPresented: isPresented)
    }
}
```

We have to return a SwiftUI View, which can only be used as a generic constraint, so we need to add an `associatedtype` in our `MasterPresenting` protocol. Notice how with the `some` keyword in `MasterPresenter` we don't have to specify the `associatedtype`.

Perfect, take a look at `coordinator.presentDetailView(:)`, it's returning a View. Now we can go to `MasterPresenter`'s coordinator and add the `presentDetailView` function. 

Remember we had a `MasterCoordinator` protocol which was empty? Not anymore:

```swift
protocol MasterCoordinator: Coordinator {}

extension MasterCoordinator {
    func presentDetailView(isPresented: Binding<Bool>) -> some View {
        let coordinator = NavigationDetailCoordinator(isPresented: isPresented)
        return coordinate(to: coordinator)
    }
}
```

Since `presentDetailView` is a *pure* function, we can add it as a default implementation to the `MasterCoordinator` protocol (isn't the `some` keyword great?).

By the way, did you notice we have a new coordinator? Yup, `NavigationDetailCoordinator`! It's exactly where we're going to put the `NavigationLink`:

```swift
protocol DetailCoordinator: Coordinator {}

final class NavigationDetailCoordinator: DetailCoordinator {
    private var isPresented: Binding<Bool>
    
    init(isPresented: Binding<Bool>) {
        self.isPresented = isPresented
    }
    
    func start() -> some View {
        return NavigationLink(destination: EmptyView(), isActive: isPresented) {
            EmptyView()
        }
    }
}
```

Hmmm... but now we have a problem, we're returning a View from `start()`, but the `Coordinator` protocol implementation isn't returning anything, we'll see what we have to do there.

Great! We've seen how to extract that `NavigationLink` from our `MasterView` creating a handy new `NavigationButton` along the way. In the next section we're going to reimplement our base Coordinator to handle returning Views from `start()`.

This is what we've done so far:

```swift
// MARK: Coordinator

protocol Coordinator {
    func start()
}

extension Coordinator {
    func coordinate(to coordinator: Coordinator) {
        coordinator.parent = self
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
        return coordinate(to: coordinator)
    }
}

// MARK: MasterCoordinator

protocol MasterCoordinator: Coordinator {}

extension MasterCoordinator {
    func presentDetailView(isPresented: Binding<Bool>) -> some View {
        let coordinator = NavigationDetailCoordinator(isPresented: isPresented)
        return coordinate(to: coordinator)
    }
}

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

// MARK: DetailCoordinator

protocol DetailCoordinator: Coordinator {}

final class NavigationDetailCoordinator: DetailCoordinator {
    private var isPresented: Binding<Bool>
    
    init(isPresented: Binding<Bool>) {
        self.isPresented = isPresented
    }
    
    func start() -> some View {
        return NavigationLink(destination: EmptyView(), isActive: isPresented) {
            EmptyView()
        }
    }
}

// MARK: Factory

enum MasterFactory {
    static func make(with coordinator: MasterCoordinator) -> some View {
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
    associatedtype U: View                                
    var viewModel: MasterViewModel { get }
    func onButtonPressed(isPresented: Binding<Bool>) -> U
}

final class MasterPresenter: MasterPresenting {
    @Published private(set) var viewModel: MasterViewModel
  
    private let coordinator: MasterCoordinator
    
    init(coordinator: MasterCoordinator) {
        self.coordinator = coordinator 
        self.viewModel = MasterViewModel(date: Date())
    }
  
    func onButtonPressed(isPresented: Binding<Bool>) -> some View { 
        return coordinator.presentDetailView(isPresented: isPresented)
    }
}

struct MasterView<T: MasterPresenting>: View {
    @ObservedObject var presenter: T
    
    var body: some View {
        NavigationButton(contentView: Text("\(presenter.viewModel.date, formatter: dateFormatter)"),
                         navigationView: { isPresented in
                            self.presenter.onButtonPressed(isPresented: isPresented)
        })
    }
}

struct NavigationButton<CV: View, NV: View>: View {
    @State private var isPresented = false
    
    var contentView: CV
    var navigationView: (Binding<Bool>) -> NV
    
    var body: some View {
        Button(action: {
            self.isPresented = true
        }) {
            contentView
                .background(
                    navigationView($isPresented)
            )
        }
    }
}
```

## 2. ⚡️ Changing base Coordinator's implementation

We just saw how to extract the `NavigationLink` from our `MasterView` creating a handy new `NavigationButton` along the way. Now we're going to reimplement our base Coordinator to return SwiftUI Views from `start()`.

Let's change it, this is our new `Coordinator` protocol:

```swift
protocol Coordinator {
    associatedtype U: View
    func start() -> U
}

extension Coordinator {
    func coordinate<T: Coordinator>(to coordinator: T) -> some View {
        return coordinator.start()
    }
}
```

Ok, we redefined our `start` and `coordinate` methods, now both of them return a View. And we rely on the power of generics and the keyword `some` to avoid specifying them.

Since we're now leveraging on a generic protocol for the coordinators, we have to change the implementation of `AppCoordinator`, `MasterFactory` and `MasterPresenter` like so:

```swift
final class AppCoordinator: Coordinator {
    {...}
    
    @discardableResult // discardableResult let us avoid capturing whatever it returns
    func start() -> some View {
        let coordinator = RootMasterCoordinator(window: window)
        return coordinate(to: coordinator)
    }
}

final class RootMasterCoordinator: MasterCoordinator {
    {...}
    
    func start() -> some View {
        let view = MasterFactory.make(with: self)
        let navigation = NavigationView { view }
        let hosting = UIHostingController(rootView: navigation)
        window?.rootViewController = hosting
        window?.makeKeyAndVisible()
        return EmptyView() // we just have to return something
    }
}

enum MasterFactory {
    static func make<C: MasterCoordinator>(with coordinator: C) -> some View {
        {...}
    }
}

final class MasterPresenter<C: MasterCoordinator>: MasterPresenting {
    @Published private(set) var viewModel: MasterViewModel
  
    private let coordinator: C
    
    init(coordinator: C) {
        self.coordinator = coordinator
        self.viewModel = MasterViewModel(date: Date())
    }
  
    {...}
}
```

Check out the `some View` and `<C: MasterCoordinator>` parts, we have to add them because we are conforming to the `Coordinator` protocol, which is generic now.

Aaaand done! Now we can navigate from one view to another one without the `NavigationLink` in the view itself, wooo!

We just saw how to setup our Coordinator so we can return SwiftUI Views from the `start()` function. In the next section we'll see how to present a view as a modal, and how to present several views from the same view.

Here's what we've done so far:

```swift
// MARK: Coordinator

protocol Coordinator {
    associatedtype U: View
    func start() -> U
}

extension Coordinator {
    func coordinate<T: Coordinator>(to coordinator: T) -> some View {
        return coordinator.start()
    }
}

// MARK: AppCoordinator

final class AppCoordinator: Coordinator {
    private weak var window: UIWindow?
    
    init(window: UIWindow) {
        self.window = window
    }
    
    @discardableResult
    func start() -> some View {
        let coordinator = RootMasterCoordinator(window: window)
        return coordinate(to: coordinator)
    }
}

// MARK: MasterCoordinator

protocol MasterCoordinator: Coordinator {}

extension MasterCoordinator {
    func presentDetailView(isPresented: Binding<Bool>) -> some View {
        let coordinator = NavigationDetailCoordinator(isPresented: isPresented)
        return coordinate(to: coordinator)
    }
}

final class RootMasterCoordinator: MasterCoordinator {
    private weak var window: UIWindow?
    
    init(window: UIWindow?) {
        self.window = window
    }
    
    func start() -> some View {
        let view = MasterFactory.make(with: self)
        let navigation = NavigationView { view }
        let hosting = UIHostingController(rootView: navigation)
        window?.rootViewController = hosting
        window?.makeKeyAndVisible()
        return EmptyView() 
    }
}

// MARK: DetailCoordinator

protocol DetailCoordinator: Coordinator {}

final class NavigationDetailCoordinator: DetailCoordinator {
    private var isPresented: Binding<Bool>
    
    init(isPresented: Binding<Bool>) {
        self.isPresented = isPresented
    }
    
    func start() -> some View {
        return NavigationLink(destination: EmptyView(), isActive: isPresented) {
            EmptyView()
        }
    }
}

// MARK: Factory

enum MasterFactory {
    static func make<C: MasterCoordinator>(with coordinator: C) -> some View {
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
    associatedtype U: View                                
    var viewModel: MasterViewModel { get }
    func onButtonPressed(isPresented: Binding<Bool>) -> U
}

final class MasterPresenter<C: MasterCoordinator>: MasterPresenting {
    @Published private(set) var viewModel: MasterViewModel
  
    private let coordinator: C
    
    init(coordinator: C) {
        self.coordinator = coordinator
        self.viewModel = MasterViewModel(date: Date())
    }
  
    func onButtonPressed(isPresented: Binding<Bool>) -> some View { 
        return coordinator.presentDetailView(isPresented: isPresented)
    }
}

struct MasterView<T: MasterPresenting>: View {
    @ObservedObject var presenter: T
    
    var body: some View {
        NavigationButton(contentView: Text("\(presenter.viewModel.date, formatter: dateFormatter)"),
                         navigationView: { isPresented in
                            self.presenter.onButtonPressed(isPresented: isPresented)
        })
    }
}

struct NavigationButton<CV: View, NV: View>: View {
    @State private var isPresented = false
    
    var contentView: CV
    var navigationView: (Binding<Bool>) -> NV
    
    var body: some View {
        Button(action: {
            self.isPresented = true
        }) {
            contentView
                .background(
                    navigationView($isPresented)
            )
        }
    }
}
```

## 3. 🚨 Switch from navigation to modal

We've learned how we can navigate from one view to another one with `NavigationLink`, but what if I want to present the view as a modal? Remember the `.sheet` modifier we talked about in [part 1](https://lascorbe.com/posts/2020-04-27-MVPCoordinators-SwiftUI-part1)? Well, I have a small trick for that, which is wrapping `.sheet` in a View:

```swift
struct ModalLink<T: View>: View {
    @Binding var isPresented: Bool
    var destination: T
    
    var body: some View {
        EmptyView()
            .sheet(isPresented: $isPresented, content: {
                self.destination
            })
    }
}
```

`ModalLink` is a view that contains the `.sheet` modifier, so we can use it as a view instead of as a modifier. Now that we have something like `NavigationLink` but for modal presentations, let's see how to use it.

Let's go to `NavigationDetailCoordinator`, and change the implementation of `start()` to show the view as a modal, instead of a push on the navigation stack, like this:

```swift
// Before
final class NavigationDetailCoordinator: DetailCoordinator {
    {...}
    
    func start() -> some View {
        return NavigationLink(destination: EmptyView(), isActive: isPresented) {
            EmptyView()
        }
    }
}

// After
final class NavigationDetailCoordinator: Coordinator {
    {...}
    
    func start() -> some View {
        return ModalLink(isPresented: isPresented, destination: view)
    }
}
```

That's it! That's the change! We didn't have to touch `MasterView`, `MasterPresenter` or any other file. We just switched from `NavigationLink` to our all-new `ModalLink`.

Now, let's say we would like to navigate to 2 views from the same view. Can we do that? Sure, we add a new `NavigationButton` to the view, and then handle the call from the presenter, like this:

```swift
protocol MasterPresenting: ObservableObject {
    associatedtype V1: View                                
    associatedtype V2: View                                
    var viewModel: MasterViewModel { get }
    func onButtonPressed1(isPresented: Binding<Bool>) -> V1
    func onButtonPressed2(isPresented: Binding<Bool>) -> V2
}
```

Notice that we have to add a new `associatedtype` for every different view we want to navigate to, and we're done. Then we have to link it to the coordinator in the presenter's implementation, and the call to the appropiate coordinator from the presenter's coordinator:

```swift
protocol MasterCoordinator: Coordinator {}

extension MasterCoordinator {
    func presentDetailView1(isPresented: Binding<Bool>) -> some View {
        // here we decide here to which coordinator we'd like to navigate to
        let coordinator = NavigationDetailCoordinator(isPresented: isPresented)
        return coordinate(to: coordinator)
    }
  
    func presentDetailView2(isPresented: Binding<Bool>) -> some View {
        // here we decide here to which coordinator we'd like to navigate to
        let coordinator = AnotherNewCoordinator(isPresented: isPresented)
        return coordinate(to: coordinator)
    }
}

final class RootMasterCoordinator: MasterCoordinator {
    {...}
}

final class MasterPresenter<C: MasterCoordinator>: MasterPresenting {
    {...}
  
    func onButtonPressed1(isPresented: Binding<Bool>) -> some View { 
        return coordinator.presentDetailView1(isPresented: isPresented)
    }
  
    func onButtonPressed2(isPresented: Binding<Bool>) -> some View { 
        return coordinator.presentDetailView2(isPresented: isPresented)
    }
}
```

In this section we saw how to easily change presenting a view as a modal instead of in a navigation stack. We also learned how to present several views from the same view. And we've arrived to the end of part 2.

I'm not going to add the "what we've done so far" bit here because it's starting to get big. But I invite you to [take a look at the public repo where I'm doing all](https://github.com/Lascorbe/SwiftUI-MVP-Coordinator), where the final implementation is, with more classes and examples, and both ways of navigating, with navigation stack and modals. 

## 🏁 Conclusion

We've learned how to extract that `NavigationLink` from our `MasterView` creating a handy new `NavigationButton` along the way. We saw how to set up our `Coordinator` so we can return SwiftUI Views from the `start()` function. We learned how to easily change presenting a view as a modal instead of in a navigation stack. And we also saw how to present several views from the same view.

**That's it! We've completed part 2 of this series.** In the next post, part 3, we'll see how to reimplement our `Coordinator` protocol to store its identifier, parent and children. To do that, to create stored properies in protocol extensions, we'll create a mixin using the power of the Objective-C runtime, sounds cool? 

**Next part of the series (part 3)!**: [https://lascorbe.com/posts/2020-04-29-MVPCoordinators-SwiftUI-part3](https://lascorbe.com/posts/2020-04-29-MVPCoordinators-SwiftUI-part3)

I hope you liked [part 1](https://lascorbe.com/posts/2020-04-27-MVPCoordinators-SwiftUI-part1) and [part 2](https://lascorbe.com/posts/2020-04-28-MVPCoordinators-SwiftUI-part2) covering my experience trying to decouple the navigation in SwftUI.

Thank you for reading. Let me know what you think and share it with your friends!

Luis.