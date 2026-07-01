//
//  NowPlayingExpandedNotchView.swift
//  DynamicNotch
//
//  Created by Евгений Петрукович on 4/14/26.
//

import SwiftUI

struct NowPlayingExpandedNotchView: View {
    @Environment(\.notchScale) var scale
    @Environment(\.isDynamicIsland) var isDynamicIsland
    
    @ObservedObject var nowPlayingViewModel: NowPlayingViewModel
    @ObservedObject var settings: MediaAndFilesSettingsStore
    @ObservedObject var applicationSettings: ApplicationSettingsStore
    
    let onOpenPlaybackSource: @MainActor () -> Void
    
    @State private var scrubProgress: CGFloat?
    private let detailedPresentationSource = "nowPlaying.notch.expanded"
    private let lyricsPresentationSource = "nowPlaying.notch.expanded.lyrics"
    
    private var resolvedSnapshot: NowPlayingSnapshot {
        nowPlayingViewModel.snapshot ?? NowPlayingSnapshot(
            title: "Nothing Playing",
            artist: "Start playback to see live metadata",
            album: "Debug Preview",
            duration: 0,
            elapsedTime: 0,
            playbackRate: 0,
            artworkData: nil,
            refreshedAt: .now
        )
    }
    
    var body: some View {
        let snapshot = resolvedSnapshot

        return TimelineView(.periodic(from: .now, by: progressTick(for: snapshot))) { context in
            timelineContent(snapshot: snapshot, at: context.date)
        }
        .onAppear {
            nowPlayingViewModel.setDetailedPresentationActive(
                true,
                source: detailedPresentationSource
            )
            nowPlayingViewModel.setLyricsPresentationActive(
                true,
                source: lyricsPresentationSource
            )
        }
        .onDisappear {
            nowPlayingViewModel.setDetailedPresentationActive(
                false,
                source: detailedPresentationSource
            )
            nowPlayingViewModel.setLyricsPresentationActive(
                false,
                source: lyricsPresentationSource
            )
        }
    }

    private func timelineContent(snapshot: NowPlayingSnapshot, at date: Date) -> some View {
        let elapsedTime = nowPlayingViewModel.snapshot != nil ?
        nowPlayingViewModel.elapsedTime(at: date) :
        snapshot.elapsedTime
        let progress = progressValue(elapsedTime: elapsedTime, duration: snapshot.duration)
        let displayedProgress = min(max(scrubProgress ?? progress, 0), 1)
        let displayedElapsedTime = snapshot.duration > 0 ?
        TimeInterval(displayedProgress) * snapshot.duration :
        elapsedTime
        let appearance = settings.resolvedNowPlayingAppearanceOptions(
            isDefaultActivityStrokeEnabled: applicationSettings.isDefaultActivityStrokeEnabled
        )

        return VStack {
            Spacer()

            HStack(spacing: 15) {
                Button(action: {
                    openPlaybackSource()
                }) {
                    ArtworkView(
                        nowPlayingViewModel: nowPlayingViewModel,
                        width: 60,
                        height: 60,
                        cornerRadius: 10,
                        usesFlipAnimation: appearance.usesArtwork3DEffect
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlaybackSourceButtonStyle())
                .disabled(!nowPlayingViewModel.canOpenPlaybackSource)

                HStack(alignment: .top, spacing: 10) {
                    Button(action: {
                        openPlaybackSource()
                    }) {
                        VStack(alignment: .leading, spacing: 2) {
                            MarqueeText(
                                .constant(displayTitle(for: snapshot)),
                                font: .system(size: 16, weight: .medium),
                                nsFont: .headline,
                                textColor: .white.opacity(0.8),
                                backgroundColor: .clear,
                                minDuration: 2.0,
                                frameWidth: 170
                            )

                            MarqueeText(
                                .constant(displayArtist(for: snapshot)),
                                font: .system(size: 14),
                                nsFont: .headline,
                                textColor: .white.opacity(0.5),
                                backgroundColor: .clear,
                                minDuration: 3.0,
                                frameWidth: 170
                            )
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlaybackSourceButtonStyle())
                    .disabled(!nowPlayingViewModel.canOpenPlaybackSource)

                    Spacer(minLength: 0)

                    LightweightNowPlayingEqualizerView(
                        isPlaying: snapshot.isPlaying,
                        colors: [
                            nowPlayingViewModel.artworkPalette.equalizerHighlightColor,
                            nowPlayingViewModel.artworkPalette.equalizerBaseColor
                        ],
                        barHeight: 23,
                        barWidth: 2.7
                    )
                    .frame(width: 23, height: 18)
                }
            }
            Spacer()

            NowPlayingExpandedLyricsPanel(
                state: nowPlayingViewModel.lyricsState,
                activeIndex: activeLyricIndex(at: date),
                palette: nowPlayingViewModel.artworkPalette,
                isPlaying: snapshot.isPlaying,
                onSeek: { startTime in
                    nowPlayingViewModel.seek(to: startTime)
                }
            )
            .frame(height: 72)

            Spacer()

            PlayerProgressBar(
                progress: displayedProgress,
                displayedElapsedTime: displayedElapsedTime,
                duration: snapshot.duration,
                isInteractive: snapshot.duration > 0,
                tintGradient: {
                    switch appearance.progressTintStyle {
                    case .default:
                        return nil
                    case .artwork:
                        return nowPlayingViewModel.artworkPalette.equalizerGradient
                    case .systemAccent:
                        return LinearGradient(
                            colors: [.accentColor, .accentColor.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }(),
                primaryColor: progressTimeColor(isPrimary: true, appearance: appearance),
                secondaryColor: progressTimeColor(isPrimary: false, appearance: appearance),
                onScrubChanged: { newProgress in
                    scrubProgress = newProgress
                },
                onScrubEnded: { newProgress in
                    nowPlayingViewModel.seek(to: snapshot.duration * TimeInterval(newProgress))
                    scrubProgress = nil
                }
            )

            Spacer()

            ZStack {
                HStack(spacing: 25) {
                    PlayerControlButton(
                        systemImage: "backward.fill",
                        fontSize: 22,
                        width: 42,
                        height: 42,
                        feedbackStyle: .backward
                    ) {
                        nowPlayingViewModel.previousTrack()
                    }

                    PlayerControlButton(
                        systemImage: snapshot.isPlaying ? "pause.fill" : "play.fill",
                        fontSize: 32,
                        width: 42,
                        height: 42,
                        feedbackStyle: .playPause
                    ) {
                        nowPlayingViewModel.togglePlayPause()
                    }

                    PlayerControlButton(
                        systemImage: "forward.fill",
                        fontSize: 22,
                        width: 42,
                        height: 42,
                        feedbackStyle: .forward
                    ) {
                        nowPlayingViewModel.nextTrack()
                    }
                }

                HStack {
                    if appearance.showsFavoriteButton {
                        FavoriteTrackButton(
                            nowPlayingViewModel: nowPlayingViewModel,
                            width: 42,
                            height: 42,
                            fontSize: 21
                        )
                    }

                    Spacer()

                    if appearance.showsOutputDeviceButton {
                        AudioOutputRoutePickerButton(
                            nowPlayingViewModel: nowPlayingViewModel,
                            width: 42,
                            height: 42,
                            fontSize: 21
                        )
                    }
                }
                .padding(.horizontal, 5)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, isDynamicIsland ? 25 : 55)
        .padding(.top, isDynamicIsland ? 15 : 25)
        .padding(.bottom, 15)
    }
    
    private func displayTitle(for snapshot: NowPlayingSnapshot) -> String {
        snapshot.title.trimmed.isEmpty ? "Unknown Track" : snapshot.title
    }
    
    private func displayArtist(for snapshot: NowPlayingSnapshot) -> String {
        snapshot.artist.trimmed.isEmpty ? "Unknown Artist" : snapshot.artist
    }
    
    private func displayAlbum(for snapshot: NowPlayingSnapshot) -> String {
        snapshot.album.trimmed.isEmpty ? "Unknown Album" : snapshot.album
    }
    
    private func progressValue(elapsedTime: TimeInterval, duration: TimeInterval) -> CGFloat {
        guard duration > 0 else { return 0 }
        return min(max(CGFloat(elapsedTime / duration), 0), 1)
    }
    
    private func formattedTime(_ time: TimeInterval) -> String {
        guard time.isFinite else { return "--:--" }
        
        let totalSeconds = max(0, Int(time.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func progressTimeColor(isPrimary: Bool, appearance: NowPlayingAppearanceOptions) -> Color {
        switch appearance.progressTintStyle {
        case .default:
            return .white.opacity(0.4)
        case .artwork:
            let nsColor = isPrimary ?
            nowPlayingViewModel.artworkPalette.equalizerHighlightColor :
            nowPlayingViewModel.artworkPalette.equalizerBaseColor
            return Color(nsColor: nsColor)
        case .systemAccent:
            return isPrimary ? .accentColor : .accentColor.opacity(0.7)
        }
    }
    
    private func playbackStatusColor(for snapshot: NowPlayingSnapshot) -> Color {
        if nowPlayingViewModel.snapshot == nil {
            return .white.opacity(0.48)
        }
        
        return snapshot.isPlaying ?
        Color(red: 0.97, green: 0.73, blue: 0.32) :
            .white.opacity(0.48)
    }

    private func progressTick(for snapshot: NowPlayingSnapshot) -> TimeInterval {
        if snapshot.isPlaying,
           case .loaded(let lyrics) = nowPlayingViewModel.lyricsState,
           lyrics.isSynced {
            return 0.35
        }

        return snapshot.isPlaying ? 1.0 : 30.0
    }

    private func activeLyricIndex(at date: Date) -> Int {
        guard case .loaded(let lyrics) = nowPlayingViewModel.lyricsState else {
            return 0
        }

        return lyrics.activeLineIndex(at: nowPlayingViewModel.elapsedTime(at: date)) ?? 0
    }

    private func openPlaybackSource() {
        guard nowPlayingViewModel.canOpenPlaybackSource else { return }
        nowPlayingViewModel.openPlaybackSource()
        if !settings.isCloseAtFocusLiveActivityEnabled {
            onOpenPlaybackSource()
        }
    }
}

private struct NowPlayingExpandedLyricsPanel: View {
    let state: NowPlayingLyricsState
    let activeIndex: Int
    let palette: NowPlayingArtworkPalette
    let isPlaying: Bool
    let onSeek: (TimeInterval) -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(panelBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(borderGradient, lineWidth: 1)
                        .opacity(0.45)
                }
                .shadow(color: Color(nsColor: palette.equalizerBaseColor).opacity(0.25), radius: 16, x: 0, y: 8)

            content()
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: activeIndex)
    }

    @ViewBuilder
    private func content() -> some View {
        switch state {
        case .idle, .loading:
            NowPlayingLyricsLoadingRows(palette: palette)

        case .loaded(let lyrics):
            if lyrics.isSynced {
                syncedLyricsContent(lyrics)
            } else {
                plainLyricsContent(lyrics)
            }

        case .notFound, .failed:
            unavailableContent
        }
    }

    private func syncedLyricsContent(_ lyrics: TrackLyrics) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(visibleSyncedLines(lyrics.lines), id: \.id) { line in
                let distance = line.id - activeIndex
                NowPlayingExpandedLyricLine(
                    text: line.text,
                    distanceFromActive: distance,
                    palette: palette,
                    isPlaying: isPlaying,
                    onTap: line.startTime.map { startTime in
                        { onSeek(startTime) }
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .mask(verticalFadeMask)
    }

    private func plainLyricsContent(_ lyrics: TrackLyrics) -> some View {
        let visibleLines = Array(lyrics.lines.prefix(2))

        return VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(visibleLines.enumerated()), id: \.element.id) { index, line in
                NowPlayingExpandedLyricLine(
                    text: line.text,
                    distanceFromActive: index,
                    palette: palette,
                    isPlaying: isPlaying,
                    onTap: nil
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .transition(.opacity)
    }

    private var unavailableContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "quote.bubble")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(nsColor: palette.equalizerHighlightColor).opacity(0.72))

            Text("Lyrics unavailable")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .transition(.opacity)
    }

    private func visibleSyncedLines(_ lines: [LyricLine]) -> [LyricLine] {
        guard lines.isEmpty == false else { return [] }

        return (activeIndex - 1...activeIndex + 1).map { index in
            guard lines.indices.contains(index) else {
                return LyricLine(id: index, startTime: nil, text: " ")
            }

            return lines[index]
        }
    }

    private var panelBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(nsColor: palette.equalizerBaseColor).opacity(0.22),
                .white.opacity(0.055),
                .black.opacity(0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(nsColor: palette.equalizerHighlightColor).opacity(0.7),
                Color(nsColor: palette.equalizerBaseColor).opacity(0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var verticalFadeMask: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.16),
                .init(color: .black, location: 0.84),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct NowPlayingExpandedLyricLine: View {
    let text: String
    let distanceFromActive: Int
    let palette: NowPlayingArtworkPalette
    let isPlaying: Bool
    let onTap: (() -> Void)?

    private var isActive: Bool {
        distanceFromActive == 0
    }

    private var clampedDistance: CGFloat {
        min(CGFloat(abs(distanceFromActive)), 2)
    }

    var body: some View {
        Text(text)
            .font(.system(size: isActive ? 15 : 12, weight: isActive ? .semibold : .medium, design: .rounded))
            .foregroundStyle(lineColor)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .allowsTightening(true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .blur(radius: isActive ? 0 : 0.2 * clampedDistance)
            .scaleEffect(isActive ? 1 : 0.96, anchor: .leading)
            .offset(x: isActive ? 0 : 7)
            .contentTransition(.opacity)
            .onTapGesture {
                onTap?()
            }
    }

    private var lineColor: Color {
        if isActive {
            return Color(nsColor: palette.equalizerHighlightColor)
                .opacity(isPlaying ? 0.98 : 0.82)
        }

        return .white.opacity(max(0.28, 0.48 - (Double(clampedDistance) * 0.12)))
    }
}

private struct NowPlayingLyricsLoadingRows: View {
    let palette: NowPlayingArtworkPalette

    @State private var shimmerPhase: CGFloat = -0.6

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: index == 1 ? 7 : 5, style: .continuous)
                    .fill(Color(nsColor: palette.equalizerHighlightColor).opacity(index == 1 ? 0.3 : 0.16))
                    .frame(width: [CGFloat(0.54), 0.82, 0.64][index] * 240, height: index == 1 ? 10 : 7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .mask(
            LinearGradient(
                colors: [.black.opacity(0.35), .black, .black.opacity(0.35)],
                startPoint: UnitPoint(x: shimmerPhase - 0.4, y: 0.5),
                endPoint: UnitPoint(x: shimmerPhase + 0.4, y: 0.5)
            )
        )
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                shimmerPhase = 1.4
            }
        }
    }
}
