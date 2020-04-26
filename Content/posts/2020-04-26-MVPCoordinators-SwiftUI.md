---
title: MVP + Coordinators in SwiftUI
timeToRead: ? minutes
date: 2020-04-26 13:00
description: Let's explore a MVP+Coordinators approach on SwiftUI without using UIKit.
tags: swiftui, coordinator, mvp, article
---



![](/images/posts/2020-04-26-MVPCoordinators-SwiftUI/1.jpg)

*Public repo: For those of you who want to check out the code right away here is the repo: https://github.com/Lascorbe/SwiftUI-MVP-Coordinator.*

**I didn't want to do much on SwiftUI until the next version is announced**, due to my previous experience with Swift, which will likely introduce a lot of breaking changes. I still remember the pain of migrating between Swift versions (Swift 3 to 4 anyone?).

But all changed, quarantine arrived and I wanted to give a hand building a new app for a friend. I though it could be nice to try SwiftUI making a real app. What a great tool it is, **something that took you 2 days to do with UIKit now you can do it in 2 hours**, it just boosts develpoment so much, it's what we all were waiting for while we were looking at hot reloading of our frontend colleagues, or React Native or Flutter... Plus a declarative layout. Great!

In SwiftUI everything is a land of unicorns, until you discover that not only navigation is a bit tied to the views itself, but [there're](https://twitter.com/Dimillian/status/1184745928739184640?s=20) [some](https://twitter.com/tomatoterrorist/status/1242823885621350401?s=20) [broken](https://twitter.com/SwiftUILab/status/1156091686151475200?s=20) [things](https://twitter.com/ishabazz/status/1234274177231638529?s=20) [between iOS 13 minor versions](https://twitter.com/search?q=broken%20swiftui&src=typed_query), and other platforms.

I can't do much about how broken an Apple framework/tool is (above reporting ~~radars~~ [feedbacks](https://feedbackassistant.apple.com)), but I can explore **how navigation can be decoupled from Views**, or at least I can try, [and looks like there's some interest](https://twitter.com/Lascorbe/status/1253992068814430209?s=20).

I choose MVP and [Coordinators](https://khanlou.com/2015/10/coordinators-redux/), because I've worked with MVP, and because Coordinators became the defacto design pattern to route our navigation on a UIKit app. I don't know if those 2 are the best design patterns to use with SwiftUI, probably not, maybe something like redux would fit better, I don't know, but it doesn't hurt to try. I will definitely try this with redux tho.

I'm not going to explain how coordinators work, [there're](https://khanlou.com/2015/10/coordinators-redux/) [several](https://www.hackingwithswift.com/articles/175/advanced-coordinator-pattern-tutorial-ios) [blog posts](https://khanlou.com/tag/advanced-coordinators/) far better and from smarter people than me on the internet which I recommend you to check out if you haven't. 

Let's go, let's define our 1st view.

```swift
struct MasterView: View {
    var body: some View {
        Text("We will rock the stage at NSSpain again")
    }
}
```

Just 1 label in the middle of the screen. 

Now the model, let's just store a date.

```swift
struct MasterViewModel {
    let date: Date
}
```

Now the presenter.

```swift
protocol MasterPresenting: ObservableObject {
    var viewModel: MasterViewModel { get }
}

final class MasterPresenter: MasterPresenting {
    @Published private(set) var viewModel: MasterViewModel
}
```

Here we declare the protocol of the Presenter, so we can inject it in our view, which will make testing easier.

We declare the protocol as `ObservableObject` so we can observe the `@Published` properties from the view. Let's change our view to adopt this.

```swift
struct MasterView: View {
    @ObservedObject var presenter: MasterPresenting
  
    var body: some View {
        Text("\(viewModel.date, formatter: dateFormatter)")
    }
}
```

`dateFormatter` is just a global `DateFormatter` defined somewhere else. Now our view is "listening" for whenever our `viewModel` changes!

We have the MVP, and we're going to define our coordinator now. So how does our base Coordinator look like?

```swift
protocol Coordinator {
    var identifier: UUID { get }
    var childs: [UUID: Coordinator] { get }
    var parent: Coordinator { get }
    func start()
}
```

Let's start with something like this. And we extend the protocol to define a coordinate function:

```swift
extension Coordinator {
  func coordinate(to coordinator: Coordinator) {
    coordinator.parent = self
    childs[coordinator.identifier] = coordinator
    return coordinator.start()
  }
}
```

Wait how are you storing parent and childs on a protocol extension? Bear with me for a second, we'll get there.

And our view's coordinator now.

```swift
protocol MasterCoordinator: Coordinator {} // for now, empty

final class RootMasterCoordinator: MasterCoordinator {
    func start() {
        ??
    }
}
```

Hmmm, what can we do here? Let's go to the beginning of the app, the `SceneDelegate`, and see what we need to get here.

```swift
func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    if let windowScene = scene as? UIWindowScene {
        let window = UIWindow(windowScene: windowScene)
        let coordinator = AppCoordinator(window: window)
        coordinator.start()
        self.window = window
    }
}
```

We want something like that, notice the important part, `coordinator.start()`, then how can our `AppCoordinator` look like? Maybe:

```swift
class AppCoordinator: Coordinator {
    weak var window: UIWindow?
    
    init(window: UIWindow) {
        self.window = window
    }
    
    func start() {
        let coordinator = NavigationMasterCoordinator(window: window)
        return coordinator.coordinate(to: coordinator)
    }
}
```

We can go back to our `RootMasterCoordinator` and set it up now:

```swift
final class RootMasterCoordinator: MasterCoordinator {
    weak var window: UIWindow?
    
    init(window: UIWindow) {
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

This is only part where we need UIKit, maybe in June we get a new `UISceneDelegate`/`UIApplicationDelegate` API? Anyway, It's starting to look good. 

What's behind that `MasterFactory`?

```swift
enum MasterFactory {
    static func make(with coordinator: Coordinator) -> some View {
        let presenter = MasterPresenter(coordinator: coordinator)
        let view = MasterView(presenter: presenter)
        return view
    }
}
```

Here we get an interesting bit, notice we're returning `some View`, so we can get the SwiftUI view in the `RootMasterCoordinatorv` coordinator.

Also, looks like now we're injecting our coordinator into the presenter, so let's implement that too:

```swift
protocol MasterPresenting: ObservableObject {
    var viewModel: MasterViewModel { get }
}

final class MasterPresenter: MasterPresenting {
    @Published private(set) var viewModel: MasterViewModel
  
    private let coordinator: Coordinator
    
    init(coordinator: Coordinator) {
        self.coordinator = coordinator
    }
}
```



Let's go back to our view, and try to see how we can navigate to another view.

