import SwiftUI

struct MainTabView: View {
    @ObservedObject var viewModel: CamperViewModel
    @Binding var selectedTab: String
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                ImportCampersView(viewModel: viewModel)
            }
            .tabItem {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            .tag("Import")
            
            NavigationView {
                AssignCampersView(viewModel: viewModel)
            }
            .tabItem {
                Label("Assign", systemImage: "person.2.fill")
            }
            .tag("Assign")
            
            NavigationView {
                InventoryView(viewModel: viewModel)
            }
            .tabItem {
                Label("Inventory", systemImage: "list.bullet.rectangle")
            }
            .tag("Inventory")
            
            NavigationView {
                RoundsView(viewModel: viewModel)
            }
            .tabItem {
                Label("Rounds", systemImage: "flag.checkered")
            }
            .tag("Rounds")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
