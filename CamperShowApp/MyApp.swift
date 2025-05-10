import SwiftUI

@main
struct CamperShowApp: App {
    @StateObject private var viewModel = CamperViewModel()

    var body: some Scene {
        WindowGroup {
            if viewModel.userRole == nil {
                RoleSelectorView(viewModel: viewModel)
            } else if viewModel.userRole == .driver {
                DriverMainView(viewModel: viewModel)
            } else {
                CamperShowMainView(viewModel: viewModel)
            }
        }
    }
}

