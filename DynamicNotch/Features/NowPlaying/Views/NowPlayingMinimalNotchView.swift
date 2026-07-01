//
//  NowPlayingMinimalNotchView.swift
//  DynamicNotch
//
//  Created by Евгений Петрукович on 4/14/26.
//

import SwiftUI

struct NowPlayingMinimalNotchView: View {
    @Environment(\.notchScale) var scale
    @Environment(\.isDynamicIsland) var isDynamicIsland
    
    @ObservedObject var nowPlayingViewModel: NowPlayingViewModel
    @ObservedObject var settings: MediaAndFilesSettingsStore
    private let lyricsPresentationSource = "nowPlaying.notch.minimal"
    
    private var resolvedSnapshot: NowPlayingSnapshot {
        nowPlayingViewModel.snapshot ?? NowPlayingSnapshot(
            title: "Nothing Playing",
            artist: "Nothing artists",
            album: "",
            duration: 0,
            elapsedTime: 0,
            playbackRate: 0,
            artworkData: nil,
            refreshedAt: .now
        )
    }
    
    var body: some View {
        let snapshot = resolvedSnapshot

        TimelineView(.periodic(from: .now, by: progressTick(for: snapshot))) { context in
            timelineContent(snapshot: snapshot, at: context.date)
        }
        .onAppear {
            nowPlayingViewModel.setLyricsPresentationActive(
                true,
                source: lyricsPresentationSource
            )
        }
        .onDisappear {
            nowPlayingViewModel.setLyricsPresentationActive(
                false,
                source: lyricsPresentationSource
            )
        }
    }

    @ViewBuilder
    private func timelineContent(snapshot: NowPlayingSnapshot, at date: Date) -> some View {
        if let line = activeSyncedLyricLine(at: date) {
            lyricContent(snapshot: snapshot, line: line)
        } else {
            compactPlayerContent(snapshot: snapshot)
        }
    }

    private func compactPlayerContent(snapshot: NowPlayingSnapshot) -> some View {
        HStack {
            ArtworkView(
                nowPlayingViewModel: nowPlayingViewModel,
                width: isDynamicIsland ? 18 : 24,
                height: isDynamicIsland ? 18 : 24,
                cornerRadius: isDynamicIsland ? 3 : 5,
                usesFlipAnimation: settings.isNowPlayingArtwork3DEffectEnabled
            )
            Spacer()
            
            LightweightNowPlayingEqualizerView(
                isPlaying: snapshot.isPlaying,
                colors: [
                    nowPlayingViewModel.artworkPalette.equalizerHighlightColor,
                    nowPlayingViewModel.artworkPalette.equalizerBaseColor
                ]
            )
            .frame(width: isDynamicIsland ? 14 : 18, height: isDynamicIsland ? 12 : 16)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, isDynamicIsland ? 10.scaled(by: scale) : 14.scaled(by: scale))
    }

    private func lyricContent(snapshot: NowPlayingSnapshot, line: LyricLine) -> some View {
        HStack(spacing: isDynamicIsland ? 7 : 9) {
            ArtworkView(
                nowPlayingViewModel: nowPlayingViewModel,
                width: isDynamicIsland ? 18 : 23,
                height: isDynamicIsland ? 18 : 23,
                cornerRadius: isDynamicIsland ? 3 : 5,
                usesFlipAnimation: settings.isNowPlayingArtwork3DEffectEnabled
            )

            VStack(alignment: .leading, spacing: 3) {
                MarqueeText(
                    .constant(line.text),
                    font: .system(size: isDynamicIsland ? 11 : 12, weight: .semibold, design: .rounded),
                    nsFont: .headline,
                    textColor: .white.opacity(0.92),
                    backgroundColor: .clear,
                    minDuration: 1.4,
                    frameWidth: isDynamicIsland ? 120.scaled(by: scale) : 172.scaled(by: scale)
                )

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(nsColor: nowPlayingViewModel.artworkPalette.equalizerHighlightColor),
                                Color(nsColor: nowPlayingViewModel.artworkPalette.equalizerBaseColor).opacity(0.55)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: isDynamicIsland ? 34.scaled(by: scale) : 46.scaled(by: scale), height: 1.5)
            }

            Spacer(minLength: 0)

            LightweightNowPlayingEqualizerView(
                isPlaying: snapshot.isPlaying,
                colors: [
                    nowPlayingViewModel.artworkPalette.equalizerHighlightColor,
                    nowPlayingViewModel.artworkPalette.equalizerBaseColor
                ]
            )
            .frame(width: isDynamicIsland ? 12 : 16, height: isDynamicIsland ? 11 : 14)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, isDynamicIsland ? 10.scaled(by: scale) : 13.scaled(by: scale))
        .background {
            Capsule(style: .continuous)
                .fill(Color(nsColor: nowPlayingViewModel.artworkPalette.equalizerBaseColor).opacity(0.12))
                .blur(radius: 10)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }

    private func activeSyncedLyricLine(at date: Date) -> LyricLine? {
        guard case .loaded(let lyrics) = nowPlayingViewModel.lyricsState,
              lyrics.isSynced,
              let activeIndex = lyrics.activeLineIndex(at: nowPlayingViewModel.elapsedTime(at: date)),
              lyrics.lines.indices.contains(activeIndex) else {
            return nil
        }

        let line = lyrics.lines[activeIndex]
        return line.text.trimmed.isEmpty ? nil : line
    }

    private func progressTick(for snapshot: NowPlayingSnapshot) -> TimeInterval {
        guard snapshot.isPlaying else { return 30.0 }

        if case .loaded(let lyrics) = nowPlayingViewModel.lyricsState, lyrics.isSynced {
            return 0.35
        }

        return 1.0
    }
}
