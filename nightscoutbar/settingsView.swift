//
//  settingsView.swift
//  nightscoutbar
//
//  Created by Peter Wallman on 2023-12-11.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: NightscoutViewModel
    @State private var serverURL: String = UserDefaults.standard.string(forKey: "ServerURL") ?? ""
    @State private var apiSecret: String = UserDefaults.standard.string(forKey: "APISecret") ?? ""
    @State private var showValuesInMmol: Bool = UserDefaults.standard.bool(forKey: "ShowValuesInMmol")
    @State private var serverInMmol: Bool = UserDefaults.standard.bool(forKey: "ServerInMmol")

    // This function saves the values to UserDefaults
    func saveToUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(serverURL, forKey: "ServerURL")
        defaults.set(apiSecret, forKey: "APISecret")
        defaults.set(showValuesInMmol, forKey: "ShowValuesInMmol")
        defaults.set(serverInMmol, forKey: "ServerInMmol")
    }

    func saveAndTest() {
        saveToUserDefaults()
        // test a request with current settings
        viewModel.fetchData()
    }
    
    func closeSettingsView() {
        // Close the window
        if let window = NSApplication.shared.windows.first(where: { $0.contentView is NSHostingView<SettingsView> }) {
            window.close()
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("NightscoutBar Settings")
                .font(.headline)
                .padding(.top, 10)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Nightscout Server URL:")
                TextField("Enter Server URL", text: $serverURL)
                
                Text("API Secret:")
                SecureField("Enter API Secret", text: $apiSecret)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                HStack(spacing: 20) {
                    Toggle(isOn: $showValuesInMmol) {
                        Text("Use mmol")
                    }
                    Toggle(isOn: $serverInMmol) {
                        Text("Server is set to mmol")
                    }

                }
                HStack(spacing: 20) {
                    Button(action: saveAndTest) {
                        Text("Save and Test")
                    }
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    Button(action: closeSettingsView) {
                        Text("Close")
                    }
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                TextEditor(text: $viewModel.connectionResult)
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.gray)
                    )
            //        .scrollContentBackground(.hidden)
                    .frame(height: 100)
                    .background(Color.gray)
                    .cornerRadius(8)
                    .border(statusColor(for: viewModel.connectionStatus), width: 2)
            }
        }
        .padding()
        .frame(width: 400)
    }
    
    private func statusColor(for connectionStatus: NightscoutViewModel.ConnectionStatus) -> Color {
        switch connectionStatus {
        case NightscoutViewModel.ConnectionStatus.ok:
            return .green
        case NightscoutViewModel.ConnectionStatus.error:
            return .red
        default:
            return .gray
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock or actual ViewModel instance
        let viewModel = NightscoutViewModel()
        // Pass it to the SettingsView
        SettingsView(viewModel: viewModel)
    }
}
