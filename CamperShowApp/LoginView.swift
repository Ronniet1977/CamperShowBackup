import SwiftUI//import SwiftUI

struct LoginView: View {
    @AppStorage("userRole") var userRole: String = ""
    @AppStorage("currentDriverName") var currentDriverName: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Select Your Role")
                    .font(.title)
                    .bold()
                    .padding()

                Button("🚚 Driver") {
                    userRole = "driver"
                }
                .buttonStyle(.borderedProminent)
                .font(.title3)
                .padding(.horizontal)

                Button("🛠️ Admin") {
                    userRole = "admin"
                }
                .buttonStyle(.bordered)
                .font(.title3)
                .padding(.horizontal)
            }
        }
    }
}
//  LoginView.swift
//  Camper Show
//
//  Created by Ronald Thayer Jr on 5/1/25.
//

