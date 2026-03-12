//
//  DashboardView.swift
//  Smart Home
//
//  Created by mac on 17.09.2025.
//

import SwiftUI

struct DashboardView: View {
    @ObservedObject var vm: SmartHomeViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text(" Умный дом")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .padding(.top)
                    
                    DashboardCard(title: "Пожарная сигнализация", icon: "flame.fill", iconColor: .red) {
                        lastFireView
                    }

//                    DashboardCard(title: "Безопасность", icon: "shield.fill", iconColor: .blue) {
//                        lastSecurityView
//                    }

                    DashboardCard(title: "RFID вход", icon: "key.fill", iconColor: .green) {
                        lastRFIDView
                    }

//                    Button(action: {vm.simulateFire() }) {
//                                           Text("Симулировать пожар")
//                                               .padding()
//                                               .frame(maxWidth: .infinity)
//                                               .background(Color.red)
//                                               .foregroundColor(.white)
//                                               .cornerRadius(12)
//                                       }
                }
                .padding()
            }
            .background(
                LinearGradient(gradient: Gradient(colors: [Color.yellow.opacity(0.4),
                                                           Color.orange.opacity(0.6)]),
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
                .ignoresSafeArea()
            )
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Subviews
    private var lastFireView: some View {
        Group {
            if vm.fireDetected {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.red)
                    Text("🔥 Пожар обнаружен!")
                        .foregroundColor(.red)
                        .bold()
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Система в норме")
                        .foregroundColor(.green)
                        .bold()
                }
            }
        }
    }
    
    private var lastRFIDView: some View {
        Group {
            if let lastRFID = vm.rfidEvents.first {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Карта: \(lastRFID.cardID)")
                        Text(lastRFID.date, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(lastRFID.success ? " Разрешено" : " Опасно")
                        .foregroundColor(lastRFID.success ? .green : .red)
                        .bold()
                }
            } else {
                Text("Нет событий RFID").foregroundColor(.secondary)
            }
        }
    }
    
//    private var lastSecurityView: some View {
//        Group {
//            if let lastAlert = vm.securityAlerts.first {
//                HStack {
//                    VStack(alignment: .leading) {
//                        Text("Датчик \(lastAlert.sensorID)")
//                            .font(.subheadline)
//                        Text(lastAlert.message)
//                            .foregroundColor(.red)
//                    }
//                    Spacer()
//                    Image(systemName: "exclamationmark.triangle.fill")
//                        .foregroundColor(.red)
//                }
//            } else {
//                Text("Периметр чист ")
//                    .foregroundColor(.green)
//            }
//        }
//    }
}
