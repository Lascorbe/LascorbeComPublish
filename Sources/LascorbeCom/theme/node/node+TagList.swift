// Code thanks to @nitesuit from https://github.com/nitesuit/Blog

import Publish
import Plot

extension Node where Context == HTML.BodyContext {
    static func tagList(for item: Item<LascorbeCom>, on site: LascorbeCom) -> Node {
        return .tagList(for: item.tags, on: site)
    }
    
    static func tagList(for tags: [Tag], on site: LascorbeCom) -> Node {
        return .div(.class("mini-post-tags"), .forEach(tags) { tag in
            .a(
                .class("mini-post-category post-category-\(tag.string.lowercased())"),
                .href(site.path(for: tag)),
                .text(tag.string)
            )
        })
    }
    
    static func tagListPost(for item: Item<LascorbeCom>, on site: LascorbeCom) -> Node {
        return .tagListPost(for: item.tags, on: site)
    }
    
    static func tagListPost(for tags: [Tag], on site: LascorbeCom) -> Node {
        return .div(.class("post-tags"), .forEach(tags) { tag in
            .a(
                .class("post-category post-category-\(tag.string.lowercased())"),
                .href(site.path(for: tag)),
                .text(tag.string)
            )
        })
    }
    
    
    
    static func tagList(for page: TagListPage, on site: LascorbeCom) -> Node {
        return .tagList(for: Array(page.tags), on: site)
    }
}
