#if Graphics
    public import Motion
    public import Picture

    extension Picture {
        /// A window at a moment: the body's surface, the edge, the rule under the bar, the traffic lights and the
        /// title centred on the bar at the middle of its capitals, all faded by how much of the window shows.
        public init(_ window: Motion.Graphics.Window, at moment: Motion.Graphics.Window.Moment) {
            guard moment.shown > 0 else {
                self = .empty
                return
            }
            let style = window.style
            let frame = window.frame
            let (left, top, right) = (frame.llx.underlying, frame.lly.underlying, frame.urx.underlying)
            let edge = style.corners.path(frame)
            let bar = top + style.bar
            let rule = Picture.Plane.Path(Picture.Plane.Rectangle(llx: .init(left), lly: .init(bar), urx: .init(right), ury: .init(bar + style.line)))
            let middle = top + style.bar / 2
            let lights = (0..<Int(clamping: style.lights.count)).map { place in
                let centre = Picture.Plane.Point<2>([left + style.lights.inset + Double(place) * style.lights.step, middle])
                return Picture.Element.fill(Picture.Plane.Path(Picture.Plane.Circle(center: centre, radius: .init(style.lights.radius))), .solid(style.lights.color))
            }
            let title = window.text
            let fill = style.surface.elements(frame, corners: style.corners)
            let content = Picture(
                fill
                    + [
                        .stroke(edge, .solid(style.edge), width: style.line, join: .round, cap: .round),
                        .fill(rule, .solid(style.rule)),
                    ]
                    + lights
                    + [title.placed(.init(.solid(style.title.color)), at: Picture.Plane.Point<2>([(left + right) / 2, middle]), anchor: .center, level: .cap(0.5))]
            )
            self = moment.shown < 1 ? [.layer(Picture.Layer(content, opacity: Float(moment.shown)))] : content
        }
    }
#endif
