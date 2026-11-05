import SwiftUI

public struct TimingHUDView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var theme = ThemeManager.shared
    
    public init() {}
    
    public var body: some View {
        if settings.isTimingHUDVisible && !settings.timingHUDMessage.isEmpty {
            let activeColor = theme.activePalette.highlightAccent
            
            HStack(spacing: 10) {
                Image(systemName: "timer")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(activeColor)
                
                Text(settings.timingHUDMessage)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                HStack(spacing: 4) {
                    Text("[")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.12)))
                    
                    Text("]")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.12)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 0.06, green: 0.06, blue: 0.09).opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        activeColor.opacity(0.7),
                                        Color.white.opacity(0.15),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )
                    .shadow(color: activeColor.opacity(0.35), radius: 14, y: 4)
            )
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.9)).combined(with: .offset(y: -12)),
                removal: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .offset(y: -8))
            ))
        }
    }
}
