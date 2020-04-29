---
title: MVP + Coordinators in SwiftUI (part 3)
timeToRead: 15 minutes
date: 2020-04-29 13:00
description: Blog series on exploring a MVP+Coordinators approach in SwiftUI without using UIKit. 3rd part.
tags: swiftui, coordinator, mvp, article, series, part3, mixin, associatedobject
---

![](/images/posts/2020-04-26-MVPCoordinators-SwiftUI/1.jpg)

*Public repo: For those of you who want to check out the code right away here is the repo: [https://github.com/Lascorbe/SwiftUI-MVP-Coordinator](https://github.com/Lascorbe/SwiftUI-MVP-Coordinator).*

Welcome back! This is the 3rd part of the series on creating an MVP+Coordinators app in SwiftUI. If you're **looking for the 1st part**, please go here: [lascorbe.com/posts/2020-04-27-MVPCoordinators-SwiftUI-part1](https://lascorbe.com/posts/2020-04-27-MVPCoordinators-SwiftUI-part1). If you're **looking for the 2nd part instead**, please go here: [lascorbe.com/posts/2020-04-28-MVPCoordinators-SwiftUI-part2](https://lascorbe.com/posts/2020-04-28-MVPCoordinators-SwiftUI-part2).

**In part 1**, we learned how to set up an entire screen with the MVP pattern, we created our base `Coordinator` and our first two coordinators. We saw how to wrap our view in a `NavigationView` and how to implement `NavigationLink` so it doesn't depend of anything else in the view.

**In part 2**, we learned how to extract `NavigationLink` from `MasterView` creating a handy new `NavigationButton` along the way. We saw how to setup the Coordinator protocol so we can return SwiftUI Views from the `start()` function. We learned how to change presenting a view as a modal instead of in a navigation stack. And we also saw how to present several views from the same view.

**In this part, the 3rd one**, we're going to reimplement our Coordinator protocol to store the identifier, parent and children of the coordinators. We'll also deal with a bit of memory management so we don't create retain cycles. Are you ready? Let's go!

This is what we completed on [part 1](https://lascorbe.com/posts/2020-04-27-MVPCoordinators-SwiftUI-part1) and [part 2](https://lascorbe.com/posts/2020-04-28-MVPCoordinators-SwiftUI-part2):

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

## 1. 👾 Creating stored properties in `Coordinator`

In the previous parts, we created our `Coordinator` protocol where we set up the `start()` and `coordinate(:)` functions. Now, we're going to extend the functionality of this protocol, and we're going to start by adding a `parent` property to have a reference to the coordinator's parent.

How can we store this? I have to confess I used a trick, I used the Objective-C runtime to store them, creating a *Mixin*. Let's go to the `Coordinator` protocol:

```swift
protocol Coordinator: AssociatedObject { // notice AssociatedObject conformance
    associatedtype U: View
    associatedtype P: Coordinator
    func start() -> U
}

extension Coordinator {
    // parent must be `weak` so we don't create a retain cycle
    private(set) weak var parent: P? {
        get { associatedObject(for: &parentKey) }
        set { setAssociatedObject(newValue, for: &parentKey, policy: .weak) }
    }
}
    
extension Coordinator {
    func coordinate<T: Coordinator>(to coordinator: T) -> some View {
        coordinator.parent = self as? T.P
        return coordinator.start()
    }
}

private var parentKey: UInt8 = 0
```

What's a **mixin**? Well, [my friend Luis Recuenco explains it better than me on this blog post](https://jobandtalent.engineering/the-power-of-mixins-in-swift-f9013254c503), which I recommend you to read. In that post you can find the implementation of `AssociatedObject`, but [here's a direct link to its implementation in my project if you want to take a look](https://github.com/Lascorbe/SwiftUI-MVP-Coordinator/blob/master/SwiftUI-Coordinator/SwiftUI-Coordinator/Helpers/AssociatedObject.swift) (I just copied Luis' implementation).

Long story short, mixins are a way of leveraging on composition instead of subclassing. Right now we want to create a `parent` property in our `Coordinator` protocol, but it'd be great if we don't have to define that property on every coordinator class that conforms to `Coordinator`. To do that, we could you use subclassing, create a base coordinator class and make all the coordinators subclasses, but **I prefer to achieve polymorphic behavior and code reuse by composition instead of inheritance if I can**.

Now that we have stored properties in the protocol extension, we can save the parent of every coordinator, leveraging again in the power of generics.

This last change to the `Coordinator` protocol impacts the coordinators' implementation, and we have to make small changes to them in order to conform to `Coordinator`:

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

final class RootMasterCoordinator<P: Coordinator>: MasterCoordinator {
    {...} 
}

final class NavigationDetailCoordinator<P: Coordinator>: DetailCoordinator {
    {...}
}
```

That's it! We set `AppCoordinator` parent to itself, since it won't have parent, then we set `RootMasterCoordinator`'s parent as `AppCoordinator` with `<AppCoordinator>` on the constructor. Then on the rest of our Coordinators we can use `<Self>` to set the parent type, if the function is in a protocol extension, otherwise just use the parent's type directly. And we have to add `<P: Coordinator>` to the coordinator implementations so we define their parents on construction as well (when calling their init).

Now we have to store all the children of the coordinator, but first we have to add a way to identify each coordinator instance individually. Let's do that then! Back to our `Coordinator` protocol:

```swift
protocol Coordinator: AssociatedObject {
    {..}
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
        set { setAssociatedObject(newValue, for: &identifierKey) }
    }
    
    private(set) weak var parent: P? {
        get { associatedObject(for: &parentKey) }
        set { setAssociatedObject(newValue, for: &parentKey, policy: .weak) }
    }
  
    {...}
}

private var identifierKey: UInt8 = 0
private var parentKey: UInt8 = 0
```

Relying again on the power of the `AssociatedObject` protocol, aka the Objective-C runtime, we created a new stored property to lazily create the `identifier` on `get`.

Now we can add a way to store the children of the coordinator:

```swift
protocol Coordinator: AssociatedObject {
    {..}
}

extension Coordinator {
    private(set) var identifier: UUID {
        {...}
    }
  
    private(set) var children: [UUID: Any] {
        get {
            guard let children: [UUID: Any] = associatedObject(for: &childrenKey) else {
                self.children = [UUID: Any]()
                return self.children
            }
            return children
        }
        set { setAssociatedObject(newValue, for: &childrenKey) }
    }
    
    private(set) weak var parent: P? {
        {...}
    }
  
    private func store<T: Coordinator>(child coordinator: T) {
        children[coordinator.identifier] = coordinator
    }
    
    private func free<T: Coordinator>(child coordinator: T) {
        children.removeValue(forKey: coordinator.identifier)
    }
  
    {...}
}

private var identifierKey: UInt8 = 0
private var childrenKey: UInt8 = 0
private var parentKey: UInt8 = 0
```

We've added the property `children`, and the functions `store` and `free` to manage adding and removing children.

Great! We have learned how to implement stored properies in protocol extensions creating a mixin, using the power of the Objective-C runtime. In the next section, we'll see what we have to do to manage memory correctly so we don't create retain cycles.

This is what we've done so far:

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
        set { setAssociatedObject(newValue, for: &identifierKey) }
    }
    
    private(set) var children: [UUID: Any] {
        get {
            guard let children: [UUID: Any] = associatedObject(for: &childrenKey) else {
                self.children = [UUID: Any]()
                return self.children
            }
            return children
        }
        set { setAssociatedObject(newValue, for: &childrenKey) }
    }
    
    private func store<T: Coordinator>(child coordinator: T) {
        children[coordinator.identifier] = coordinator
    }
    
    private func free<T: Coordinator>(child coordinator: T) {
        children.removeValue(forKey: coordinator.identifier)
    }
    
    private(set) weak var parent: P? {
        get { associatedObject(for: &parentKey) }
        set { setAssociatedObject(newValue, for: &parentKey, policy: .weak) }
    }
    
    func coordinate<T: Coordinator>(to coordinator: T) -> some View {
        coordinator.parent = self as? T.P
        return coordinator.start()
    }
}

private var identifierKey: UInt8 = 0
private var childrenKey: UInt8 = 0
private var parentKey: UInt8 = 0

// MARK: AppCoordinator

final class AppCoordinator: Coordinator {
    typealias P = AppCoordinator 
  
    {...}
    
    @discardableResult
    func start() -> some View {
        let coordinator = RootMasterCoordinator<AppCoordinator>(window: window)
        return coordinate(to: coordinator)
    }
}

// MARK: MasterCoordinator

protocol MasterCoordinator: Coordinator {}

extension MasterCoordinator {
    func presentDetailView(isPresented: Binding<Bool>) -> some View {
        let coordinator = NavigationDetailCoordinator<Self>(isPresented: isPresented)
        return coordinate(to: coordinator)
    }
}

final class RootMasterCoordinator<P: Coordinator>: MasterCoordinator {
    {...}
}

// MARK: DetailCoordinator

protocol DetailCoordinator: Coordinator {}

final class NavigationDetailCoordinator<P: Coordinator>: DetailCoordinator {
    {...}
}

// MARK: Factory

{...}

// MARK: MVP

{...}
```

## 2. 💾 Handling coordinator's children and memory management

Now that we have all the properties we need in our `Coordinator` protocol, we have to manage how to actually add and remove the children of the coordinators.

Let's go to again to our `Coordinator` protocol to modify the `coordinate` function:

```swift
extension Coordinator {
    {...}
  
    private func store<T: Coordinator>(child coordinator: T) {
        children[coordinator.identifier] = coordinator
    }
    
    func coordinate<T: Coordinator>(to coordinator: T) -> some View {
        store(child: coordinator) // hi! I'm a new line
        coordinator.parent = self as? T.P
        return coordinator.start()
    }
}
```

We've added 1 line, a call to `store` to save the coordinator as a child.

Ok, but now we're retaining the coordinators we coordinatee to from here, and we are retaining the coordinators somewhere else too, in the presenters. We have to fix that!

Let's go to the presenter and make sure we don't have 2 strong references to the same object:

```swift
final class MasterPresenter<C: MasterCoordinator>: MasterPresenting {
    private(set) weak var coordinator: C?
    
    {...}
}
```

We switched our `coordinator` property from `private let` to `private(set) weak var`, so we have a weak reference to the coordinator from our presenter and a strong refence to the coordinator from its parent (in  `children` ).

Neat! We just avoided a bullet (aka retain cycle).

Now we need a way to free that memory whenever we have to release the coordinator, and we're going to implement another function usually found in the coordinator pattern, `stop`. 

Let's go back to `Coordinator`:

```swift
extension Coordinator {
    {...}
  
    private func free<T: Coordinator>(child coordinator: T) {
        children.removeValue(forKey: coordinator.identifier)
    }
    
    func stop() {
        children.removeAll()
        parent?.free(child: self)
    }
}
```

With the `stop` function we remove all the children, and with `free`, we ask the parent to remove this child.

We have everything in place, now we just have to see where we're going to call this `stop` function. But we have a problem, SwiftUI is not like UIKit, we do not have delegate methods to know when a view was released, like `UINavigationControllerDelegate`.

So instead of waiting for the view to notify the coordinator it dissappeared, we're going to rely on the presenter to know when we have to release a coordinator:

```swift
final class MasterPresenter<C: MasterCoordinator>: MasterPresenting {
    {...}
  
  	deinit {
        coordinator?.stop()
    }
  
  	{...}
}
```

Whenever SwiftUI decides to drop the view and it's linked presenter, we're going to tell its coordinator to also release itself.

Great! Looks good but... sadly, I have a but. There's another problem, do you think we're going to remember to call `coordinator?.stop()` on the `deinit` of every presenter we create? Exactly, me neither.

So we have 2 ways to solve this, one it's to add a rule to our linter (like [SwiftLint](https://github.com/realm/SwiftLint)) to alert us whenever it doesn't find the call to `stop` in the presenter's `deinit`. Another solution is to create a base presenter class and make all the presenters inherit from that one.

In my case, I choose the 2nd one:

```swift
class Presenter<C: Coordinator> {
    private(set) weak var coordinator: C?
    
    init(coordinator: C) {
        self.coordinator = coordinator
    }
    
    deinit {
        coordinator?.stop()
    }
}

final class MasterPresenter<C: MasterCoordinator>: Presenter<C>, MasterPresenting {
    @Published private(set) var viewModel: MasterViewModel
    
    override init(coordinator: C) {
        self.viewModel = MasterViewModel(date: Date())
        super.init(coordinator: coordinator)
    }
    
    func onButtonPressed(isPresented: Binding<Bool>) -> some View {
        return coordinator?.presentDetailView(isPresented: isPresented)
    }
}
```

We created a new `Presenter` base class, from which all our presenters will inherit now. As you can see, `MasterPresenter` is now a subclass, and we don't have to worry about the coordinator not being released anymore.

**Perfect! Now all the puzzle it's completed!** We added helper functions to `Coordinator` to manage adding and removing children, we implemented the `stop` method to release the coordinator. We learned how to avoid a retain cycle. And we created a new presenter base class to deal with the coordinator lifecycle. 

As I said before, I prefer composition over inheritance, but **you have to choose the option that fits better your needs**, in programming there no silver bullets, so be open to everything!

This is all what we've done in these 2 parts:

```swift
// You can put this in a playground and run it!

import SwiftUI

protocol Coordinator: AssociatedObject {
    associatedtype U: View
    associatedtype P: Coordinator
    func start() -> U
    func stop()
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
        set { setAssociatedObject(newValue, for: &identifierKey) }
    }
    
    private(set) var children: [UUID: Any] {
        get {
            guard let children: [UUID: Any] = associatedObject(for: &childrenKey) else {
                self.children = [UUID: Any]()
                return self.children
            }
            return children
        }
        set { setAssociatedObject(newValue, for: &childrenKey) }
    }
    
    private func store<T: Coordinator>(child coordinator: T) {
        children[coordinator.identifier] = coordinator
    }
    
    private func free<T: Coordinator>(child coordinator: T) {
        children.removeValue(forKey: coordinator.identifier)
    }
    
    private(set) weak var parent: P? {
        get { associatedObject(for: &parentKey) }
        set { setAssociatedObject(newValue, for: &parentKey, policy: .weak) }
    }
    
    func coordinate<T: Coordinator>(to coordinator: T) -> some View {
        store(child: coordinator)
        coordinator.parent = self as? T.P
        return coordinator.start()
    }
    
    func stop() {
        children.removeAll()
        parent?.free(child: self)
    }
}

private var identifierKey: UInt8 = 0
private var childrenKey: UInt8 = 0
private var parentKey: UInt8 = 0

// MARK: AppCoordinator

final class AppCoordinator: Coordinator {
    typealias P = AppCoordinator
    
    private weak var window: UIWindow?
    
    init(window: UIWindow) {
        self.window = window
    }
    
    @discardableResult
    func start() -> some View {
        let coordinator = RootMasterCoordinator<AppCoordinator>(window: window)
        return coordinate(to: coordinator)
    }
}

// MARK: MasterCoordinator

protocol MasterCoordinator: Coordinator {}

extension MasterCoordinator {
    func presentDetailView(isPresented: Binding<Bool>) -> some View {
        let coordinator = NavigationDetailCoordinator<Self>(isPresented: isPresented)
        return coordinate(to: coordinator)
    }
}

final class RootMasterCoordinator<P: Coordinator>: MasterCoordinator {
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

final class NavigationDetailCoordinator<P: Coordinator>: DetailCoordinator {
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

// MARK: Presenter

class Presenter<C: Coordinator> {
    private(set) weak var coordinator: C?
    
    init(coordinator: C) {
        self.coordinator = coordinator
    }
    
    deinit {
        coordinator?.stop()
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

final class MasterPresenter<C: MasterCoordinator>: Presenter<C>, MasterPresenting {
    @Published private(set) var viewModel: MasterViewModel
    
    override init(coordinator: C) {
        self.viewModel = MasterViewModel(date: Date())
        super.init(coordinator: coordinator)
    }
    
    func onButtonPressed(isPresented: Binding<Bool>) -> some View {
        return coordinator?.presentDetailView(isPresented: isPresented)
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

// MARK: Helpers

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

let dateFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .medium
    return dateFormatter
}()

protocol AssociatedObject: class {
    func associatedObject<T>(for key: UnsafeRawPointer) -> T?
    func setAssociatedObject<T>(
        _ object: T,
        for key: UnsafeRawPointer,
        policy: AssociationPolicy
    )
}
extension AssociatedObject {
    func associatedObject<T>(for key: UnsafeRawPointer) -> T? {
        return objc_getAssociatedObject(self, key) as? T
    }
    
    func setAssociatedObject<T>(
        _ object: T,
        for key: UnsafeRawPointer,
        policy: AssociationPolicy = .strong
    ) {
        return objc_setAssociatedObject(
            self,
            key,
            object,
            policy.objcPolicy
        )
    }
}
enum AssociationPolicy {
    case strong
    case copy
    case weak
    
    var objcPolicy: objc_AssociationPolicy {
        switch self {
            case .strong:
                return .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            case .copy:
                return .OBJC_ASSOCIATION_COPY_NONATOMIC
            case .weak:
                return .OBJC_ASSOCIATION_ASSIGN
        }
    }
}
```

## 🏁 Conclusion

We have learned how to implement stored properies in protocol extensions creating a mixin, using the power of the Objective-C runtime. We added helper functions to `Coordinator` to manage adding and removing children, we implemented the `stop` method to release the coordinator. We learned how to avoid a retain cycle. And we created a new presenter base class to deal with the coordinator lifecycle.

That's it! **We've completed part 3 of this series.** Now I invite you to [take a look at whole project I created](https://github.com/Lascorbe/SwiftUI-MVP-Coordinator), where the final implementation is, with more classes and examples, and both ways of navigating, navigation stack and modals. There you can also take a look at `AssociatedObject.swift` and see how we can create stored properties under the hood.

We've finished our experimental MVP+Coordinators SwiftUI project, but **there're still a few considerations I wonder about**:

- I didn't implement a way to navigate back from a coordinator, but there should be one. How should it work then?
- A great challenge is the deeplinking, how would it work in this implementation?
- What about animations? Right now, it's not possible to modify the animation/transition of `NavigationLink` nor `.sheet`. Hopefully, Apple will make that possible in the next SwiftUI version.
- Is this a good approach? Or the declarative nature of SwiftUI pushes us to use other design patterns/architectures, like redux?

All of them good candidates for an upcoming post 😏. I'll try to explore them but I can't promise anything, I dedicated a lot of time to these 3 blog posts and I can tell you writing is A LOT of work. So if you really like a writer/blogger, tell them! I'm sure they'll appreciate it immensely.

Last but not least, I'd like to give a big thank you to my friends [Marin Todorov](https://twitter.com/icanzilb) and [Benedikt Terhechte](https://twitter.com/terhechte) for giving me early feedback about these blog posts 🙇🏻‍♂️, you're the best! 🤗

**I hope you liked these [part 1](https://lascorbe.com/posts/2020-04-27-MVPCoordinators-SwiftUI-part1), [part 2](https://lascorbe.com/posts/2020-04-28-MVPCoordinators-SwiftUI-part2) and [part 3](https://lascorbe.com/posts/2020-04-29-MVPCoordinators-SwiftUI-part3) posts covering my experience trying to decouple the navigation in SwftUI**. 

Thank you for reading. Let me know what you think and share it with your friends!

Luis.