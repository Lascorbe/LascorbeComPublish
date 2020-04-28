---
title: MVP + Coordinators in SwiftUI (part 3)
timeToRead: 15 minutes
date: 2020-04-29 13:00
description: 3rd part of exploring a MVP+Coordinators approach on SwiftUI without using UIKit.
tags: swiftui, coordinator, mvp, article, series, part3, mixin, associatedobject
---

![](/images/posts/2020-04-26-MVPCoordinators-SwiftUI/1.jpg)

*Public repo: For those of you who want to check out the code right away here is the repo: [https://github.com/Lascorbe/SwiftUI-MVP-Coordinator](https://github.com/Lascorbe/SwiftUI-MVP-Coordinator).*

Welcome back! This is the 3rd part of the series on creating an MVP+Coordinators app in SwiftUI. If you're **looking for the 1st part**, please go here: [lascorbe.com/posts/2020-04-27-MVPCoordinators-SwiftUI-part1](https://lascorbe.com/posts/2020-04-27-MVPCoordinators-SwiftUI-part1). If you're **looking for the 2nd part instead**, please go here: [lascorbe.com/posts/2020-04-28-MVPCoordinators-SwiftUI-part2](https://lascorbe.com/posts/2020-04-28-MVPCoordinators-SwiftUI-part2).

In the first part we learned how to set up an entire screen with the MVP pattern, we created our base Coordinator and our first 2 coordinators, and we saw how to wrap our view in a `NavigationView` and how we can implement `NavigationLink` so it doesn't depend of anything else in the view.

Now we're going to see how to extract that `NavigationLink`  from `MasterView`.

This is what we completed on the first part:

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
        let coordinator = NavigationMasterCoordinator(window: window)
        return coordinate(to: coordinator)
    }
}

// MARK: MasterCoordinator

protocol MasterCoordinator: Coordinator {}

extension MasterCoordinator: Coordinator {
    func presentDetailView(isPresented: Binding<Bool>) -> some View {
        let coordinator = NavigationDetailCoordinator(isPresented: isPresented)
        return coordinate(to: coordinator)
    }
}

final class RootMasterCoordinator: MasterCoordinator {
    private weak var window: UIWindow?
    
    init(window: UIWindow) {
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
    }
  
    func onButtonPressed(isPresented: Binding<Bool>) -> some View { 
        return coordinator.presentDetailView(isPresented: isPresented)
    }
}

struct MasterView<T: MasterPresenting>: View {
    @ObservedObject var presenter: T
  
    var body: some View {
        NavigationButton(contentView: Text("\(viewModel.date, formatter: dateFormatter)") ,
                         navigationView: { isPresented in
                             self.presenter.onButtonPressed(isPresented: $isPresented)
        })
    }
}
```

## 4. 👾 Bonus: let's talk about Mixins

Since we'll likely need to identify the coordinators and have access to their parents, let's go back to the `Coordinator` protocol and see how we can create store this. I have to confess I used a trick, I used the Objective-C runtime to store them, creating a *Mixin*:

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
    
    // parent must be `weak` so we don't create a retain cycle
    private(set) weak var parent: P? {
        get { associatedObject(for: &parentKey) }
        set { setAssociatedObject(newValue, for: &parentKey, policy: .weak) }
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

What's a *mixin*? Well, [my friend Luis explains it better than me on this blog post](https://jobandtalent.engineering/the-power-of-mixins-in-swift-f9013254c503). But long story short, they are a way of leveraging on composition instead of subclassing. In that blog post you can find the implementation of `AssociatedObject`, but [here's a direct link to its implementation in my project if you want to take a look](https://github.com/Lascorbe/SwiftUI-MVP-Coordinator/blob/master/SwiftUI-Coordinator/SwiftUI-Coordinator/Helpers/AssociatedObject.swift), I just copied Luis' implementation.

Now that we have stored properties in the protocol extension, we can save the identifier and parent of every coordinator, leveraging again in the power of generics.

In the coordinator pattaern, there's usually implemented a `children` property to store the coordinators you coordinate to from a coordinator. [I've implemented it to see how it'd look like](https://github.com/Lascorbe/SwiftUI-MVP-Coordinator/commit/14f4783c8991e0979dd611ec1522d289c329977c), but I think it doesn't make sense if we cannot free those child coordinators on "viewDidUnload".

This last change to the `Coordinator` protocol impacts the coordinators, and we have to make small changes to them in order to conform to `Coordinator`:

```swift
final class AppCoordinator: Coordinator {
    // this is the root Coordinator so we can just point the parent to itself
    typealias P = AppCoordinator 
    
    {...}
    
    @discardableResult
    func start() -> some View {
        let coordinator = RootMasterCoordinator<AppCoordinator>(window: window)
        return coordinate(to: coordinator)
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

That's it! We set `RootMasterCoordinator`'s parent as `AppCoordinator` with `<AppCoordinator>` on the constructor. Then on the rest of our Coordinators we can use `<Self>` to set the parent type.

We have learned how to implement stored properies in protocol extensions creating a mixin, using the power of the Objective-C runtime. And we've arrived to the end of part 2.

This is all what we've done in these 2 parts:

```swift
// MARK: Coordinator

protocol Coordinator: AssociatedObject { 
    associatedtype U: View
    associatedtype P: Coordinator
    func start() -> U
}

extension Coordinator {
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
    
    private(set) weak var parent: P? { 
        get { associatedObject(for: &parentKey) }
        set { setAssociatedObject(newValue, for: &parentKey, policy: .weak) }
    }
}
    
extension Coordinator {
    func coordinate<T: Coordinator>(to coordinator: T) -> some View {
        _ = coordinator.identifier
        coordinator.parent = self as? T.P
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
        let coordinator = NavigationMasterCoordinator(window: window)
        return coordinate(to: coordinator)
    }
}

// MARK: MasterCoordinator

protocol MasterCoordinator: Coordinator {}

extension MasterCoordinator: Coordinator {
    func presentDetailView(isPresented: Binding<Bool>) -> some View {
        let coordinator = NavigationDetailCoordinator(isPresented: isPresented)
        return coordinate(to: coordinator)
    }
}

final class RootMasterCoordinator: MasterCoordinator {
    private weak var window: UIWindow?
    
    init(window: UIWindow) {
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
    }
  
    func onButtonPressed(isPresented: Binding<Bool>) -> some View { 
        return coordinator.presentDetailView(isPresented: isPresented)
    }
}

struct MasterView<T: MasterPresenting>: View {
    @ObservedObject var presenter: T
  
    var body: some View {
        NavigationButton(contentView: Text("\(viewModel.date, formatter: dateFormatter)") ,
                         navigationView: { isPresented in
                             self.presenter.onButtonPressed(isPresented: $isPresented)
        })
    }
}
```

## 🏁 Conclusion

We've learned how to extract that `NavigationLink` from our `MasterView` creating a handy new `NavigationButton` along the way. We saw how to setup our Coordinator so we can return SwiftUI Views from the `start()` function, and how to implement stored properies in protocol extensions creating a mixin. We learned how to easily change presenting a view as a modal instead of in a navigation stack, and we also learned how to present several views from the same view.

That's it! **We've completed part 3 of this series.** I invite you to [take a look at the project I created](https://github.com/Lascorbe/SwiftUI-MVP-Coordinator), where the final implementation is, with more classes and examples, and both ways of navigating, with navigation stack and modals. There you can also take a look at `AssociatedObject.swift` and see how we can create stored properties under the hood.

We've finish our experimental MVP+Coordinators SwiftUI app, but **there're still a few considerations I wonder about**:

- I didn't implement a way to navigate back from a coordinator, should there be one?
- What about animations? Looks like right now it's not possible to modify the animation/transition of `NavigationLink` nor `.sheet` (or I didn't found it).
- A great challenge is the deeplinking, how would it work in this implementation?
- Is this a good approach? Or the declarative nature of SwiftUI pushes us to use other design pattern/architecture like redux?

They all do look as good candidates for an upcoming post. **I hope you liked these [part 1](https://lascorbe.com/posts/2020-04-27-MVPCoordinators-SwiftUI-part1), [part 2](https://lascorbe.com/posts/2020-04-28-MVPCoordinators-SwiftUI-part2) and [part 3](https://lascorbe.com/posts/2020-04-28-MVPCoordinators-SwiftUI-part2) posts covering my experience trying to decouple the navigation in SwftUI**. 

Thank you for reading. Let me know what you think and share it with your friends!

Luis.