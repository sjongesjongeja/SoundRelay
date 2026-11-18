import SwiftUI

struct ContentView: View {
    @StateObject private var discovery = DiscoveryManager()
    @StateObject private var streamer = AudioStreamer()
    
    @State private var serverIp: String = ""
    @State private var serverPort: String = "59102"
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.09)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Image(systemName: "waveform.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(Color(red: 0.06, green: 0.73, blue: 0.51))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SoundRelay")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("iOS Audio Streamer")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Text(streamer.isStreaming ? "● Live" : "Niet verbonden")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(streamer.isStreaming ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                            .foregroundColor(streamer.isStreaming ? .green : .gray)
                            .cornerRadius(12)
                    }
                    .padding(.top, 10)
                    
                    // Discovered PC Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Gevonden PC's op Wi-Fi")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(Color(red: 0.02, green: 0.71, blue: 0.83))
                            
                            Spacer()
                            
                            Button(action: {
                                discovery.startDiscovery()
                            }) {
                                if discovery.isSearching {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Zoeken")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color(red: 0.06, green: 0.73, blue: 0.51))
                                }
                            }
                        }
                        
                        if let server = discovery.discoveredServer {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(server.name)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(server.ip)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Button("Kiezen") {
                                    serverIp = server.ip
                                    serverPort = String(server.audioPort)
                                }
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color(red: 0.06, green: 0.73, blue: 0.51))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .padding(12)
                            .background(Color(red: 0.12, green: 0.14, blue: 0.18))
                            .cornerRadius(10)
                        } else {
                            Text(discovery.isSearching ? "Zoeken naar PC op lokaal Wi-Fi netwerk..." : "Geen PC automatisch gevonden. Vul het IP handmatig in.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(16)
                    .background(Color(red: 0.10, green: 0.12, blue: 0.16))
                    .cornerRadius(16)
                    
                    // Manual IP & Port Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PC Verbindingsgegevens")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 12) {
                            TextField("192.168.1.xxx", text: $serverIp)
                                .keyboardType(.numbersAndPunctuation)
                                .padding(12)
                                .background(Color(red: 0.06, green: 0.07, blue: 0.09))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            
                            TextField("59102", text: $serverPort)
                                .keyboardType(.numberPad)
                                .frame(width: 80)
                                .padding(12)
                                .background(Color(red: 0.06, green: 0.07, blue: 0.09))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding(16)
                    .background(Color(red: 0.10, green: 0.12, blue: 0.16))
                    .cornerRadius(16)
                    
                    // Live Audio Meter
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Geluidsniveau")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                            Spacer()
                            Text(streamer.isStreaming ? "48 kHz • 16-bit Stereo" : "Inactief")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 12)
                                
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(LinearGradient(
                                        colors: [Color.green, Color.cyan, Color.red],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    .frame(width: geo.size.width * CGFloat(streamer.peakLevel), height: 12)
                                    .animation(.easeOut(duration: 0.05), value: streamer.peakLevel)
                            }
                        }
                        .frame(height: 12)
                    }
                    .padding(16)
                    .background(Color(red: 0.10, green: 0.12, blue: 0.16))
                    .cornerRadius(16)
                    
                    // Big Action Button
                    Button(action: {
                        if streamer.isStreaming {
                            streamer.stopStreaming()
                        } else {
                            let ip = serverIp.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !ip.isEmpty else {
                                alertMessage = "Vul eerst het IP-adres van je PC in."
                                showAlert = true
                                return
                            }
                            let port = Int(serverPort) ?? 59102
                            let success = streamer.startStreaming(toHost: ip, port: port)
                            if !success {
                                alertMessage = "Kon de audio stream niet starten. Controleer je microfoon-toegang."
                                showAlert = true
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: streamer.isStreaming ? "stop.fill" : "play.fill")
                            Text(streamer.isStreaming ? "Stop Audio Stream" : "Start Audio Stream")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(streamer.isStreaming ? Color.red : Color(red: 0.06, green: 0.73, blue: 0.51))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .padding(.top, 10)
                    
                    // Tip
                    Text("💡 Tip: SoundRelay blijft doorspelen op de achtergrond. Je kunt je iPhone vergrendelen zonder dat de stream stopt.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                }
                .padding(20)
            }
        }
        .onAppear {
            discovery.startDiscovery()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("SoundRelay"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
}
