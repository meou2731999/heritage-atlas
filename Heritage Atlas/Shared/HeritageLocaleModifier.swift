import HeritageAtlasCore
import SwiftUI

extension View {
    func heritageLocale(_ kinship: KinshipLocale) -> some View {
        HeritageLocale.kinship = kinship
        return environment(\.locale, kinship.locale)
    }
}
