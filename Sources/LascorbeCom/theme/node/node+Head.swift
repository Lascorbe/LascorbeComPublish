// Code thanks to @nitesuit from https://github.com/nitesuit/Blog

import Publish
import Plot

extension Node where Context == HTML.DocumentContext {
    static func head<T: Website>(for location: Location, site: T) -> Node {
        let stylesheets: [Path] = [
            "https://unpkg.com/purecss@1.0.1/build/pure-min.css",
            "https://unpkg.com/purecss@1.0.1/build/grids-responsive-min.css",
            "/Pure/styles.css",
            "/FontAwesomeCSS/all.css"
        ]
        let deafultHead = Node.head(for: location, on: site, stylesheetPaths: stylesheets)
        return deafultHead
    }
}
