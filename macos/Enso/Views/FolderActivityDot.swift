import SwiftUI

struct FolderActivityDot: View {
    let activity: FolderActivity
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    private var shouldPulse: Bool { activity == .working && !reduceMotion }

    private var color: Color {
        switch activity {
        case .working: Color.blue
        case .waiting: Color.yellow
        case .done: Color.green
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .opacity(shouldPulse && isPulsing ? 0.25 : 1)
            .animation(
                shouldPulse ? .linear(duration: 1.2).repeatForever(autoreverses: true) : nil,
                value: isPulsing
            )
            .onAppear { isPulsing = shouldPulse }
            .onChange(of: shouldPulse) { _, value in isPulsing = value }
    }
}
