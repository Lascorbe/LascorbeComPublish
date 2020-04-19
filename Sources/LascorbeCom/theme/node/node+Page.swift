// Code thanks to @nitesuit from https://github.com/nitesuit/Blog

import Foundation
import Plot
import Publish

extension Node where Context == HTML.BodyContext {
    static func page(for page: Page, on site: LascorbeCom) -> Node {
        return .pageContent(
            .h1(.class("content-subhead"), .text(page.title)),
            .div(
                .class("page-description"),
                .div(
                    .class("post-description-text"),
                    .contentBody(page.body)
                )
            )
        )
    }
}

