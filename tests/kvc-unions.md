# KVC union operators

Build `kvc-unions.m` as an Objective-C executable linked to Foundation and run
with the candidate framework. Assertions stay enabled even with NDEBUG.
Success prints:

`PASS: KVC unions, duplicates, nesting, key paths, nil rejection and aggregates`

The matrix covers the five documented union operators in their primary shapes:
object arrays, arrays of arrays, and sets of sets. It checks duplicates and
distinct membership without imposing a distinct-result order; nested right-hand
paths; nil-leaf errors; empty arrays/sets; invalid nested collection elements;
and sum/count controls. A custom NSObject holder tests left-hand property paths
and ordinary member-wise lookup. A dictionary alone is not sufficient for that
regression because NSDictionary overrides key-path evaluation.

Semantics follow [Apple's collection operator guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/KeyValueCoding/CollectionOperators.html).
This is not a claim about every collection/operator combination, native macOS
parity for unspecified inputs, or all other KVC behavior.
