import Foundation
import VioCore

@MainActor
public protocol VioUIRuntimeControlling: AnyObject {
    func ensureCommerceBootstrapApplied() async
}

@MainActor
public final class DefaultVioUIRuntimeController: VioUIRuntimeControlling {
    public init() {}

    public func ensureCommerceBootstrapApplied() async {
        await VioSession.shared.ensureCommerceBootstrapApplied()
    }
}

@MainActor
public enum VioUIRuntimeAdapter {
    public static var controller: VioUIRuntimeControlling = DefaultVioUIRuntimeController()
}
