import SwiftUI
import StrandDesign
import WhoopStore

/// An original, data-driven vector body map. The artwork is deliberately built from SwiftUI paths so
/// every muscle remains crisp at any device size and can be selected independently.
struct AnatomicalMuscleMap: View {
    enum Side: String, CaseIterable, Identifiable {
        case front
        case back

        var id: String { rawValue }
        var title: String {
            switch self {
            case .front: String(localized: "Front view")
            case .back: String(localized: "Back view")
            }
        }
    }

    let side: Side
    let values: [NOOPMuscle: Double]
    let onSelect: (NOOPMuscle) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AnatomicalSilhouette()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.13), Color.white.opacity(0.055)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        AnatomicalSilhouette()
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                    )

                ForEach(regions) { region in
                    let shape = SmoothMuscleShape(points: region.points)
                    let value = values[region.muscle, default: 0]
                    shape
                        .fill(MuscleLoadColorScale.color(value))
                        .overlay(
                            shape.stroke(
                                value > 0
                                    ? Color.white.opacity(0.34)
                                    : Color.white.opacity(0.10),
                                lineWidth: value > 0 ? 0.9 : 0.55
                            )
                        )
                        .shadow(
                            color: value > 0
                                ? MuscleLoadColorScale.color(value).opacity(0.30)
                                : .clear,
                            radius: 4
                        )
                        .contentShape(shape)
                        .onTapGesture { onSelect(region.muscle) }
                        .accessibilityElement()
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel(
                            "\(region.muscle.localizedName), \(MuscleLoadColorScale.level(value)) estimated load"
                        )
                        .accessibilityHint("Opens muscle load details")
                }

                // A subtle centre line makes left/right anatomy easier to read without suggesting
                // that the app directly measures activation on either side.
                Path { path in
                    path.move(to: CGPoint(x: geometry.size.width * 0.5, y: geometry.size.height * 0.13))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.5, y: geometry.size.height * 0.61))
                }
                .stroke(Color.black.opacity(0.22), style: StrokeStyle(lineWidth: 0.55, dash: [2, 3]))
                .allowsHitTesting(false)
            }
        }
        .aspectRatio(0.47, contentMode: .fit)
    }

    private var regions: [AnatomicalRegion] {
        side == .front ? Self.frontRegions : Self.backRegions
    }

    // Coordinates are normalized to the full body silhouette. Repeated regions intentionally map to
    // the same NOOPMuscle so the database taxonomy remains unchanged.
    private static let frontRegions: [AnatomicalRegion] = [
        .init("front-neck", .traps, [(0.45, 0.105), (0.55, 0.105), (0.58, 0.145), (0.50, 0.165), (0.42, 0.145)]),
        .init("front-delt-l", .frontDelts, [(0.31, 0.165), (0.42, 0.145), (0.40, 0.225), (0.31, 0.245), (0.25, 0.210)]),
        .init("front-delt-r", .frontDelts, [(0.58, 0.145), (0.69, 0.165), (0.75, 0.210), (0.69, 0.245), (0.60, 0.225)]),
        .init("side-delt-l", .sideDelts, [(0.25, 0.205), (0.31, 0.168), (0.32, 0.245), (0.27, 0.285), (0.22, 0.260)]),
        .init("side-delt-r", .sideDelts, [(0.69, 0.168), (0.75, 0.205), (0.78, 0.260), (0.73, 0.285), (0.68, 0.245)]),
        .init("chest-l", .chest, [(0.42, 0.158), (0.49, 0.176), (0.49, 0.260), (0.40, 0.278), (0.32, 0.236)]),
        .init("chest-r", .chest, [(0.51, 0.176), (0.58, 0.158), (0.68, 0.236), (0.60, 0.278), (0.51, 0.260)]),
        .init("biceps-l", .biceps, [(0.245, 0.275), (0.31, 0.255), (0.315, 0.365), (0.275, 0.415), (0.225, 0.380)]),
        .init("biceps-r", .biceps, [(0.69, 0.255), (0.755, 0.275), (0.775, 0.380), (0.725, 0.415), (0.685, 0.365)]),
        .init("forearm-l", .forearms, [(0.22, 0.395), (0.275, 0.420), (0.245, 0.535), (0.19, 0.575), (0.17, 0.535)]),
        .init("forearm-r", .forearms, [(0.725, 0.420), (0.78, 0.395), (0.83, 0.535), (0.81, 0.575), (0.755, 0.535)]),
        .init("abs-upper-l", .abdominals, [(0.43, 0.285), (0.495, 0.275), (0.495, 0.345), (0.425, 0.350)]),
        .init("abs-upper-r", .abdominals, [(0.505, 0.275), (0.57, 0.285), (0.575, 0.350), (0.505, 0.345)]),
        .init("abs-mid-l", .abdominals, [(0.425, 0.355), (0.495, 0.350), (0.495, 0.425), (0.42, 0.420)]),
        .init("abs-mid-r", .abdominals, [(0.505, 0.350), (0.575, 0.355), (0.58, 0.420), (0.505, 0.425)]),
        .init("abs-low-l", .abdominals, [(0.42, 0.427), (0.495, 0.432), (0.495, 0.500), (0.435, 0.475)]),
        .init("abs-low-r", .abdominals, [(0.505, 0.432), (0.58, 0.427), (0.565, 0.475), (0.505, 0.500)]),
        .init("oblique-l", .obliques, [(0.34, 0.275), (0.42, 0.285), (0.415, 0.460), (0.35, 0.505), (0.32, 0.390)]),
        .init("oblique-r", .obliques, [(0.58, 0.285), (0.66, 0.275), (0.68, 0.390), (0.65, 0.505), (0.585, 0.460)]),
        .init("hip-flexor-l", .hipFlexors, [(0.35, 0.505), (0.49, 0.505), (0.45, 0.570), (0.36, 0.585)]),
        .init("hip-flexor-r", .hipFlexors, [(0.51, 0.505), (0.65, 0.505), (0.64, 0.585), (0.55, 0.570)]),
        .init("abductor-l", .abductors, [(0.32, 0.535), (0.38, 0.570), (0.36, 0.710), (0.30, 0.735), (0.275, 0.630)]),
        .init("abductor-r", .abductors, [(0.62, 0.570), (0.68, 0.535), (0.725, 0.630), (0.70, 0.735), (0.64, 0.710)]),
        .init("quad-l-outer", .quadriceps, [(0.38, 0.575), (0.46, 0.585), (0.44, 0.745), (0.37, 0.795), (0.33, 0.710)]),
        .init("quad-l-inner", .quadriceps, [(0.46, 0.585), (0.49, 0.600), (0.485, 0.735), (0.44, 0.790), (0.44, 0.745)]),
        .init("quad-r-inner", .quadriceps, [(0.51, 0.600), (0.54, 0.585), (0.56, 0.745), (0.56, 0.790), (0.515, 0.735)]),
        .init("quad-r-outer", .quadriceps, [(0.54, 0.585), (0.62, 0.575), (0.67, 0.710), (0.63, 0.795), (0.56, 0.745)]),
        .init("adductor-l", .adductors, [(0.49, 0.565), (0.49, 0.735), (0.445, 0.755), (0.45, 0.605)]),
        .init("adductor-r", .adductors, [(0.51, 0.565), (0.55, 0.605), (0.555, 0.755), (0.51, 0.735)]),
        .init("tibialis-l", .tibialis, [(0.34, 0.805), (0.405, 0.805), (0.39, 0.955), (0.355, 0.955)]),
        .init("tibialis-r", .tibialis, [(0.595, 0.805), (0.66, 0.805), (0.645, 0.955), (0.61, 0.955)]),
        .init("front-calf-l", .calves, [(0.405, 0.805), (0.455, 0.810), (0.445, 0.930), (0.39, 0.955)]),
        .init("front-calf-r", .calves, [(0.545, 0.810), (0.595, 0.805), (0.61, 0.955), (0.555, 0.930)])
    ]

    private static let backRegions: [AnatomicalRegion] = [
        .init("back-traps-l", .traps, [(0.45, 0.105), (0.495, 0.135), (0.495, 0.255), (0.38, 0.195)]),
        .init("back-traps-r", .traps, [(0.505, 0.135), (0.55, 0.105), (0.62, 0.195), (0.505, 0.255)]),
        .init("rear-delt-l", .rearDelts, [(0.31, 0.165), (0.40, 0.175), (0.385, 0.245), (0.30, 0.270), (0.245, 0.215)]),
        .init("rear-delt-r", .rearDelts, [(0.60, 0.175), (0.69, 0.165), (0.755, 0.215), (0.70, 0.270), (0.615, 0.245)]),
        .init("side-delt-back-l", .sideDelts, [(0.245, 0.205), (0.31, 0.168), (0.30, 0.275), (0.245, 0.290), (0.215, 0.245)]),
        .init("side-delt-back-r", .sideDelts, [(0.69, 0.168), (0.755, 0.205), (0.785, 0.245), (0.755, 0.290), (0.70, 0.275)]),
        .init("upper-back-l", .upperBack, [(0.38, 0.195), (0.495, 0.255), (0.495, 0.335), (0.365, 0.295)]),
        .init("upper-back-r", .upperBack, [(0.505, 0.255), (0.62, 0.195), (0.635, 0.295), (0.505, 0.335)]),
        .init("lat-l", .lats, [(0.34, 0.275), (0.495, 0.335), (0.475, 0.475), (0.38, 0.445), (0.32, 0.345)]),
        .init("lat-r", .lats, [(0.505, 0.335), (0.66, 0.275), (0.68, 0.345), (0.62, 0.445), (0.525, 0.475)]),
        .init("erector-l", .erectorSpinae, [(0.445, 0.325), (0.492, 0.335), (0.492, 0.505), (0.455, 0.500)]),
        .init("erector-r", .erectorSpinae, [(0.508, 0.335), (0.555, 0.325), (0.545, 0.500), (0.508, 0.505)]),
        .init("lower-back-l", .lowerBack, [(0.38, 0.445), (0.492, 0.510), (0.492, 0.565), (0.36, 0.525)]),
        .init("lower-back-r", .lowerBack, [(0.508, 0.510), (0.62, 0.445), (0.64, 0.525), (0.508, 0.565)]),
        .init("triceps-l", .triceps, [(0.245, 0.280), (0.30, 0.275), (0.315, 0.380), (0.275, 0.425), (0.225, 0.385)]),
        .init("triceps-r", .triceps, [(0.70, 0.275), (0.755, 0.280), (0.775, 0.385), (0.725, 0.425), (0.685, 0.380)]),
        .init("back-forearm-l", .forearms, [(0.22, 0.400), (0.275, 0.425), (0.245, 0.535), (0.19, 0.575), (0.17, 0.535)]),
        .init("back-forearm-r", .forearms, [(0.725, 0.425), (0.78, 0.400), (0.83, 0.535), (0.81, 0.575), (0.755, 0.535)]),
        .init("glute-l", .glutes, [(0.35, 0.525), (0.492, 0.570), (0.485, 0.660), (0.37, 0.675), (0.315, 0.610)]),
        .init("glute-r", .glutes, [(0.508, 0.570), (0.65, 0.525), (0.685, 0.610), (0.63, 0.675), (0.515, 0.660)]),
        .init("back-abductor-l", .abductors, [(0.315, 0.600), (0.37, 0.675), (0.36, 0.735), (0.30, 0.745), (0.275, 0.650)]),
        .init("back-abductor-r", .abductors, [(0.63, 0.675), (0.685, 0.600), (0.725, 0.650), (0.70, 0.745), (0.64, 0.735)]),
        .init("hamstring-l", .hamstrings, [(0.37, 0.665), (0.485, 0.660), (0.45, 0.800), (0.36, 0.800), (0.31, 0.725)]),
        .init("hamstring-r", .hamstrings, [(0.515, 0.660), (0.63, 0.665), (0.69, 0.725), (0.64, 0.800), (0.55, 0.800)]),
        .init("back-calf-l", .calves, [(0.34, 0.805), (0.45, 0.805), (0.435, 0.925), (0.385, 0.960), (0.345, 0.925)]),
        .init("back-calf-r", .calves, [(0.55, 0.805), (0.66, 0.805), (0.655, 0.925), (0.615, 0.960), (0.565, 0.925)])
    ]
}

enum MuscleLoadColorScale {
    static func color(_ value: Double) -> Color {
        switch value {
        case 75...:
            Color(hex: "#FF3B5C")
        case 50..<75:
            Color(hex: "#FF8A34")
        case 25..<50:
            Color(hex: "#FFD43B")
        case 0.01..<25:
            Color(hex: "#00B8F5")
        default:
            Color.white.opacity(0.075)
        }
    }

    static func level(_ value: Double) -> String {
        switch value {
        case 75...: String(localized: "Very high")
        case 50..<75: String(localized: "High")
        case 25..<50: String(localized: "Moderate")
        case 0.01..<25: String(localized: "Low")
        default: String(localized: "No data")
        }
    }
}

private struct AnatomicalRegion: Identifiable {
    let id: String
    let muscle: NOOPMuscle
    let points: [CGPoint]

    init(_ id: String, _ muscle: NOOPMuscle, _ points: [(CGFloat, CGFloat)]) {
        self.id = id
        self.muscle = muscle
        self.points = points.map { CGPoint(x: $0.0, y: $0.1) }
    }
}

extension NOOPMuscle {
    var localizedName: String {
        switch self {
        case .chest: String(localized: "Chest")
        case .lats: String(localized: "Lats")
        case .upperBack: String(localized: "Upper Back")
        case .lowerBack: String(localized: "Lower Back")
        case .traps: String(localized: "Trapezius")
        case .frontDelts: String(localized: "Front deltoids")
        case .sideDelts: String(localized: "Side deltoids")
        case .rearDelts: String(localized: "Rear deltoids")
        case .biceps: String(localized: "Biceps")
        case .triceps: String(localized: "Triceps")
        case .forearms: String(localized: "Forearms")
        case .abdominals: String(localized: "Abdominals")
        case .obliques: String(localized: "Obliques")
        case .erectorSpinae: String(localized: "Erector spinae and core stabilizers")
        case .hipFlexors: String(localized: "Hip flexors")
        case .glutes: String(localized: "Glutes")
        case .quadriceps: String(localized: "Quadriceps")
        case .hamstrings: String(localized: "Hamstrings")
        case .adductors: String(localized: "Adductors")
        case .abductors: String(localized: "Abductors")
        case .calves: String(localized: "Calves")
        case .tibialis: String(localized: "Tibialis")
        }
    }
}

private struct SmoothMuscleShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        let scaled = points.map {
            CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height)
        }
        guard scaled.count > 2, let first = scaled.first, let last = scaled.last else {
            return Path()
        }

        var path = Path()
        path.move(to: midpoint(last, first))
        for index in scaled.indices {
            let current = scaled[index]
            let next = scaled[(index + 1) % scaled.count]
            path.addQuadCurve(to: midpoint(current, next), control: current)
        }
        path.closeSubpath()
        return path
    }

    private func midpoint(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
        CGPoint(x: (lhs.x + rhs.x) / 2, y: (lhs.y + rhs.y) / 2)
    }
}

private struct AnatomicalSilhouette: Shape {
    // A single continuous contour gives the map a recognisably human proportion while leaving each
    // coloured muscle as an independent interactive overlay.
    private let outline: [CGPoint] = [
        .init(x: 0.50, y: 0.015), .init(x: 0.44, y: 0.025),
        .init(x: 0.41, y: 0.065), .init(x: 0.42, y: 0.105),
        .init(x: 0.45, y: 0.125), .init(x: 0.42, y: 0.145),
        .init(x: 0.32, y: 0.160), .init(x: 0.24, y: 0.195),
        .init(x: 0.20, y: 0.270), .init(x: 0.20, y: 0.345),
        .init(x: 0.16, y: 0.455), .init(x: 0.13, y: 0.550),
        .init(x: 0.16, y: 0.590), .init(x: 0.20, y: 0.565),
        .init(x: 0.25, y: 0.455), .init(x: 0.29, y: 0.355),
        .init(x: 0.31, y: 0.500), .init(x: 0.28, y: 0.620),
        .init(x: 0.31, y: 0.735), .init(x: 0.34, y: 0.805),
        .init(x: 0.33, y: 0.925), .init(x: 0.31, y: 0.980),
        .init(x: 0.37, y: 0.990), .init(x: 0.42, y: 0.940),
        .init(x: 0.45, y: 0.805), .init(x: 0.49, y: 0.665),
        .init(x: 0.50, y: 0.665), .init(x: 0.51, y: 0.665),
        .init(x: 0.55, y: 0.805), .init(x: 0.58, y: 0.940),
        .init(x: 0.63, y: 0.990), .init(x: 0.69, y: 0.980),
        .init(x: 0.67, y: 0.925), .init(x: 0.66, y: 0.805),
        .init(x: 0.69, y: 0.735), .init(x: 0.72, y: 0.620),
        .init(x: 0.69, y: 0.500), .init(x: 0.71, y: 0.355),
        .init(x: 0.75, y: 0.455), .init(x: 0.80, y: 0.565),
        .init(x: 0.84, y: 0.590), .init(x: 0.87, y: 0.550),
        .init(x: 0.84, y: 0.455), .init(x: 0.80, y: 0.345),
        .init(x: 0.80, y: 0.270), .init(x: 0.76, y: 0.195),
        .init(x: 0.68, y: 0.160), .init(x: 0.58, y: 0.145),
        .init(x: 0.55, y: 0.125), .init(x: 0.58, y: 0.105),
        .init(x: 0.59, y: 0.065), .init(x: 0.56, y: 0.025)
    ]

    func path(in rect: CGRect) -> Path {
        SmoothMuscleShape(points: outline).path(in: rect)
    }
}
