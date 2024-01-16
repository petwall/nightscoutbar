//
//  nightscoutViewModel.swift
//  nightscoutbar
//
//  Created by Peter Wallman on 2023-12-11.
//
import SwiftUI
import Combine
import CryptoKit
import Foundation

class NightscoutViewModel: ObservableObject {
    @Published var glucoseValue: Double = 0.0
    @Published var direction: String = "?"
    @Published var lastTimeStamp: String = ""
    @Published var connectionStatus: ConnectionStatus = ConnectionStatus.empty
    @Published var connectionResult: String = "Server connection status..."
    @Published var currentBackend: BackendType = BackendType.nightscout
    private var timer: Timer?
    
    struct NightscoutEntry: Decodable {
        let sgv: Double
        let direction: String? // sometimes there is no direction data in the json object
        let dateString: String
    }

    //  TODO: add support to connect to Dexcom share...
    enum BackendType {
        case nightscout
        case dexcom
    }
    
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
    
    var serverInMmol: Bool {
        UserDefaults.standard.bool(forKey: "ServerInMmol")
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
            }
            else {
                self.connectionStatus = ConnectionStatus.error
            }
            self.connectionResult = "Request URL: \(request.url?.absoluteString ?? "Invalid URL")\n"
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
            
            if let httpResponse = response as? HTTPURLResponse {
                DispatchQueue.main.async {
                    if httpResponse.statusCode == 200 {
                        self.connectionStatus = ConnectionStatus.ok
                    }
                    else {
                        self.connectionStatus = ConnectionStatus.error
                    }
                    self.connectionResult += "Response Status Code: \(httpResponse.statusCode)\n"
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
            
            // Parse the json data
            do {
                let entries = try JSONDecoder().decode([NightscoutEntry].self, from: data)
                if let entry = entries.first {
                    DispatchQueue.main.async {
                        if self.useMmol {
                            if self.serverInMmol {
                                self.glucoseValue = Double(entry.sgv)
                            } else {
                                self.glucoseValue = Double(entry.sgv) / mmolToMgdlConstant
                            }
                        } else {
                            if self.serverInMmol {
                                self.glucoseValue = Double(entry.sgv) * mmolToMgdlConstant
                            } else {
                                self.glucoseValue = Double(entry.sgv)
                            }
                        }
                        
                        // sometimes there is no 'direction' entry in the json data, fallback to '?'
                        if let direction = entry.direction {
                            self.direction = self.arrow(for: direction)
                        } else {
                            self.direction = "?"
                        }
                        
                        let isoFormatter = ISO8601DateFormatter()
                        isoFormatter.formatOptions =  [.withInternetDateTime, .withFractionalSeconds]
                        
                        if let serverTimeStamp = isoFormatter.date(from: entry.dateString) {
                            let clientTimeStamp = Date()
                            
                            // Calculate the time difference from current time to last recorded value in seconds
                            let timeDifference = abs(serverTimeStamp.timeIntervalSince(clientTimeStamp))
                            
                            if timeDifference > 360 { // 6 minutes
                                let dateFormatter = DateFormatter()
                                dateFormatter.dateFormat = "HH:mm"
                                dateFormatter.timeZone = TimeZone.current // format the serverTimeStamp in the client's time zone
                                let formattedServerTime = dateFormatter.string(from: serverTimeStamp)
                                
                                self.lastTimeStamp = " [" + formattedServerTime + "]"
                            } else {
                                self.lastTimeStamp = ""
                            }
                        } else {
                            self.connectionResult += "Could not read dateString - invalid format\n"
                        }
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
        
        // Handle nil and represent that as '?'
        return direction.flatMap { arrows[$0] } ?? "?"
    }
}
