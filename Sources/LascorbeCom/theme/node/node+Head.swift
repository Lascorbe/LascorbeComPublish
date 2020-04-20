// Code thanks to @nitesuit from https://github.com/nitesuit/Blog

import Publish
import Plot

extension Node where Context == HTML.DocumentContext {
    static func head(for location: Location, site: LascorbeCom) -> Node {
        let stylesheets: [Path] = [
//            "https://unpkg.com/purecss@1.0.1/build/pure-min.css",
            "https://unpkg.com/purecss@1.0.1/build/grids-responsive-min.css",
            "/Pure/styles.css",
            "/FontAwesomeCSS/all.css"
        ]
        let deafultHead = myHead(for: location, on: site, stylesheetPaths: stylesheets)
        return deafultHead
    }
    
    private static func myHead(
        for location: Location,
        on site: LascorbeCom,
        stylesheetPaths: [Path],
        titleSeparator: String = " | ",
        rssFeedPath: Path? = .defaultForRSSFeed,
        rssFeedTitle: String? = nil
    ) -> Node {
        var title = location.title
        if title.isEmpty {
            title = site.name
        } else {
            title.append(titleSeparator + site.name)
        }
        
        var description = location.description
        if description.isEmpty {
            description = site.description
        }
        
        return .head(
            .encoding(.utf8),
            .siteName(site.name),
            .url(site.url(for: location)),
            .title(title),
            .description(description),
            .twitterCardType(location.imagePath == nil ? .summary : .summaryLargeImage),
            .viewport(.accordingToDevice),
            .unwrap(rssFeedPath, { path in
                let title = rssFeedTitle ?? "Subscribe to \(site.name)"
                return .rssFeedLink(path.absoluteString, title: title)
            }),
            .unwrap(location.imagePath ?? site.imagePath, { path in
                let url = site.url(for: path)
                return .socialImageLink(url)
            }),
            .link(
                .rel(.stylesheet),
                .href("https://unpkg.com/purecss@1.0.1/build/pure-min.css"),
                .init(name: "integrity", value: "sha384-oAOxQR6DkCoMliIh8yFnu25d7Eq/PHS21PClpwjOTeU2jRSq11vu66rf90/cZr47"),
                .init(name: "crossorigin", value: "anonymous")
            ),
            .forEach(stylesheetPaths, { .stylesheet($0) }),
            .link(
                .rel(.icon),
                .href("/favicon-32x32.png"),
                .type("image/png"),
                .init(name: "sizes", value: "32x32")
            ),
            .link(
                .rel(.icon),
                .href("/favicon-16x16.png"),
                .type("image/png"),
                .init(name: "sizes", value: "16x16")
            ),
            .link(
                .rel(.appleTouchIcon),
                .href("/apple-touch-icon.png"),
                .type("image/png"),
                .init(name: "sizes", value: "180x180")
            ),
            .link(
                .rel(.manifest),
                .href("/site.webmanifest")
            )
        )
    }
}

//<link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png">
//<link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png">
//<link rel="icon" type="image/png" sizes="16x16" href="/favicon-16x16.png">
//<link rel="manifest" href="/site.webmanifest">
