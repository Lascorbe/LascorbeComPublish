// Code thanks to @nitesuit from https://github.com/nitesuit/Blog

import Foundation
import Publish
import Plot

extension Node where Context == HTML.BodyContext {
    static func post(for item: Item<LascorbeCom>, on site: LascorbeCom) -> Node {
        let dateAndTime = DateFormatter.blog.string(from: item.date) + " · ⏱ \(item.metadata.timeToRead)"
        let urlUrl = "https://lascorbe.com/" + item.path.string
        let urlTitle = item.title
        let twitterUrl = "https://twitter.com/intent/tweet?via=lascorbe&text=\(urlTitle)&url=\(urlUrl)"
        let escapedUrl = twitterUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        
        return .pageContent(
            .h2(
                .class("post-title"),
                .text(item.title)
            ),
            .p(
                .class("post-meta"),
                .text(dateAndTime)
            ),
            .tagListPost(for: item, on: site),
            .div(
                .class("post-description"),
                .div(
                    .class("description-text"),
                    .contentBody(item.body)
                )
            ),
            .div(
                .class("post-description"),
                .div(
                    .class("pure-u-md-1-1"),
                    .a(
                        .href(escapedUrl),
                        .target(.blank),
                        .icon("fab fa-twitter"),
                        .text("Share this post on Twitter.")
                    )
                )
            )
        )
    }
}
