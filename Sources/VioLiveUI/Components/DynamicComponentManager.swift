import Foundation
import Combine

@MainActor
public final class DynamicComponentManager: ObservableObject {
    public static let shared = DynamicComponentManager()
    
    @Published public private(set) var registered: [String: DynamicComponent] = [:]
    @Published public private(set) var activeComponents: [DynamicComponent] = []
    
    private var timers: [String: AnyCancellable] = [:]
    private init() {}
    
    public func reset() {
        timers.values.forEach { _ in }
        timers.removeAll()
        registered.removeAll()
        activeComponents.removeAll()
    }
    
    public func register(_ components: [DynamicComponent]) {
        print("[DynamicManager] Register components count=\(components.count)")
        for c in components {
            print("[DynamicManager] Register id=\(c.id) type=\(c.type) start=\(String(describing: c.startTime)) end=\(String(describing: c.endTime)) trigger=\(String(describing: c.triggerOn))")
            registered[c.id] = c
            scheduleIfNeeded(component: c)
        }
    }
    
    public func register(_ component: DynamicComponent) {
        print("[DynamicManager] Register single id=\(component.id) type=\(component.type)")
        registered[component.id] = component
        scheduleIfNeeded(component: component)
    }
    
    public func activate(id: String) {
        guard let c = registered[id] else { return }
        if !activeComponents.contains(where: { $0.id == id }) {
            print("[DynamicManager] Activate id=\(id)")
            activeComponents.append(c)
            scheduleDeactivationIfNeeded(component: c)
        }
    }
    
    public func deactivate(id: String) {
        print("[DynamicManager] Deactivate id=\(id)")
        activeComponents.removeAll { $0.id == id }
        timers[id]?.cancel()
        timers.removeValue(forKey: id)
    }
    
    private func scheduleIfNeeded(component: DynamicComponent) {
        print("[DynamicManager] scheduleIfNeeded for id=\(component.id)")
        print("[DynamicManager] startTime=\(String(describing: component.startTime))")
        print("[DynamicManager] endTime=\(String(describing: component.endTime))")
        print("[DynamicManager] triggerOn=\(String(describing: component.triggerOn))")
        print("[DynamicManager] current date=\(Date())")
        
        // If startTime is in future, schedule; if past or nil and trigger is stream_start, activate now
        if let start = component.startTime, start > Date() {
            let interval = start.timeIntervalSinceNow
            print("[DynamicManager] Schedule activation id=\(component.id) in=\(interval)s")
            timers[component.id] = Timer.publish(every: interval, on: .main, in: .common)
                .autoconnect()
                .first()
                .sink { [weak self] _ in
                    print("[DynamicManager] Timer fired -> activate id=\(component.id)")
                    self?.activate(id: component.id)
                }
        } else if component.triggerOn == .streamStart || component.startTime == nil {
            print("[DynamicManager] Immediate activation id=\(component.id) trigger=\(String(describing: component.triggerOn)) start=\(String(describing: component.startTime))")
            activate(id: component.id)
        } else {
            print("[DynamicManager] No activation conditions met for id=\(component.id)")
        }
    }
    
    private func scheduleDeactivationIfNeeded(component: DynamicComponent) {
        if let end = component.endTime, end > Date() {
            let interval = end.timeIntervalSinceNow
            print("[DynamicManager] Schedule deactivation id=\(component.id) in=\(interval)s")
            timers[component.id] = Timer.publish(every: interval, on: .main, in: .common)
                .autoconnect()
                .first()
                .sink { [weak self] _ in
                    print("[DynamicManager] Timer fired -> deactivate id=\(component.id)")
                    self?.deactivate(id: component.id)
                }
        } else if let banner = bannerDuration(component: component) {
            print("[DynamicManager] Schedule banner duration deactivation id=\(component.id) duration=\(banner)s")
            timers[component.id] = Timer.publish(every: banner, on: .main, in: .common)
                .autoconnect()
                .first()
                .sink { [weak self] _ in
                    print("[DynamicManager] Banner duration elapsed -> deactivate id=\(component.id)")
                    self?.deactivate(id: component.id)
                }
        }
    }
    
    private func bannerDuration(component: DynamicComponent) -> TimeInterval? {
        if case let .banner(data) = component.data, let d = data.duration { return d }
        return nil
    }
}


