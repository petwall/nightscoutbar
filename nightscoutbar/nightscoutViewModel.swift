//
//  nightscoutViewModel.swift
//  nightscoutbar
//
//  Created by Peter Wallman on 2023-12-11.
//
import SwiftUI
import Combine
import CryptoKit

class NightscoutViewModel: ObservableObject {
    @Published var glucoseValue: Double = 0.0
    @Published var direction: String = "?"
    @Published var connectionStatus: ConnectionStatus = ConnectionStatus.empty
    @Published var connectionResult: String = "Server connection status..."
    private var timer: Timer?
    
    enum ConnectionStatus {
        case empty
        case ok
        case error
    }
    
    var baseURL: String {
        UserDefaults.standard.string(forKey: "ServerURL") ?? ""
    }
    
    var apiSecret: String {
        UserDefaults.standard.string(forKey: "APISecret") ?? ""
    }
    
    var useMmol: Bool {
        UserDefaults.standard.bool(forKey: "ShowValuesInMmol")
    }

    func startFetching() {
        // Execute the network request immediately
        fetchData()

        // Then set up a timer to fetch data every 30 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.fetchData()
        }
    }
    
    func stopFetching() {
        timer?.invalidate()
        timer = nil
    }

    func fetchData() {
        
        var components = URLComponents(string: baseURL)
        components?.path = "/api/v1/entries.json"  // Append the endpoint path
        components?.queryItems = [URLQueryItem(name: "count", value: "1")]

        var request = URLRequest(url: (components?.url)!)
        request.setValue(sha1Hash(apiSecret), forHTTPHeaderField: "API-SECRET")

        DispatchQueue.main.async {
            if request.url?.absoluteString != nil {
                self.connectionStatus = ConnectionStatus.ok
                self.connectionResult = "Request URL: \(request.url?.absoluteString ?? "Invalid URL")\n"
            }
            else {
                self.connectionStatus = ConnectionStatus.error
                self.connectionResult = "Request URL: \(request.url?.absoluteString ?? "Invalid URL")\n"
            }
        }
        if let headers = request.allHTTPHeaderFields {
            DispatchQueue.main.async {
                self.connectionResult += "Request Headers: \(headers)\n"
            }
        }

        DispatchQueue.main.async {
            self.connectionResult += "Starting network request to \(request.url?.absoluteString ?? "")\n"
        }
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.connectionResult += "Network Request Error: \(error.localizedDescription)\n"
                    self.connectionStatus = ConnectionStatus.error
                }
                return
            }

            // Print response status code
            if let httpResponse = response as? HTTPURLResponse {
                DispatchQueue.main.async {
                    if httpResponse.statusCode == 200 {
                        self.connectionResult += "Response Status Code: \(httpResponse.statusCode)\n"
                        self.connectionStatus = ConnectionStatus.ok
                    }
                    else {
                        self.connectionResult += "Response Status Code: \(httpResponse.statusCode)\n"
                        self.connectionStatus = ConnectionStatus.error
                    }
                }
            }

            // Check and print the raw response data
            guard let data = data else {
                DispatchQueue.main.async {
                    self.connectionStatus = ConnectionStatus.error
                    self.connectionResult += "No data received in response\n"
                }
                return
            }
            DispatchQueue.main.async {
                self.connectionResult += "Raw Response Data: \(String(data: data, encoding: .utf8) ?? "Invalid response data")\n"
            }
            print("Raw Response Data: \(String(data: data, encoding: .utf8) ?? "Invalid response data")\n")
            // Attempt to parse the data
            do {
                let entries = try JSONDecoder().decode([NightscoutEntry].self, from: data)
                if let entry = entries.first {
                    DispatchQueue.main.async {
                        if self.useMmol {
                            self.glucoseValue = Double(entry.sgv) / 18.0
                        } else {
                            self.glucoseValue = Double(entry.sgv)
                        }
                        self.direction = self.arrow(for: entry.direction)

                        // sync variable changes to update the statusbar
                        self.objectWillChange.send()
                    }
                } else {
                    DispatchQueue.main.async {
                        self.connectionStatus = ConnectionStatus.error
                        self.connectionResult += "No entries found in decoded data\n"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.connectionStatus = ConnectionStatus.error
                    self.connectionResult += "JSON Decoding Error: \(error)\n"
                }
            }
        }.resume()
    }

    func sha1Hash(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = Insecure.SHA1.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    func arrow(for direction: String?) -> String {
        let arrows = [
            "Flat": "→",
            "SingleUp": "↑",
            "DoubleUp": "↑↑",
            "DoubleDown": "↓↓",
            "SingleDown": "↓",
            "FortyFiveDown": "↘",
            "FortyFiveUp": "↗"
        ]

        // Handle nil and represent that as '-'
        return direction.flatMap { arrows[$0] } ?? "?"
    }
}

struct NightscoutEntry: Decodable {
    let sgv: Double
    let direction: String
}
