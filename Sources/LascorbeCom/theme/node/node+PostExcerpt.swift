// Code thanks to @nitesuit from https://github.com/nitesuit/Blog

import Foundation
import Publish
import Plot

extension Node where Context == HTML.BodyContext {
    static func postExcerpt(for item: Item<LascorbeCom>, on site: LascorbeCom) -> Node {
        let dateAndTime = DateFormatter.blog.string(from: item.date) + " · ⏱ \(item.metadata.timeToRead)"
        return .section(
            .class("section-post"),
            .div(
                .class("mini-post"),
                .a(
                    .href(item.path),
                    .header(
                        .class("mini-post-header"),
                        .h2(
                            .class("mini-post-title"),
                            .text(item.title)
                        ),
                        .p(
                            .class("mini-post-meta"),
                            .text(dateAndTime),
                            tagList(for: item, on: site)
                        )
                    ),
                    .div(
                        .class("mini-post-description"),
                        .p(
                            .class("mini-post-description-text"),
                            .a(
                                .href(item.path),
                                .text(item.metadata.description)
                            )
                        )
                    )
                )
            )
        )
    }
}
