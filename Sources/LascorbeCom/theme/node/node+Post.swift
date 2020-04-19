// Code thanks to @nitesuit from https://github.com/nitesuit/Blog

import Foundation
import Publish
import Plot

extension Node where Context == HTML.BodyContext {
    static func post(for item: Item<LascorbeCom>, on site: LascorbeCom) -> Node {
        let dateAndTime = DateFormatter.blog.string(from: item.date) + " · ⏱ \(item.metadata.timeToRead)"
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
            )
        )
    }
}