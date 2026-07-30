//
//  Shimmer.swift
//  SwiftUI-Shimmer
//  Created by Vikram Kriplaney on 23.03.21.
//

import SwiftUI

/// A view modifier that applies an animated "shimmer" to any view, typically to show that an operation is in progress.
public struct Shimmer: ViewModifier {
    public enum Mode {
        /// Masks the content with the gradient (this is the usual, default mode).
        case mask
        /// Overlays the gradient with a given `BlendMode` (`.sourceAtop` by default).
        case overlay(blendMode: BlendMode = .sourceAtop)
        /// Places the gradient behind the content.
        case background
    }

    private let animation: Animation?
    private let duration: TimeInterval
    private let delay: TimeInterval
    private let bounce: Bool
    private let gradient: Gradient
    private let min, max: CGFloat
    private let mode: Mode
    @State private var isInitialState = true
    @State private var startDate = Date()
    @Environment(\.layoutDirection) private var layoutDirection

    /// Initializes the modifier.
    /// - Parameters:
    ///   - duration: The duration of a shimmer cycle in seconds.
    ///   - bounce: Whether to reverse the animation after each cycle.
    ///   - delay: The delay before the animation starts.
    ///   - gradient: A custom gradient. Defaults to ``Shimmer/defaultGradient``.
    ///   - bandSize: The size of the animated mask's "band". Defaults to 0.3 unit points, which corresponds to
    /// 30% of the extent of the gradient.
    public init(
        duration: TimeInterval = 1.5,
        bounce: Bool = false,
        delay: TimeInterval = 0.25,
        gradient: Gradient = Self.defaultGradient,
        bandSize: CGFloat = 0.3,
        mode: Mode = .mask
    ) {
        self.animation = nil
        self.duration = duration
        self.delay = delay
        self.bounce = bounce
        self.gradient = gradient
        self.min = 0 - bandSize
        self.max = 1 + bandSize
        self.mode = mode
    }

    public init(
        animation: Animation,
        gradient: Gradient = Self.defaultGradient,
        bandSize: CGFloat = 0.3,
        mode: Mode = .mask
    ) {
        self.animation = animation
        self.duration = 1.5
        self.delay = 0.25
        self.bounce = false
        self.gradient = gradient
        // Calculate unit point dimensions beyond the gradient's edges by the band size
        self.min = 0 - bandSize
        self.max = 1 + bandSize
        self.mode = mode
    }

    /// The default animation effect.
    public static let defaultAnimation = Animation.linear(duration: 1.5).delay(0.25).repeatForever(autoreverses: false)

    // A default gradient for the animated mask.
    public static let defaultGradient = Gradient(colors: [
        .black.opacity(0.3), // translucent
        .black, // opaque
        .black.opacity(0.3) // translucent
    ])

    /*
     Calculating the gradient's animated start and end unit points:
     min,min
        \
         ┌───────┐         ┌───────┐
         │0,0    │ Animate │       │  "forward" gradient
     LTR │       │ ───────►│    1,1│  / // /
         └───────┘         └───────┘
                                    \
                                  max,max
                max,min
                  /
         ┌───────┐         ┌───────┐
         │    1,0│ Animate │       │  "backward" gradient
     RTL │       │ ───────►│0,1    │  \ \\ \
         └───────┘         └───────┘
                          /
                       min,max
     */

    /// The start unit point of our gradient, adjusting for layout direction.
    func startPoint(progress: CGFloat) -> UnitPoint {
        if layoutDirection == .rightToLeft {
            return UnitPoint(x: max - max * progress, y: min + (1 - min) * progress)
        } else {
            return UnitPoint(x: min + (1 - min) * progress, y: min + (1 - min) * progress)
        }
    }

    /// The end unit point of our gradient, adjusting for layout direction.
    func endPoint(progress: CGFloat) -> UnitPoint {
        if layoutDirection == .rightToLeft {
            return UnitPoint(x: 1 + (min - 1) * progress, y: max * progress)
        } else {
            return UnitPoint(x: max * progress, y: max * progress)
        }
    }

    public func body(content: Content) -> some View {
        if let animation {
            applyingGradient(to: content, progress: isInitialState ? 0 : 1)
                .animation(animation, value: isInitialState)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now()) {
                        isInitialState = false
                    }
                }
        } else if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
            TimelineView(.animation(minimumInterval: 1 / 60)) { context in
                applyingGradient(to: content, progress: progress(at: context.date))
            }
        } else {
            applyingGradient(to: content, progress: isInitialState ? 0 : 1)
                .animation(Self.defaultAnimation, value: isInitialState)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now()) {
                        isInitialState = false
                    }
                }
        }
    }

    func progress(at date: Date) -> CGFloat {
        guard duration > 0 else {
            return 1
        }
        let elapsed = Swift.max(0, date.timeIntervalSince(startDate))
        let pauseDuration = Swift.max(0, delay)
        let animationDuration = pauseDuration + duration
        let cycleDuration = bounce ? animationDuration * 2 : animationDuration
        let cycleTime = elapsed.truncatingRemainder(dividingBy: cycleDuration)
        guard cycleTime >= pauseDuration else {
            return 0
        }
        let forwardProgress = (cycleTime - pauseDuration) / duration
        guard bounce, forwardProgress > 1 else {
            return CGFloat(forwardProgress)
        }
        let reverseProgress = (cycleTime - animationDuration) / duration
        return CGFloat(Swift.max(0, 1 - reverseProgress))
    }

    @ViewBuilder public func applyingGradient(to content: Content) -> some View {
        applyingGradient(to: content, progress: isInitialState ? 0 : 1)
    }

    @ViewBuilder public func applyingGradient(to content: Content, progress: CGFloat) -> some View {
        let gradient = LinearGradient(
            gradient: gradient,
            startPoint: startPoint(progress: progress),
            endPoint: endPoint(progress: progress)
        )
        switch mode {
        case .mask:
            content.mask(gradient)
        case let .overlay(blendMode: blendMode):
            content.overlay(gradient.blendMode(blendMode))
        case .background:
            content.background(gradient)
        }
    }
}

public extension View {
    /// Adds an animated shimmering effect to any view, typically to show that an operation is in progress.
    /// - Parameters:
    ///   - active: Convenience parameter to conditionally enable the effect. Defaults to `true`.
    ///   - duration: The duration of a shimmer cycle in seconds.
    ///   - bounce: Whether to reverse the animation after each cycle.
    ///   - delay: The delay before the animation starts.
    ///   - gradient: A custom gradient. Defaults to ``Shimmer/defaultGradient``.
    ///   - bandSize: The size of the animated mask's "band". Defaults to 0.3 unit points, which corresponds to
    /// 20% of the extent of the gradient.
    @ViewBuilder func shimmering(
        active: Bool = true,
        duration: TimeInterval = 1.5,
        bounce: Bool = false,
        delay: TimeInterval = 0.25,
        gradient: Gradient = Shimmer.defaultGradient,
        bandSize: CGFloat = 0.3,
        mode: Shimmer.Mode = .mask
    ) -> some View {
        if active {
            modifier(
                Shimmer(
                    duration: duration,
                    bounce: bounce,
                    delay: delay,
                    gradient: gradient,
                    bandSize: bandSize,
                    mode: mode
                )
            )
        } else {
            self
        }
    }

    @ViewBuilder func shimmering(
        active: Bool = true,
        animation: Animation,
        gradient: Gradient = Shimmer.defaultGradient,
        bandSize: CGFloat = 0.3,
        mode: Shimmer.Mode = .mask
    ) -> some View {
        if active {
            modifier(Shimmer(animation: animation, gradient: gradient, bandSize: bandSize, mode: mode))
        } else {
            self
        }
    }

}

#if DEBUG
struct Shimmer_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            Text("SwiftUI Shimmer")
            if #available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *) {
                Text("SwiftUI Shimmer").preferredColorScheme(.light)
                Text("SwiftUI Shimmer").preferredColorScheme(.dark)
                VStack(alignment: .leading) {
                    Text("Loading...").font(.title)
                    Text(String(repeating: "Shimmer", count: 12))
                        .redacted(reason: .placeholder)
                }.frame(maxWidth: 200)
            }
        }
        .padding()
        .shimmering()
        .previewLayout(.sizeThatFits)

        VStack(alignment: .leading) {
            Text("مرحبًا")
            Text("← Right-to-left layout direction").font(.body)
            Text("שלום")
        }
        .font(.largeTitle)
        .shimmering()
        .environment(\.layoutDirection, .rightToLeft)

        Text("Custom Gradient Mode").bold()
            .font(.largeTitle)
            .shimmering(
                gradient: Gradient(colors: [.clear, .orange, .white, .green, .clear]),
                bandSize: 0.5,
                mode: .overlay()
            )
    }
}
#endif
