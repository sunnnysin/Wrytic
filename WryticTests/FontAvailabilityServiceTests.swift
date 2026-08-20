import Testing
import SwiftUI
@testable import Wrytic

struct FontAvailabilityServiceTests {
    private let service = SystemFontAvailabilityService()

    @Test func everyFontSupportsAtLeastOneWeightOnDevice() {
        for font in AppFont.allCases {
            let supportsAnyWeight = FontWeight.allCases.contains { service.isAvailable(font, weight: $0) }
            #expect(supportsAnyWeight, "\(font.displayName) should support at least one weight")
        }
    }

    @Test func noteworthyHasNoRegularWeight() {
        #expect(service.isAvailable(.noteworthy, weight: .regular) == false)
        #expect(service.isAvailable(.noteworthy, weight: .light))
        #expect(service.isAvailable(.noteworthy, weight: .bold))
    }

    @Test func georgiaHasNoLightWeight() {
        #expect(service.isAvailable(.georgia, weight: .light) == false)
        #expect(service.isAvailable(.georgia, weight: .regular))
        #expect(service.isAvailable(.georgia, weight: .bold))
    }

    @Test func systemFontsAreAlwaysAvailableAtEveryWeight() {
        for weight in FontWeight.allCases {
            #expect(service.isAvailable(.system, weight: weight))
            #expect(service.isAvailable(.systemRounded, weight: weight))
        }
    }

    @Test func systemFontsResolveWithRequestedWeight() {
        #expect(service.resolvedFont(for: .system, weight: .bold, size: 20) == .system(size: 20, weight: .bold))
        #expect(
            service.resolvedFont(for: .systemRounded, weight: .light, size: 20)
                == .system(size: 20, weight: .light, design: .rounded)
        )
    }

    @Test func namedFontResolvesToCustomFontWhenAvailable() {
        #expect(
            service.resolvedFont(for: .chalkboardSE, weight: .bold, size: 20)
                == .custom("ChalkboardSE-Bold", size: 20)
        )
    }

    @Test func missingWeightFallsBackToRegularWeightOfSameFamily() {
        #expect(
            service.resolvedFont(for: .georgia, weight: .light, size: 20)
                == .custom("Georgia", size: 20)
        )
    }

    @Test func unavailableFontFamilyFallsBackToSystem() {
        let unavailable = SystemFontAvailabilityService(fontExists: { _ in false })

        #expect(unavailable.isAvailable(.chalkboardSE, weight: .regular) == false)
        #expect(unavailable.resolvedFont(for: .chalkboardSE, weight: .regular, size: 20) == .system(size: 20))
    }
}
