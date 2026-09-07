import SwiftUI

/// Hidden reward for tapping the app version 7 times in Settings — a paper plane
/// (nod to "Air"Dash) flying a curved trail into a shield.
struct EasterEggView: View {
    @Binding var isPresented: Bool
    @State private var planeProgress: CGFloat = 0
    @State private var showImpact = false
    @State private var showText = false
    @State private var textOffset: CGFloat = 8

    private static let messageKeys = [
        "easter_egg.message.1",
        "easter_egg.message.2",
        "easter_egg.message.3"
    ]
    @State private var messageKey: String = messageKeys[0]

    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            GeometryReader { geo in
                let start = CGPoint(x: -30, y: geo.size.height * 0.72)
                let end = CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.42)
                // A gentle bow above the straight line between start and end, rather
                // than an exaggerated loop — keeps the plane visually on its own trail.
                let control = CGPoint(
                    x: (start.x + end.x) / 2,
                    y: (start.y + end.y) / 2 - 70
                )

                ZStack {
                    RadialGradient(
                        colors: [Color.accentColor.opacity(0.25), Color.accentColor.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 110
                    )
                    .frame(width: 220, height: 220)
                    .position(end)

                    TrailPath(start: start, control: control, end: end, progress: planeProgress)
                        .stroke(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0), Color.accentColor.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )

                    Circle()
                        .stroke(Color.accentColor.opacity(0.5), lineWidth: 2)
                        .frame(width: 90, height: 90)
                        .scaleEffect(showImpact ? 1.7 : 1)
                        .opacity(showImpact ? 0 : 1)
                        .position(end)

                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 88, height: 88)
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .scaleEffect(showImpact ? 1.08 : 1)
                    .position(end)

                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .rotationEffect(tangentAngle(start: start, control: control, end: end, t: planeProgress) + .degrees(45))
                        .position(pointOnQuadCurve(start: start, control: control, end: end, t: planeProgress))
                        .opacity(planeProgress < 1 ? 1 : 0)
                }
            }
            .allowsHitTesting(false)

            VStack {
                Spacer()
                if showText {
                    Text(LocalizedStringKey(messageKey))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .offset(y: textOffset)
                        .opacity(showText ? 1 : 0)
                }
                Spacer()
                Spacer()
            }
        }
        .onAppear { play() }
    }

    private func play() {
        messageKey = Self.messageKeys.randomElement() ?? Self.messageKeys[0]
        withAnimation(.timingCurve(0.3, 0, 0.15, 1, duration: 1.1)) {
            planeProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                showImpact = true
            }
            withAnimation(.easeOut(duration: 0.6)) {
                showText = true
                textOffset = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) {
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) {
            isPresented = false
        }
    }

    private func pointOnQuadCurve(start: CGPoint, control: CGPoint, end: CGPoint, t: CGFloat) -> CGPoint {
        let x = pow(1 - t, 2) * start.x + 2 * (1 - t) * t * control.x + pow(t, 2) * end.x
        let y = pow(1 - t, 2) * start.y + 2 * (1 - t) * t * control.y + pow(t, 2) * end.y
        return CGPoint(x: x, y: y)
    }

    /// Direction of travel along the curve at `t`, so the plane banks naturally
    /// into the turn instead of holding a fixed tilt.
    private func tangentAngle(start: CGPoint, control: CGPoint, end: CGPoint, t: CGFloat) -> Angle {
        let dx = 2 * (1 - t) * (control.x - start.x) + 2 * t * (end.x - control.x)
        let dy = 2 * (1 - t) * (control.y - start.y) + 2 * t * (end.y - control.y)
        return .radians(atan2(dy, dx))
    }
}

private struct TrailPath: Shape {
    let start: CGPoint
    let control: CGPoint
    let end: CGPoint
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        return path.trimmedPath(from: 0, to: progress)
    }
}
