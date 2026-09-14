import Foundation
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var settings: AppSettings
    @Published var runtimeStatuses: [RuntimeStatus] = []
    @Published var isLoadingStatus = false
    @Published var errorMessage: String?

    private let runtimeService: RuntimeService

    init(settings: AppSettings, runtimeService: RuntimeService) {
        self.settings = settings
        self.runtimeService = runtimeService
    }

    var selectedProviderID: String {
        get { settings.runtimeProviderID }
        set { settings.runtimeProviderID = newValue }
    }

    var initialProviderName: String {
        runtimeStatuses.first?.providerName ?? "Madeira"
    }

    func loadRuntimeStatus() {
        isLoadingStatus = true
        Task {
            let statuses = await runtimeService.currentStatus()
            runtimeStatuses = statuses
            isLoadingStatus = false
        }
    }

    func selectProvider(_ providerID: String) {
        settings.runtimeProviderID = providerID
        runtimeService.setActiveProvider(providerID)
    }

    func save() {
        // Persist via injected closure if needed by caller.
    }
}