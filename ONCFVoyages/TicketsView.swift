//
//  TicketsView.swift
//  Booked tickets, confirmation sheet and the full e-ticket detail.
//

import SwiftUI

// MARK: - Confirmation (shown right after booking)

struct ConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    let ticket: Ticket

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color(hex: 0x16A34A))
                    .padding(.top, 16)
                Text(L("Réservation confirmée !"))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(Brand.label)
                Text("Votre e-billet \(ticket.reference) a été ajouté à vos billets.")
                    .font(.subheadline).foregroundStyle(Brand.textSoft)
                    .multilineTextAlignment(.center)

                BoardingPass(ticket: ticket)

                Button { dismiss() } label: { Text(L("Voir mes billets")) }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
        }
        .background(Brand.sand.ignoresSafeArea())
    }
}

// MARK: - Tickets list

struct TicketsView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        NavigationStack {
            Group {
                if store.tickets.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(store.tickets) { t in
                                NavigationLink { TicketDetailView(ticket: t) } label: { BoardingPass(ticket: t) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(18)
                    }
                }
            }
            .background(Brand.sand.ignoresSafeArea())
            .navigationTitle(L("Mes billets"))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "ticket").font(.system(size: 48)).foregroundStyle(Brand.textSoft)
            Text(L("Aucun billet")).font(.headline).foregroundStyle(Brand.label)
            Text("Réservez un voyage depuis l'accueil.").font(.subheadline).foregroundStyle(Brand.textSoft)
        }
    }
}

// MARK: - Ticket detail (e-ticket with QR)

struct TicketDetailView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let ticket: Ticket
    @State private var reminderOn = false
    @State private var showCancel = false
    @State private var share: ShareItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                BoardingPass(ticket: ticket)

                Card {
                    VStack(spacing: 14) {
                        Text("EMBARQUEMENT").font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(Brand.textSoft)
                        QRCodeView(string: "ONCF|\(ticket.reference)|\(ticket.passengerName)", size: 170)
                        Text(ticket.reference)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .tracking(2).foregroundStyle(Brand.label)
                        Divider()
                        HStack {
                            label("Voyageur", ticket.passengerName)
                            Spacer()
                            label("Total", Fmt.price(ticket.total), trailing: true)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                travelersCard
                actions
                caution
            }
            .padding(18)
        }
        .background(Brand.sand.ignoresSafeArea())
        .navigationTitle(L("Billet"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $share) { item in ShareSheet(items: [item.url]) }
        .confirmationDialog("Annuler ce billet ?", isPresented: $showCancel, titleVisibility: .visible) {
            let q = store.refundQuote(for: ticket)
            Button(q.refund > 0 ? "Annuler · remboursé \(Fmt.price(q.refund))" : "Annuler (non remboursé)",
                   role: .destructive) {
                store.cancel(ticket)
                dismiss()
            }
            Button("Garder mon billet", role: .cancel) {}
        } message: {
            Text(store.refundQuote(for: ticket).label)
        }
    }

    private var travelersCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("VOYAGEURS").font(.system(size: 10, weight: .bold)).foregroundStyle(Brand.textSoft)
                ForEach(ticket.travelers) { p in
                    HStack(spacing: 10) {
                        Image(systemName: p.type.icon).font(.caption).foregroundStyle(Brand.orange)
                            .frame(width: 26, height: 26).background(Brand.orange.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.name).font(.system(.subheadline, design: .rounded).weight(.semibold)).foregroundStyle(Brand.label)
                            Text(p.type.rawValue).font(.caption2).foregroundStyle(Brand.textSoft)
                        }
                        Spacer()
                        Text("Voit. \(ticket.coach) · \(p.seat)").font(.caption.weight(.semibold)).foregroundStyle(Brand.label)
                    }
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                if let u = TicketPDF.generate(ticket) { share = ShareItem(url: u); Haptics.tap() }
            } label: {
                Label(L("Télécharger le billet"), systemImage: "arrow.down.doc.fill")
            }
            .buttonStyle(PrimaryButtonStyle())

            HStack(spacing: 12) {
                Button {
                    NotificationService.scheduleReminder(for: ticket) { ok in reminderOn = ok }
                } label: {
                    Label(reminderOn ? "Rappel activé" : L("Me rappeler"),
                          systemImage: reminderOn ? "bell.fill" : "bell")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Brand.cream, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.black.opacity(0.08)))
                        .foregroundStyle(Brand.label)
                }
                NavigationLink { ExchangeView(ticket: ticket) } label: {
                    Label(L("Échanger"), systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Brand.cream, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.black.opacity(0.08)))
                        .foregroundStyle(Brand.label)
                }
            }
            Button(role: .destructive) { showCancel = true } label: {
                Label(L("Annuler & rembourser"), systemImage: "xmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(Color.red.opacity(0.1), in: Capsule())
                    .foregroundStyle(Color.red)
            }
        }
    }

    private func label(_ t: String, _ v: String, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 2) {
            Text(t.uppercased()).font(.system(size: 9, weight: .semibold)).foregroundStyle(Brand.textSoft)
            Text(v).font(.system(.subheadline, design: .rounded).weight(.bold)).foregroundStyle(Brand.label)
        }
    }

    private var caution: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Brand.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(L("À SAVOIR")).font(.system(size: 10, weight: .bold)).foregroundStyle(Brand.clay)
                Text("Présentez-vous 20 min avant le départ, muni d'une pièce d'identité valide. Billet nominatif et non cessible · échange & annulation gratuits jusqu'à 1h avant le départ.")
                    .font(.caption).foregroundStyle(Brand.textSoft)
            }
        }
        .padding(14)
        .background(Color(hex: 0xFFF4EA), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color(hex: 0xFFE0C2)))
    }
}

/// Identifiable wrapper so a generated PDF URL can drive `.sheet(item:)`.
struct ShareItem: Identifiable { let id = UUID(); let url: URL }

/// Native share sheet (UIActivityViewController) for exporting the PDF e-ticket.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

#Preview { TicketsView().environmentObject(AppStore()) }
