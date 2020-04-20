import Foundation
import Publish
import Plot
import SplashPublishPlugin

struct LascorbeCom: Website {
    enum SectionID: String, WebsiteSectionID {
        case posts
        case about
    }

    struct ItemMetadata: WebsiteItemMetadata {
        var description: String
        var timeToRead: String
    }

    var url = URL(string: "https://lascorbe.com")!
    var name = "Luis Ascorbe"
    var description = "Software Developer. Tech Lead. Speaker. Conference Organizer."
    var language: Language { .english }
    var imagePath: Path? { nil }
    var socialMedia: [SocialMedia] { [.email, .github, .twitter, .linkedIn] }
}

try LascorbeCom().publish(
    withTheme: .blog,
    additionalSteps: [.deploy(using: .gitHub("lascorbe/lascorbe.github.io"))],
    plugins: [.splash(withClassPrefix: "la-")]
)
