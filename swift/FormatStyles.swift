// Swift Foundation's date format styles (iOS 15) and Date.now, as apps built
// against the iOS 16 SDK call them. Declarations follow that SDK's public
// interface, so this module (Foundation, like NSSortDescriptor.swift) emits
// Foundation's own symbol names; the formatting is NSDateFormatter's, in
// FoundationSupplementBridge.m.
import DarlingFoundationSupplementBridge

/// Foundation.Date's stand-in. Date is resilient, so clients pass and return
/// it by address and never see its layout; this one has the same layout as
/// the overlay's (the time since the reference date). Its own type symbols
/// are not exported (build.sh): the overlay's Date is the one apps link.
public struct Date {
    internal var _time: Double
    internal init(_time: Double) { self._time = _time }
}

@available(iOS 15.0, *)
public protocol FormatStyle: Decodable, Encodable, Hashable {
    associatedtype FormatInput
    associatedtype FormatOutput
    func format(_ value: Self.FormatInput) -> Self.FormatOutput
}

/// A string the bridge allocated with malloc.
private func adopt(_ text: UnsafeMutablePointer<CChar>) -> String {
    defer { free(text) }
    return String(cString: text)
}

@available(iOS 15.0, *)
extension Date {
    public static var now: Date { Date(_time: CFAbsoluteTimeGetCurrent()) }

    public struct FormatStyle: Codable, Hashable {
        public var date: DateStyle?
        public var time: TimeStyle?

        public init(date: DateStyle? = nil, time: TimeStyle? = nil) {
            self.date = date
            self.time = time
        }

        // The NSDateFormatterStyle each one stands for.
        public struct DateStyle: Codable, Hashable {
            let style: Int32
            public static let omitted = DateStyle(style: 0)
            public static let numeric = DateStyle(style: 1)
            public static let abbreviated = DateStyle(style: 2)
            public static let long = DateStyle(style: 3)
            public static let complete = DateStyle(style: 4)
        }

        public struct TimeStyle: Codable, Hashable {
            let style: Int32
            public static let omitted = TimeStyle(style: 0)
            public static let shortened = TimeStyle(style: 1)
            public static let standard = TimeStyle(style: 2)
            public static let complete = TimeStyle(style: 4)
        }
    }

    public struct RelativeFormatStyle: Codable, Hashable {
        public struct UnitsStyle: Codable, Hashable {
            let width: Int32
            public static let wide = UnitsStyle(width: 0)
            public static let spellOut = UnitsStyle(width: 1)
            public static let abbreviated = UnitsStyle(width: 2)
            public static let narrow = UnitsStyle(width: 3)
        }

        public struct Presentation: Codable, Hashable {
            let isNamed: Bool
            public static let numeric = Presentation(isNamed: false)
            public static let named = Presentation(isNamed: true)
        }

        public var presentation: Presentation
        public var unitsStyle: UnitsStyle

        public init(presentation: Presentation = .numeric, unitsStyle: UnitsStyle = .wide) {
            self.presentation = presentation
            self.unitsStyle = unitsStyle
        }
    }

    public func formatted<F>(_ format: F) -> F.FormatOutput where F: Foundation.FormatStyle, F.FormatInput == Date {
        format.format(self)
    }

    public func formatted(date: Date.FormatStyle.DateStyle, time: Date.FormatStyle.TimeStyle) -> String {
        Date.FormatStyle(date: date, time: time).format(self)
    }

    public func formatted() -> String {
        Date.FormatStyle(date: .numeric, time: .shortened).format(self)
    }
}

@available(iOS 15.0, *)
extension Date.FormatStyle: FormatStyle {
    public func format(_ value: Date) -> String {
        // Neither part chosen means both, as Date.FormatStyle() prints the date and time.
        let both = date == nil && time == nil
        let dateStyle = date ?? (both ? .numeric : .omitted)
        let timeStyle = time ?? (both ? .shortened : .omitted)
        return adopt(DarlingFoundationFormatDate(value._time, dateStyle.style, timeStyle.style))
    }
}

@available(iOS 15.0, *)
extension Date.RelativeFormatStyle: FormatStyle {
    public func format(_ destination: Date) -> String {
        adopt(DarlingFoundationFormatRelativeDate(destination._time, presentation.isNamed ? 1 : 0, unitsStyle.width))
    }
}

@available(iOS 15.0, *)
extension FormatStyle where Self == Date.RelativeFormatStyle {
    public static func relative(presentation: Date.RelativeFormatStyle.Presentation,
                                unitsStyle: Date.RelativeFormatStyle.UnitsStyle = .wide) -> Self {
        Date.RelativeFormatStyle(presentation: presentation, unitsStyle: unitsStyle)
    }
}
