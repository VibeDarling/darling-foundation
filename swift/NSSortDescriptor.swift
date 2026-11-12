//===----------------------------------------------------------------------===//
// This source file is part of the Swift.org open source project
// Copyright (c) 2017 - 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// https://swift.org/LICENSE.txt
// Adapted from swiftlang/swift release/5.4 stdlib/public/Darwin/Foundation/
// NSSortDescriptor.swift and the _bridgeKeyPathToString helper in NSObject.swift.
// Pinned source commit: 845205b4407cb1e50ebe69a4d1174714338337c3.
//===----------------------------------------------------------------------===//
@_exported import Foundation // Clang module; this supplement is module Foundation.
import ObjectiveC
import DarlingFoundationSupplementBridge

private var sortDescriptorKeyPathAssociation: UInt8 = 0
private func sortDescriptorKVCPath(_ path: AnyKeyPath) -> String {
    guard let value = path._kvcKeyPathString else {
        DarlingFoundationSortRejectedKeyPath()
        preconditionFailure("NSSortDescriptor requires an Objective-C compatible key path")
    }
    return value
}
extension NSSortDescriptor {
    public convenience init<Root, Value>(keyPath: KeyPath<Root, Value>, ascending: Bool) {
        // Swift keeps the Array-to-pointer argument alive throughout delegated initialization.
        let key = Array(sortDescriptorKVCPath(keyPath).utf8CString)
        self.init(darlingKVCKeyUTF8: key, ascendingInt: ascending ? 1 : 0)
        objc_setAssociatedObject(self, &sortDescriptorKeyPathAssociation, keyPath, .OBJC_ASSOCIATION_RETAIN)
    }
    public convenience init<Root, Value>(keyPath: KeyPath<Root, Value>, ascending: Bool,
                                         comparator cmptr: @escaping Foundation.Comparator) {
        // Swift keeps the Array-to-pointer argument alive throughout delegated initialization.
        let key = Array(sortDescriptorKVCPath(keyPath).utf8CString)
        self.init(darlingKVCKeyUTF8: key, ascendingInt: ascending ? 1 : 0, comparator: cmptr)
        objc_setAssociatedObject(self, &sortDescriptorKeyPathAssociation, keyPath, .OBJC_ASSOCIATION_RETAIN)
    }
    public var keyPath: AnyKeyPath? {
        objc_getAssociatedObject(self, &sortDescriptorKeyPathAssociation) as? AnyKeyPath
    }
}
