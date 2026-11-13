#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics {
        /// What a plate is made of: paint over what is behind it, what is behind it frosted under a coat, or a pane
        /// of glass.
        public enum Surface: Sendable, Hashable {
            /// A colour over what is behind; its alpha is how much of it the plate hides.
            case fill(Picture.Color)

            /// What is behind, blurred by a Gaussian of `deviation`, under a coat of `coat`: a pane of glass with no
            /// body, rim or thickness whose frost is the deviation and whose tint is the coat.
            case frosted(deviation: Double, coat: Picture.Color)

            /// A pane of a glass, `thickness` thick, its top falling to the plate's outline across a rim `rim`
            /// wide, as `Picture.Glass.Pane` lays it.
            case glass(Picture.Glass, thickness: Double, rim: Double)
        }
    }

    extension Motion.Graphics.Surface {
        /// The plate over a rectangle with corners: a fill of the corners' path, or a pane over their region. A
        /// pane reads the picture beneath it wherever it stands, also inside a layer that fades it, so a plate
        /// of glass fades as a fill does. A clear fill draws nothing.
        public func elements(_ rectangle: Picture.Plane.Rectangle, corners: Motion.Graphics.Corners) -> [Picture.Element] {
            switch self {
            case .fill(let color):
                return color.alpha > 0 ? [.fill(corners.path(rectangle), .solid(color))] : []
            case .frosted(let deviation, let coat):
                let glass = Picture.Glass(tint: coat, frost: deviation)
                return [.pane(Picture.Glass.Pane(corners.region(rectangle), glass: glass, thickness: 0, rim: 0))]
            case .glass(let glass, let thickness, let rim):
                return [.pane(Picture.Glass.Pane(corners.region(rectangle), glass: glass, thickness: thickness, rim: rim))]
            }
        }
    }
#endif
