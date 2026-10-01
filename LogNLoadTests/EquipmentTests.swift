import Testing
@testable import LogNLoad

struct EquipmentTests {
    @Test func dumbbellsAndKettlebellsAreWeighedPerImplement() {
        #expect(Equipment.dumbbell.weightConvention == .perImplement)
        #expect(Equipment.kettlebell.weightConvention == .perImplement)
    }

    @Test(arguments: [Equipment.barbell, .machine, .cable, .band, .bodyweight, .other])
    func everyOtherEquipmentIsWeighedInTotal(equipment: Equipment) {
        #expect(equipment.weightConvention == .total)
    }

    @Test func thereAreEightEquipmentsAndThreeLoadTypes() {
        #expect(Equipment.allCases.map(\.rawValue) == ["barbell", "dumbbell", "kettlebell", "machine", "cable", "band", "bodyweight", "other"])
        #expect(LoadType.allCases.map(\.rawValue) == ["loaded", "bodyweight", "assisted"])
    }
}
