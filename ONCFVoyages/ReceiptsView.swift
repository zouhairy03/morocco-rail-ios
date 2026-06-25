//
//  ReceiptsView.swift
//  Invoices / receipts generated at payment.
//

import SwiftUI

struct ReceiptsView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        Group {
            if store.invoices.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text").font(.system(size: 44)).foregroundStyle(Brand.textSoft)
                    Text("Aucun reçu").font(.headline).foregroundStyle(Brand.label)
                    Text("Vos factures apparaîtront ici après un paiement.")
                        .font(.subheadline).foregroundStyle(Brand.textSoft).multilineTextAlignment(.center)
                }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(store.invoices) { inv in receipt(inv) }
                    }.padding(18)
                }
            }
        }
        .background(Brand.sand.ignoresSafeArea())
        .navigationTitle("Mes reçus")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func receipt(_ inv: Invoice) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FACTURE").font(.system(size: 9, weight: .bold)).foregroundStyle(Brand.textSoft)
                        Text(inv.number).font(.system(.subheadline, design: .rounded).weight(.bold)).foregroundStyle(Brand.label)
                    }
                    Spacer()
                    Text(Fmt.price(inv.amount)).font(.system(.title3, design: .rounded).weight(.heavy)).foregroundStyle(Brand.label)
                }
                Divider()
                row("Billet", inv.ticketReference)
                row("Payé par", inv.method)
                row("Autorisation", inv.authCode)
                row("Date", Fmt.dayLong.string(from: inv.date))
                HStack {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Color(hex: 0x16A34A))
                    Text("Payé · \(inv.payer)").font(.caption).foregroundStyle(Brand.textSoft)
                }
            }
        }
    }

    private func row(_ l: String, _ v: String) -> some View {
        HStack {
            Text(l).font(.caption).foregroundStyle(Brand.textSoft)
            Spacer()
            Text(v).font(.caption.weight(.semibold)).foregroundStyle(Brand.label)
        }
    }
}

#Preview {
    NavigationStack { ReceiptsView() }.environmentObject(AppStore())
}
