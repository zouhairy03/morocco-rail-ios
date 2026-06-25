//
//  SettingsView.swift
//  Security, notifications and reminder preferences.
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var lock: LockManager
    @AppStorage("reminderLeadMinutes") private var leadMinutes = 30
    @AppStorage("serviceAlertsEnabled") private var serviceAlerts = true
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined

    private let leadOptions = [15, 30, 45, 60, 90]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if lock.isAvailable { security }
                notifications
                reminders
                about
            }
            .padding(18)
        }
        .background(Brand.sand.ignoresSafeArea())
        .navigationTitle(L("Réglages"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refreshStatus() }
    }

    // MARK: Security

    private var security: some View {
        section(L("Sécurité")) {
            Toggle(isOn: $lock.enabled) {
                rowLabel(lock.biometryIcon,
                         String(format: L("Verrouiller avec %@"), lock.biometryName),
                         L("Demander l'authentification à l'ouverture"))
            }
            .tint(Brand.orange)
            .padding(.vertical, 4).padding(.horizontal, 12)
        }
    }

    // MARK: Notifications

    private var notifications: some View {
        section(L("Notifications")) {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    icon("bell.fill")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("Autorisation")).font(.system(.body, design: .rounded)).foregroundStyle(Brand.label)
                        Text(statusText).font(.caption2).foregroundStyle(statusColor)
                    }
                    Spacer()
                    if notifStatus == .notDetermined {
                        Button(L("Activer")) {
                            NotificationService.requestAuthorization { _ in refreshStatus() }
                        }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.orange)
                    } else if notifStatus == .denied {
                        Button(L("Réglages iOS")) { openSystemSettings() }
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.orange)
                    }
                }
                .padding(.vertical, 10).padding(.horizontal, 12)

                Divider().padding(.leading, 52)

                Toggle(isOn: $serviceAlerts) {
                    rowLabel("exclamationmark.triangle.fill",
                             L("Alertes trafic"),
                             L("Perturbations et retards sur vos lignes"))
                }
                .tint(Brand.orange)
                .padding(.vertical, 4).padding(.horizontal, 12)
            }
        }
    }

    // MARK: Reminders

    private var reminders: some View {
        section(L("Rappel de départ")) {
            VStack(alignment: .leading, spacing: 10) {
                rowLabel("clock.fill", L("Me prévenir avant le départ"),
                         L("Délai du rappel automatique"))
                    .padding(.horizontal, 12).padding(.top, 6)
                Picker(L("Délai"), selection: $leadMinutes) {
                    ForEach(leadOptions, id: \.self) { m in
                        Text(String(format: L("%d min"), m)).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12).padding(.bottom, 8)
            }
        }
    }

    // MARK: About

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private var about: some View {
        section(L("À propos")) {
            VStack(spacing: 0) {
                Button {
                    if let url = URL(string: "mailto:support@oncf-voyages.ma") { UIApplication.shared.open(url) }
                } label: {
                    HStack(spacing: 14) {
                        icon("envelope.fill")
                        Text(L("Contacter le support")).font(.system(.body, design: .rounded)).foregroundStyle(Brand.label)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Brand.textSoft)
                    }
                    .padding(.vertical, 10).padding(.horizontal, 12)
                }
                Divider().padding(.leading, 52)
                HStack(spacing: 14) {
                    icon("info.circle.fill")
                    Text(L("Version")).font(.system(.body, design: .rounded)).foregroundStyle(Brand.label)
                    Spacer()
                    Text(appVersion).font(.subheadline).foregroundStyle(Brand.textSoft)
                }
                .padding(.vertical, 10).padding(.horizontal, 12)
            }
        }
    }

    // MARK: Helpers

    private var statusText: String {
        switch notifStatus {
        case .authorized, .provisional, .ephemeral: return L("Activées")
        case .denied: return L("Refusées — activez-les dans Réglages")
        default: return L("Non configurées")
        }
    }
    private var statusColor: Color {
        switch notifStatus {
        case .authorized, .provisional, .ephemeral: return Color(hex: 0x16A34A)
        case .denied: return .red
        default: return Brand.textSoft
        }
    }

    private func refreshStatus() {
        NotificationService.authorizationStatus { notifStatus = $0 }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold)).tracking(1).foregroundStyle(Brand.textSoft)
                .padding(.leading, 6)
            Card(padding: 6) { content() }
        }
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name).font(.subheadline).foregroundStyle(Brand.orange)
            .frame(width: 30, height: 30)
            .background(Brand.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func rowLabel(_ name: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 14) {
            icon(name)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(.body, design: .rounded)).foregroundStyle(Brand.label)
                Text(subtitle).font(.caption2).foregroundStyle(Brand.textSoft)
            }
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environmentObject(LockManager())
}
