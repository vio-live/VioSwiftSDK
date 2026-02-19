//
//  VideoPlayerViewModel.swift
//  VioCastingUI
//

import Foundation
import SwiftUI
import Combine

#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(AVKit)
import AVKit
#endif

@MainActor
public class VideoPlayerViewModel: ObservableObject {
    @Published public var player: AVPlayer?
    @Published public var isPlaying = false
    @Published public var showControls = true
    @Published public var progress: Double = 0
    @Published public var currentTimeText = "00:00"
    @Published public var durationText = "2:10:48"
    @Published public var isMuted = true
    @Published public var playbackSpeed: Float = 1.0

    private var timeObserver: Any?
    private var controlsTimer: Timer?

    public init() {}

    public func setupPlayer() {
        #if os(iOS) || os(tvOS)
        if let localVideoPath = Bundle.main.path(forResource: "match", ofType: "mp4") {
            let url = URL(fileURLWithPath: localVideoPath)
            initializePlayer(with: url)
            return
        }

        let firebaseVideoURL = "https://firebasestorage.googleapis.com/v0/b/tipio-1ec97.appspot.com/o/bar.v.psg.1.ucl.01.10.2025.fullmatchsports.com.1080p.mp4?alt=media&token=593ce8a1-0462-4c37-98c3-e399f25e3853"

        guard let videoURL = URL(string: firebaseVideoURL) else {
            return
        }

        initializePlayer(with: videoURL)
        #endif
    }

    private func initializePlayer(with url: URL) {
        #if os(iOS) || os(tvOS)
        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)

        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Ignore audio session errors
        }
        #endif

        self.player = player
        player.play()
        isPlaying = true

        setupTimeObserver()
        startControlsTimer()
        #endif
    }

    private func setupTimeObserver() {
        guard let player = player else { return }

        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }

            if let duration = player.currentItem?.duration, duration.seconds > 0 {
                let progress = time.seconds / duration.seconds
                self.progress = min(max(progress, 0), 1)
                self.currentTimeText = self.formatTime(time.seconds)
                self.durationText = self.formatTime(duration.seconds)
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    public func togglePlayPause() {
        guard let player = player else { return }

        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }

        startControlsTimer()
    }

    public func toggleMute() {
        guard let player = player else { return }
        isMuted.toggle()
        player.isMuted = isMuted
    }

    public func seekBackward() {
        guard let player = player else { return }
        let currentTime = player.currentTime()
        let newTime = CMTime(seconds: max(0, currentTime.seconds - 10), preferredTimescale: currentTime.timescale)
        player.seek(to: newTime)
    }

    public func seekForward() {
        guard let player = player else { return }
        let currentTime = player.currentTime()
        let newTime = CMTime(seconds: currentTime.seconds + 10, preferredTimescale: currentTime.timescale)
        player.seek(to: newTime)
    }

    public func togglePlaybackSpeed() {
        guard let player = player else { return }

        switch playbackSpeed {
        case 1.0:
            playbackSpeed = 1.25
        case 1.25:
            playbackSpeed = 1.5
        case 1.5:
            playbackSpeed = 2.0
        default:
            playbackSpeed = 1.0
        }

        player.rate = playbackSpeed
    }

    public func toggleControlsVisibility() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showControls.toggle()
        }

        if showControls {
            startControlsTimer()
        }
    }

    private func startControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self?.showControls = false
                }
            }
        }
    }

    public func cleanup() {
        timeObserver = nil
        controlsTimer?.invalidate()
        controlsTimer = nil
        player?.pause()
        player = nil
    }
}
