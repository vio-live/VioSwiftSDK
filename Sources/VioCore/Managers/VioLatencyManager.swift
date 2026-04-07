import Foundation
import Combine

/// Manager responsible for buffering WebSocket events and releasing them based on a configurable latency offset.
/// This prevents "spoilers" in live sports where the data feed might be faster than the video stream.
@MainActor
public class VioLatencyManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = VioLatencyManager()
    
    // MARK: - Properties
    
    /// Latency offset in seconds (e.g., 30s delay).
    @Published public var latencyOffsetSeconds: Double = 0
    
    /// Queue of pending events with their scheduled release time.
    private var eventQueue: [(releaseTime: Date, action: () -> Void)] = []
    
    private var timer: Timer?
    
    private init() {
        startTimer()
    }
    
    // MARK: - Public Methods
    
    /// Buffers an action to be executed after the current latency offset.
    /// - Parameter action: The closure to execute.
    public func bufferAction(_ action: @escaping () -> Void) {
        guard latencyOffsetSeconds > 0 else {
            action()
            return
        }
        
        let releaseTime = Date().addingTimeInterval(latencyOffsetSeconds)
        eventQueue.append((releaseTime: releaseTime, action: action))
        VioLogger.debug("Action buffered. Release in \(latencyOffsetSeconds)s", component: "VioLatencyManager")
    }
    
    /// Clears all buffered actions.
    public func clearBuffer() {
        eventQueue.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.processQueue()
            }
        }
    }
    
    private func processQueue() {
        let now = Date()
        
        // Find events that are ready to be released
        let readyEvents = eventQueue.filter { $0.releaseTime <= now }
        
        // Remove from queue
        eventQueue.removeAll { $0.releaseTime <= now }
        
        // Execute actions
        for event in readyEvents {
            event.action()
        }
    }
}
