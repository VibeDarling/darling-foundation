import Foundation

@_cdecl("authored_foundation_bridge")
@inline(never)
public func authoredFoundationBridge() -> Int32 {
    let value = "Héllo 🦀"
    let bridged = value._bridgeToObjectiveC()
    if bridged.length != value.utf16.count {
        return 93
    }
    let roundtrip = bridged as String
    if roundtrip != value {
        return 94
    }
    return 0
}
