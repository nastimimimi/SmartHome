import SwiftUI

// MARK: - Models
struct RFIDEvent: Identifiable {
    let id = UUID()
        let cardID: String
        let date: Date
        let success: Bool
}

struct SecurityAlert: Identifiable {
    let id = UUID()
    let sensorID: String
    let message: String
    let date: Date
}

// DTO для работы с сервером
struct RFIDEventDTO: Codable {
    let cardID: String
    let date: String
    let success: Bool
}

// MARK: - ViewModel
class SmartHomeViewModel: ObservableObject {
    @Published var rfidEvents: [RFIDEvent] = []
    @Published var securityAlerts: [SecurityAlert] = []
    @Published var lightColor: Color = .white
    @Published var isLightOn: Bool = false
    @Published var fireDetected: Bool = false
    
    private let serverURL = "http://172.168.85.187:5002"
    private var timer: Timer?
    
    init() {

        fetchRFIDEvents()
        fetchFireStatus()

        // каждые 5 секунд обновление события и пожар
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.fetchRFIDEvents()
            self?.fetchFireStatus()
        }
    }
    
    // MARK: - 🔥 Ручное управление пожаркой
    func setFireStatus(_ isOn: Bool) {
        guard let url = URL(string: "\(serverURL)/fire/\(isOn ? "on" : "off")") else { return }
        URLSession.shared.dataTask(with: url).resume()
    }

    
    // MARK: - 🔹 Работа с сервером
    
    func fetchRFIDEvents() {
        guard let url = URL(string: "\(serverURL)/events") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil else { return }
            do {
                let decoded = try JSONDecoder().decode([RFIDEventDTO].self, from: data)
                DispatchQueue.main.async {
                    var mapped = decoded.compactMap { dto -> RFIDEvent? in
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
                        if let date = formatter.date(from: dto.date) {
                            return RFIDEvent(cardID: dto.cardID, date: date, success: dto.success)
                        }
                        return nil
                    }
                    mapped.reverse()
                    self?.rfidEvents = Array(mapped.prefix(5))
                }
            } catch {
                print("JSON decode error:", error.localizedDescription)
            }
        }.resume()
    }
    
    // MARK: - 💡 Управление светом (палитра)
    func setLightColor(r: Int, g: Int, b: Int) {
        guard let url = URL(string: "\(serverURL)/setColor?r=\(r)&g=\(g)&b=\(b)") else { return }
        URLSession.shared.dataTask(with: url).resume()
        DispatchQueue.main.async {
            self.isLightOn = !(r == 0 && g == 0 && b == 0)
            self.lightColor = Color(red: Double(r)/255.0, green: Double(g)/255.0, blue: Double(b)/255.0)
        }
    }
    
    // MARK: - 🔥 Пожарная система
    func fetchFireStatus() {
        guard let url = URL(string: "\(serverURL)/fire_status") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil else { return }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Bool],
               let fireDetected = json["fireDetected"] {
                DispatchQueue.main.async {
                    self?.fireDetected = fireDetected
                }
            }
        }.resume()
    }
}

    
    // MARK: - Main Content
struct ContentView: View {
    @StateObject var vm = SmartHomeViewModel()

    var body: some View {
        TabView {
            DashboardView(vm: vm)
                .tabItem { Label("Главная", systemImage: "house.fill") }
            
            RFIDEventsView(vm: vm)
                .tabItem { Label("RFID", systemImage: "key.fill") }
            
            FireView(vm: vm)
                .tabItem { Label("Пожар", systemImage: "flame.fill") }

            LightingView(vm: vm)
                .tabItem { Label("Свет", systemImage: "lightbulb.fill") }

        }
    }
}


// MARK: - RFID Events
struct RFIDEventsView: View {
    @ObservedObject var vm: SmartHomeViewModel
    @State private var isRefreshing = false   // Стан для pull-to-refresh

    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                Text("🔐 RFID події")
                    .font(.largeTitle.bold())
                    .foregroundColor(.black)
                    .padding(.top)

                if vm.rfidEvents.isEmpty && !isRefreshing {
                    ProgressView("Завантаження подій...")
                        .padding(.top, 60)
                }

                else if vm.rfidEvents.isEmpty {
                    DashboardCard(title: "RFID події", icon: "key.fill", iconColor: .orange) {
                        Text("Події відсутні")
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                }

                else {
                    ForEach(vm.rfidEvents) { event in
                        DashboardCard(
                            title: "Карта: \(event.cardID)",
                            icon: "key.fill",
                            iconColor: event.success ? .green : .red
                        ) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.date, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(event.date, style: .time)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(event.success ? " Успішно" : " Доступ заборонено")
                                    .foregroundColor(event.success ? .green : .red)
                                    .bold()
                            }
                        }
                    }
                }
            }
            .padding()
        }

        // Фон
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.yellow.opacity(0.4),
                    Color.orange.opacity(0.6)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )

        .refreshable {
            isRefreshing = true
            await refreshData()
            isRefreshing = false
        }
    }

    // Асинхронне оновлення
    private func refreshData() async {
        await withCheckedContinuation { continuation in
            vm.fetchRFIDEvents()
            // невелика затримка для анімації
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                continuation.resume()
            }
        }
    }
}


    
    // MARK: - Security Alerts
    struct SecurityView: View {
        let alerts: [SecurityAlert]
        
        var body: some View {
            NavigationView {
                List(alerts) { alert in
                    VStack(alignment: .leading) {
                        Text("Датчик: \(alert.sensorID)")
                            .font(.headline)
                        Text(alert.message).foregroundColor(.red)
                        Text(alert.date, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .background(
                    LinearGradient(gradient: Gradient(colors: [Color.yellow.opacity(0.4),
                                                               Color.orange.opacity(0.6)]),
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                )
                .navigationTitle("Система безопасности")
            }
        }
    }
    
    // MARK: - Lighting Control
import SwiftUI

// MARK: - LightingView (палитра цветов + пожар)
struct LightingView: View {
    @ObservedObject var vm: SmartHomeViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 💡 Включение / выключение света
                DashboardCard(title: "Состояние света", icon: "lightbulb.fill") {
                    Toggle(isOn: $vm.isLightOn) {
                        Text(vm.isLightOn ? "💡 Включен" : "🌙 Выключен")
                            .font(.headline)
                            .foregroundColor(vm.isLightOn ? .green : .gray)
                    }
                }
                
                // Палитра цветов
                DashboardCard(title: "Цвет освещения", icon: "paintpalette.fill") {
                    HStack {
                        ColorButton(color: .red) { vm.setLightColor(r: 255, g: 0, b: 0) }
                        ColorButton(color: .green) { vm.setLightColor(r: 0, g: 255, b: 0) }
                        ColorButton(color: .blue) { vm.setLightColor(r: 0, g: 0, b: 255) }
                        ColorButton(color: .yellow) { vm.setLightColor(r: 255, g: 255, b: 0) }
                        ColorButton(color: .pink) { vm.setLightColor(r: 255, g: 105, b: 180) }
                    }
                }
                
                // Пожарная сигнализация
                DashboardCard(title: "Пожарная система", icon: "flame.fill") {
                    if vm.fireDetected {
                        Text(" Пожар обнаружен!")
                            .foregroundColor(.red)
                            .bold()
                    } else {
                        Text(" Система в норме")
                            .foregroundColor(.green)
                            .bold()
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.yellow.opacity(0.4), Color.orange.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Освещение и пожар")
    }
}

// MARK: - Кнопка цвета
struct ColorButton: View {
    var color: Color
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 50, height: 50)
                .shadow(radius: 2)
        }
    }
}



// MARK: - FireControlView
// MARK: - FireControlView
struct FireView: View {
    @ObservedObject var vm: SmartHomeViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Text(" Пожарная сигнализация")
                .font(.title.bold())
                .foregroundColor(.red)
            
            if vm.fireDetected {
                Text(" Сигнализация активна!")
                    .foregroundColor(.red)
                    .bold()
            } else {
                Text(" Всё спокойно")
                    .foregroundColor(.green)
                    .bold()
            }
            
            HStack(spacing: 20) {
                Button(action: { vm.setFireStatus(true) }) {
                    Text("Включить")
                        .padding()
                        .frame(width: 120)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Button(action: { vm.setFireStatus(false) }) {
                    Text("Выключить")
                        .padding()
                        .frame(width: 120)
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
        .padding()
    }
}


    
    // MARK: - DashboardCard
struct DashboardCard<Content: View>: View {
    var title: String
    var icon: String
    var iconColor: Color
    var content: Content
    
    init(title: String, icon: String, iconColor: Color = .orange, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.black)
            } icon: {
                Image(systemName: icon)
                    .foregroundColor(iconColor)  
            }
            
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}



    // MARK: - Preview
    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            ContentView()
        }
    }
    

