import SwiftUI

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.55
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 8

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                // Logo — matches onboarding app icon style
                ZStack {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(Color(white: 0.11))
                        .frame(width: 110, height: 110)
                    Text("R")
                        .font(.system(size: 68, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                // App name
                Text("Rift")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(textOpacity)
                    .offset(y: textOffset)
            }
        }
        .onAppear {
            // Logo springs in
            withAnimation(.spring(response: 0.45, dampingFraction: 0.68)) {
                logoScale = 1
                logoOpacity = 1
            }
            // Text slides up and fades in shortly after
            withAnimation(.easeOut(duration: 0.35).delay(0.25)) {
                textOpacity = 1
                textOffset = 0
            }
        }
    }
}

#Preview {
    SplashView()
}
