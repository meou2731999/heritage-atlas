import Foundation
import HeritageAtlasCore
import SwiftData

enum DemoFamilySeeder {
    /// Builds a compact three-generation Vietnamese family for tree demos. Does not run on launch.
    @discardableResult
    static func seed(into context: ModelContext) throws -> UUID {
        func date(_ year: Int, month: Int = 6, day: Int = 15) -> Date {
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            return Calendar(identifier: .gregorian).date(from: components)!
        }

        func person(
            _ fullName: String,
            nickname: String? = nil,
            gender: Gender,
            birth: Int,
            death: Int? = nil,
            occupation: String? = nil
        ) -> Person {
            let model = Person(
                fullName: fullName,
                nickname: nickname,
                gender: gender,
                birthDate: date(birth),
                deathDate: death.map { date($0, month: 3, day: 8) },
                occupation: occupation,
                tags: ["demo"]
            )
            context.insert(model)
            return model
        }

        func parent(_ from: Person, _ to: Person) {
            context.insert(KinRelationship(kind: .parent, fromPerson: from, toPerson: to))
        }

        func spouse(_ from: Person, _ to: Person) {
            context.insert(KinRelationship(kind: .spouse, fromPerson: from, toPerson: to))
        }

        let ongNoi = person("Nguyễn Văn Sơn", nickname: "Ông Nội", gender: .male, birth: 1930, death: 2005)
        let baNoi = person("Lê Thị Xuân", nickname: "Bà Nội", gender: .female, birth: 1932, death: 2010)
        let ongNgoai = person("Trần Văn Long", nickname: "Ông Ngoại", gender: .male, birth: 1931, death: 2008)
        let baNgoai = person("Phạm Thị Lan", nickname: "Bà Ngoại", gender: .female, birth: 1933, death: 2012)

        let bacTrai = person("Nguyễn Văn Minh", nickname: "Bác Trai", gender: .male, birth: 1955, occupation: "Teacher")
        let father = person("Nguyễn Văn Ba", nickname: "Ba", gender: .male, birth: 1960, occupation: "Engineer")
        let chuNam = person("Nguyễn Văn Năm", nickname: "Chú Năm", gender: .male, birth: 1965)
        let coSau = person("Nguyễn Thị Sáu", nickname: "Cô Sáu", gender: .female, birth: 1963)

        let mother = person("Trần Thị Mai", nickname: "Mẹ", gender: .female, birth: 1962, occupation: "Doctor")
        let cauBay = person("Trần Văn Bảy", nickname: "Cậu Bảy", gender: .male, birth: 1958)
        let diTam = person("Trần Thị Tám", nickname: "Dì Tám", gender: .female, birth: 1966)

        let me = person("Nguyễn Văn Quân", nickname: "Quân", gender: .male, birth: 1995, occupation: "Software engineer")
        let sister = person("Nguyễn Thị Linh", nickname: "Linh", gender: .female, birth: 1998)
        let cousin = person("Nguyễn Văn Họ", nickname: "Anh Họ", gender: .male, birth: 1990)

        spouse(ongNoi, baNoi)
        spouse(ongNgoai, baNgoai)
        spouse(father, mother)

        parent(ongNoi, bacTrai)
        parent(baNoi, bacTrai)
        parent(ongNoi, father)
        parent(baNoi, father)
        parent(ongNoi, chuNam)
        parent(baNoi, chuNam)
        parent(ongNoi, coSau)
        parent(baNoi, coSau)

        parent(ongNgoai, mother)
        parent(baNgoai, mother)
        parent(ongNgoai, cauBay)
        parent(baNgoai, cauBay)
        parent(ongNgoai, diTam)
        parent(baNgoai, diTam)

        parent(father, me)
        parent(mother, me)
        parent(father, sister)
        parent(mother, sister)
        parent(chuNam, cousin)

        me.notes = "Sample proband for exploring the tree and kinship names."

        func place(_ name: String, lat: Double, lon: Double, notes: String? = nil) -> Place {
            let model = Place(name: name, latitude: lat, longitude: lon, notes: notes)
            context.insert(model)
            return model
        }

        func link(_ person: Person, _ place: Place, _ role: PlaceRole, from: Int? = nil, to: Int? = nil) {
            context.insert(PersonPlace(role: role, person: person, place: place, yearFrom: from, yearTo: to))
        }

        let nhaHaNoi = place("Nhà Hà Nội", lat: 21.028511, lon: 105.854444, notes: "Family home")
        let nhaHue = place("Nhà thời thơ ấu — Huế", lat: 16.4637, lon: 107.5909)
        let truong = place("Trường Chu Văn An", lat: 21.0278, lon: 105.832)
        let coQuanBa = place("Cơ quan Ba", lat: 21.0227, lon: 105.8194)
        let benhVien = place("Bệnh viện Bạch Mai", lat: 20.9995, lon: 105.8413)
        let damCuoi = place("Thủy Tạ", lat: 21.0311, lon: 105.8522)
        let vanDien = place("Nghĩa trang Văn Điển", lat: 20.9476, lon: 105.8608, notes: "Paternal burials")
        let anBang = place("Nghĩa trang An Bằng", lat: 16.4542, lon: 107.5554, notes: "Maternal burials near Huế")

        link(me, nhaHaNoi, .home, from: 1995)
        link(sister, nhaHaNoi, .home, from: 1998)
        link(father, nhaHaNoi, .home, from: 1990)
        link(mother, nhaHaNoi, .home, from: 1990)
        link(me, nhaHue, .childhoodHome, from: 1995, to: 2001)
        link(father, nhaHue, .childhoodHome, from: 1960, to: 1978)
        link(ongNoi, nhaHue, .home, from: 1955, to: 2005)
        link(baNoi, nhaHue, .home, from: 1955, to: 2010)
        link(me, truong, .school, from: 2007, to: 2013)
        link(father, coQuanBa, .workplace, from: 1985, to: 2020)
        link(mother, benhVien, .workplace, from: 1988)
        link(me, benhVien, .born, from: 1995)
        link(father, damCuoi, .wedding, from: 1993)
        link(mother, damCuoi, .wedding, from: 1993)
        link(ongNoi, vanDien, .burial, from: 2005)
        link(baNoi, vanDien, .burial, from: 2010)
        link(ongNgoai, anBang, .burial, from: 2008)
        link(baNgoai, anBang, .burial, from: 2012)

        @discardableResult
        func event(
            _ person: Person,
            _ date: Date,
            _ title: String,
            _ kind: TimelineEventKind,
            place: Place? = nil,
            memoryIDs: [UUID] = []
        ) -> TimelineEvent {
            let model = TimelineEvent(person: person, date: date, title: title, kind: kind, place: place, memoryIDs: memoryIDs)
            context.insert(model)
            return model
        }

        let hueStory = Memory(
            kind: .story,
            title: "Ông Nội kể chuyện Huế",
            occurredOn: date(2001),
            body: "Ông ngồi trên ghế mây, kể về sông Hương lúc sương sớm. Quân còn nhớ mùi trầm và tiếng cười của bà.",
            personIDs: [ongNoi.id, me.id],
            placeIDs: [nhaHue.id],
            isFeatured: true
        )
        context.insert(hueStory)

        let tetNote = Memory(
            kind: .text,
            title: "Tết ở nhà Hà Nội",
            occurredOn: date(2012, month: 1, day: 23),
            body: "Bánh chưng, họ hàng đầy nhà, Linh trốn ra sân chơi.",
            personIDs: [me.id, sister.id, father.id, mother.id],
            placeIDs: [nhaHaNoi.id]
        )
        context.insert(tetNote)

        let gio = Memory(
            kind: .event,
            title: "Giỗ Ông Nội",
            occurredOn: date(2006, month: 3, day: 8),
            body: "Cả nhà ra Văn Điển. Ba kể lại chuyện ông dạy học.",
            personIDs: [ongNoi.id, father.id, me.id],
            placeIDs: [vanDien.id]
        )
        context.insert(gio)

        let weddingStory = Memory(
            kind: .story,
            title: "Đám cưới Ba Mẹ",
            occurredOn: date(1993),
            body: "Họ cưới ở Thủy Tạ. Bà Ngoại nói đó là ngày Hà Nội đẹp nhất mùa thu.",
            personIDs: [father.id, mother.id],
            placeIDs: [damCuoi.id],
            isFeatured: true
        )
        context.insert(weddingStory)

        event(ongNoi, date(1930), "Sinh ở Huế", .born, place: nhaHue)
        let ongNoiDied = event(ongNoi, date(2005, month: 3, day: 8), "Mất", .died, place: vanDien, memoryIDs: [gio.id])
        event(father, date(1960), "Sinh", .born, place: nhaHue)
        let fatherMarried = event(father, date(1993), "Kết hôn", .married, place: damCuoi, memoryIDs: [weddingStory.id])
        event(me, date(1995), "Sinh", .born, place: benhVien)
        let movedHaNoi = event(me, date(2001), "Chuyển ra Hà Nội", .moved, place: nhaHaNoi, memoryIDs: [hueStory.id])
        gio.timelineEventID = ongNoiDied.id
        weddingStory.timelineEventID = fatherMarried.id
        hueStory.timelineEventID = movedHaNoi.id

        let ancestralWalk = FamilyWalk(
            title: "Huế to Hà Nội",
            stopIDs: [nhaHue.id, damCuoi.id, nhaHaNoi.id, vanDien.id],
            notes: "Childhood home, parents’ wedding, the Hà Nội house, then Văn Điển."
        )
        context.insert(ancestralWalk)

        let settings = AppSettings.current(in: context)
        if settings.mePersonID == nil {
            settings.mePersonID = me.id
        }
        settings.favoritePersonIDs = uniqued([me.id, father.id, ongNoi.id] + settings.favoritePersonIDs)
        settings.localeKinship = .vi
        if settings.currentFamilyWalkID == nil {
            settings.currentFamilyWalkID = ancestralWalk.id
        }
        return me.id
    }

    private static func uniqued(_ ids: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return ids.filter { seen.insert($0).inserted }
    }
}
