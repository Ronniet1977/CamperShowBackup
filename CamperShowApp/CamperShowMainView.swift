import SwiftUI

struct CamperShowMainView: View {
    @StateObject var viewModel = CamperViewModel()
    @AppStorage("userRole") var userRole: String = ""
    @State private var selectedTab = "Import"

    var body: some View {
        Group {
            switch userRole {
            case "":
                LoginView()
            case "driver":
                DriverMainView(viewModel: viewModel)
            default:
                MainTabView(viewModel: viewModel, selectedTab: $selectedTab)
            }
        }
    }
}
