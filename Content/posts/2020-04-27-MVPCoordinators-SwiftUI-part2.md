---
title: MVP + Coordinators in SwiftUI (part 2)
timeToRead: 10 minutes
date: 2020-04-27 13:00
description: 2nd part of exploring a MVP+Coordinators approach on SwiftUI without using UIKit.
tags: swiftui, coordinator, mvp, article
---

![](/images/posts/2020-04-26-MVPCoordinators-SwiftUI/1.jpg)

*Public repo: For those of you who want to check out the code right away here is the repo: [https://github.com/Lascorbe/SwiftUI-MVP-Coordinator](https://github.com/Lascorbe/SwiftUI-MVP-Coordinator).*

Welcome back! This is the 2nd part of the blog posts on creating an MVP+Coordinators app with SwiftUI. **If you're looking for the 1st part, please go here instead:** [lascorbe.com/posts/2020-04-27-MVPCoordinators-SwiftUI-part1](https://lascorbe.com/posts/2020-04-27-MVPCoordinators-SwiftUI-part1).

In the first part we learned how to set up an entire screen with the MVP pattern, we created our base Coordinator and our first 2 coordinators, and we saw how to wrap our view in a `NavigationView` and how we can implement `NavigationLink` so it doesn't depend of anything else in the view.

Now we're going to see how to extract that `NavigationLink`  from `MasterView`.

This is what we completed on the first part:

```swift
// MARK: Coordinators

final class AppCoordinator: Coordinator {
    private weak var window: UIWindow?
    
    init(window: UIWindow) {
        self.window = window
    }
    
    func start() {
        let coordinator = NavigationMasterCoordinator(window: window)
        return coordinator.coordinate(to: coordinator)
    }
}

final class RootMasterCoordinator: MasterCoordinator {
    private weak var window: UIWindow?
    
    init(window: UIWindow) {
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

## 1. 🥊 Extracting `NavigationLink` 

The last thing we did in *part 1* was moving `NavigationView` out of the `MasterView` and "hidding" `NavigationLink` as the background view of the Button's text:

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
                    NavigationLink(destination: EmptyView(), isActive: $isPresented) {
                        EmptyView()
                    }
                )
        }
    }
}
```

Now we can extract `NavigationLink`! Let's define what we really would like to have in the button in `MasterView`:

```swift
Button(action: {
    self.isPresented = true
}) {
    Text("\(viewModel.date, formatter: dateFormatter)") 
        .background(
				    self.presenter.onButtonPressed(isPresented: $isPresented)
        )
}
```

See how we switched `NavigationLink` with a presenter's function. And now I ask, where do we move `NavigationLink` to? The presenter? Hmmm, maybe better in the coordinator! 

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
    }
  
  	// using `some` we don't have to specify the MasterPresenting's associatedtype
    func onButtonPressed(isPresented: Binding<Bool>) -> some View { 
        return coordinator.presentDetailView(isPresented: isPresented)
    }
}
```

We have to return a SwiftUI View, which can only be used as a generic constraint, so we need to add an `associatedtype` in our `MasterPresenting` protocol. Notice how with the `some` keyword we don't have to specify the `associatedtype`.

Also look at `coordinator.presentDetailView(:)`, it's returning a View. We're going there next but first we have to modify our `MasterView` because is using a generic protocol now:

```swift
struct MasterView<T: MasterPresenting>: View { // hi there T!
    @ObservedObject var presenter: T
  
    {...}
}
```

Since we don't want `MasterView` to know what `MasterPresenting` we're injecting, let's tell it on construction.

Perfect, now we can go to `MasterPresenter`'s' coordinator and add the `presentDetailView` function. Remember we had a `MasterCoordinator` protocol which was empty? Not anymore:

```swift
protocol MasterCoordinator: Coordinator {}

extension MasterCoordinator: Coordinator {
    func presentDetailView(isPresented: Binding<Bool>) -> some View {
        let coordinator = NavigationDetailCoordinator(isPresented: isPresented)
        return coordinate(to: coordinator)
    }
}
```

Since `presentDetailView` is a *pure* function, we can add it as a default implementation to the `MasterCoordinator` protocol.

Did you notice we have a new coordinator? `NavigationDetailCoordinator`, it's exactly where we're going to put the `NavigationLink`:

```swift
final class NavigationDetailCoordinator: Coordinator {
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

Great! Hmmm... but now we have a problem, we're returning a View from `start()`, but the `Coordinator` protocol implementation isn't returning anything.

Let's change it then, this is our new `Coordinator` protocol:

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

Since we're now relying on a generic protocol for the coordinators, we have to change the implementation of the `AppCoordinator`, `MasterFactory` and `MasterPresenter` like so:

```swift
final class AppCoordinator: Coordinator {
    {...}
    
    func start() -> some View {
        let coordinator = NavigationMasterCoordinator(window: window)
        return coordinator.coordinate(to: coordinator)
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
    }
  
    {...}
}
```

Check out the `some View` and `<C: MasterCoordinator>` parts, we are just conforming to the `Coordinator` protocol.

Aaaand done! Now we can navigate from 1 view to another without the `NavigationLink` in the view itself.

Ok, but what if I want to present the view as a modal, as we said before? Well, I have a small trick for that, which is wrapping `.sheet` in a View:

```swift
struct ModalReturnWrapper<T: View>: ReturnWrapper {
    typealias DestinationView = T
    
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

Now we can go to `NavigationDetailCoordinator` and change the implementation of `start()` to show the view as a modal instead of a push on the navigation stack, like this:

```swift
final class NavigationDetailCoordinator: Coordinator {
    {...}
    
    func start() -> some View {
        return ModalReturnWrapper(isPresented: isPresented, destination: view)
    }
}
```

That's it! That's the change, we didn't have to touch `MasterView` or any other view.

Since we'll likely need to identify the coordinators and have access to their parents, let's go back to the `Coordinator` protocol and see how we can create stored properties. I have to confess I used a trick, I used the Objective-C runtime to store them, creating a *mixin*:

```swift
protocol Coordinator: AssociatedObject { // notice AssociatedObject conformance
    associatedtype U: View
    associatedtype P: Coordinator
    func start() -> U
}

extension Coordinator { // Mixin Extension
    private(set) var identifier: UUID {
        get {
            guard let identifier: UUID = associatedObject(for: &identifierKey) else {
                self.identifier = UUID()
                return self.identifier
            }
            return identifier
        }
        set {
            setAssociatedObject(newValue, for: &identifierKey)
        }
    }
    
    private(set) var parent: P? {
        get { associatedObject(for: &parentKey) }
        set { setAssociatedObject(newValue, for: &parentKey) }
    }
}
    
extension Coordinator {
    func coordinate<T: Coordinator>(to coordinator: T) -> some View {
        _ = coordinator.identifier // generate identifier
        coordinator.parent = self as? T.P
        return coordinator.start()
    }
}
```

What's a *mixin*? Well, [my friend Luis explains it better than me on this blog post](https://jobandtalent.engineering/the-power-of-mixins-in-swift-f9013254c503). But long story short, they are a way of leveraging on composition instead of subclassing. There you can find the implementation of `AssociatedObject`, but [here's a direct link to its implementation in the project if you want to take a look](https://github.com/Lascorbe/SwiftUI-MVP-Coordinator/blob/master/SwiftUI-Coordinator/SwiftUI-Coordinator/Helpers/AssociatedObject.swift), I just copied Luis' implementation.

Now that we have stored properties in the protocol extension, we can store the identifier and parent of the protocol, leveraging again on generics.

This last change to the protocol impacts on the coordinators again, and we have to make small changes to them in order to conform to `Coordinator`:

```swift
final class AppCoordinator: Coordinator {
    // this is the root Coordinator so we can just point the parent to itself
    typealias P = AppCoordinator 
    
    {...}
    
    @discardableResult
    func start() -> some View {
        let coordinator = RootMasterCoordinator<AppCoordinator>(window: window)
        return coordinator.coordinate(to: coordinator)
    }
}

protocol MasterCoordinator: Coordinator {}
extension MasterCoordinator: Coordinator {
    func presentDetailView(isPresented: Binding<Bool>) -> some View {
        let coordinator = NavigationDetailCoordinator<Self>(isPresented: isPresented)
        return coordinate(to: coordinator)
    }
}
```

We set `RootMasterCoordinator`'s parent as `AppCoordinator` with `<AppCoordinator>` on the constructor. Then on the rest of our Coordinators we can use `<Self>` to set the parent type.

I invite you to [take a look at the project I created](https://github.com/Lascorbe/SwiftUI-MVP-Coordinator), where the final implementation is, with more classes and examples, and both ways of navigating, with navigation stack and modals. There you can also take a look at `AssociatedObject.swift` and see how we can create stored properties under the hood.

After all, there're a few considerations I wonder, and I would like you to know:

- I didn't implement a way to navigate back from a coordinator, should there be one?
- What about animations?
- A great challenge is the deeplinking, how would it work with this implementation?
- Is this a good approach? Or the declarative nature of SwiftUI pushes us to use other design pattern/architecture?

I hope you liked those 2 posts covering my experience trying to decouple the navigation on SwftUI. Let me know what you think and share it with your friends!

