import Foundation

func expect(_ condition: Bool, _ message: String) {
    if !condition {
        print("FAIL: \(message)")
        exit(1)
    }
}

func expectEqual(_ actual: String?, _ expected: String, _ what: String) {
    expect(actual == expected, "\(what): expected \"\(expected)\", got \"\(actual ?? "nil")\"")
}

// Locale and number style go through KVC so the test does not depend on whether NSLocale bridges to
// Locale or on how NumberFormatter's accessors import.
func use(_ identifier: String, _ formatter: NumberFormatter) {
    formatter.setValue(NSLocale(localeIdentifier: identifier), forKey: "locale")
}

func isDecimal(_ formatter: NumberFormatter) -> Bool {
    return formatter.value(forKey: "numberStyle") as? NSNumber == NSNumber(value: Double(NumberFormatter.Style.decimal.rawValue))
}

expect(Formatter.UnitStyle.short.rawValue == 1 && Formatter.UnitStyle.long.rawValue == 3, "Formatter.UnitStyle raw values")
expect(LengthFormatter.Unit.millimeter.rawValue == 8 && LengthFormatter.Unit.inch.rawValue == 1281
       && LengthFormatter.Unit.mile.rawValue == 1284, "LengthFormatter.Unit raw values")
expect(MassFormatter.Unit.kilogram.rawValue == 14 && MassFormatter.Unit.ounce.rawValue == 1537
       && MassFormatter.Unit.stone.rawValue == 1283, "MassFormatter.Unit raw values")
expect(EnergyFormatter.Unit.joule.rawValue == 11 && EnergyFormatter.Unit.kilocalorie.rawValue == 1794,
       "EnergyFormatter.Unit raw values")

let length = LengthFormatter()
expect(length.unitStyle == .medium && !length.isForPersonHeightUse, "LengthFormatter defaults")
expect(isDecimal(length.numberFormatter), "default number formatter is decimal")
use("en_US_POSIX", length.numberFormatter)
expectEqual(length.string(fromValue: 5, unit: .kilometer), "5 km", "medium km")
length.unitStyle = .short
expectEqual(length.string(fromValue: 5, unit: .kilometer), "5km", "short km")
length.unitStyle = .long
expectEqual(length.string(fromValue: 1, unit: .meter), "1 meter", "long singular")
expectEqual(length.string(fromValue: 2.5, unit: .foot), "2.5 feet", "long plural")
length.unitStyle = .medium

use("en_US", length.numberFormatter)
expectEqual(length.string(fromMeters: 3218.688), "2 mi", "US picks miles")
var usedLength = LengthFormatter.Unit.meter
expectEqual(length.unitString(fromMeters: 3218.688, usedUnit: &usedLength), "mi", "US unit string")
expect(usedLength == .mile, "US used unit is mile")
use("de_DE", length.numberFormatter)
expectEqual(length.string(fromMeters: 1500), "1,5 km", "metric picks kilometers")
expectEqual(length.string(for: NSNumber(value: 0.25)), "25 cm", "string(for:) takes meters")
expect(length.string(for: "5") == nil, "string(for:) is nil for a non-number")

length.isForPersonHeightUse = true
expectEqual(length.string(fromMeters: 1.8), "180 cm", "metric person height")
use("en_US", length.numberFormatter)
expectEqual(length.string(fromMeters: 1.778), "5 ft, 10 in", "US person height")

let lengthCopy = length.copy() as! LengthFormatter
expect(lengthCopy.isForPersonHeightUse && lengthCopy.numberFormatter !== length.numberFormatter, "copy is deep")
length.numberFormatter = nil
expect(length.numberFormatter != nil && isDecimal(length.numberFormatter), "numberFormatter is null_resettable")

var parsed: AnyObject?
var reason: NSString?
expect(!length.getObjectValue(&parsed, for: "5 km", errorDescription: &reason), "parsing is unsupported")

let mass = MassFormatter()
expect(mass.unitStyle == .medium && !mass.isForPersonMassUse, "MassFormatter defaults")
use("en_US", mass.numberFormatter)
expectEqual(mass.string(fromKilograms: 2), "4.409 lb", "US picks pounds")
expectEqual(mass.string(fromValue: 1.5, unit: .stone), "1 st, 7 lb", "stone with pounds")
use("de_DE", mass.numberFormatter)
expectEqual(mass.string(fromKilograms: 0.5), "500 g", "metric picks grams")
var usedMass = MassFormatter.Unit.gram
expectEqual(mass.unitString(fromKilograms: 70, usedUnit: &usedMass), "kg", "metric unit string")
expect(usedMass == .kilogram, "metric used unit is kilogram")
mass.unitStyle = .long
expectEqual(mass.string(fromValue: 1, unit: .kilogram), "1 kilogram", "long singular mass")

let energy = EnergyFormatter()
expect(energy.unitStyle == .medium && !energy.isForFoodEnergyUse, "EnergyFormatter defaults")
use("en_US", energy.numberFormatter)
expectEqual(energy.string(fromValue: 100, unit: .kilocalorie), "100 kcal", "kcal")
expectEqual(energy.string(fromJoules: 418.4), "100 cal", "US picks calories")
energy.isForFoodEnergyUse = true
expectEqual(energy.string(fromValue: 100, unit: .kilocalorie), "100 Cal", "food energy")
use("de_DE", energy.numberFormatter)
var usedEnergy = EnergyFormatter.Unit.joule
expectEqual(energy.unitString(fromJoules: 2500, usedUnit: &usedEnergy), "kJ", "metric unit string")
expect(usedEnergy == .kilojoule, "metric used unit is kilojoule")
expectEqual(energy.string(fromJoules: 2500), "2,5 kJ", "metric picks kilojoules")

let archived = NSKeyedArchiver.archivedData(withRootObject: energy)
let decoded = NSKeyedUnarchiver.unarchiveObject(with: archived) as? EnergyFormatter
expect(decoded != nil && decoded!.isForFoodEnergyUse && decoded!.unitStyle == .medium, "keyed coding round trip")

print("PASS unit-formatters")
