//
//  RewardsView.swift
//  Redeem loyalty points for discount vouchers, applied at checkout.
//

import SwiftUI

struct RewardsView: View {
    @EnvironmentObject var store: AppStore

    struct Reward: Identifiable { let id = UUID(); let cost: Int; let value: Int }
    private let rewards = [Reward(cost: 500, value: 50), Reward(cost: 1000, value: 120), Reward(cost: 2000, value: 300)]
    @State private var flash = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Card {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(store.loyaltyPoints)").font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundStyle(Brand.label)
                            Text(L("points fidélité")).font(.caption).foregroundStyle(Brand.textSoft)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Fmt.price(store.voucherDH)).font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(Brand.orange)
                            Text("bon disponible").font(.caption2).foregroundStyle(Brand.textSoft)
                        }
                    }
                }
                if flash {
                    Label("Bon ajouté à votre solde", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(Color(hex: 0x16A34A))
                }
                ForEach(rewards) { r in card(r) }
                Text("Vos bons se déduisent automatiquement au paiement.")
                    .font(.caption).foregroundStyle(Brand.textSoft).multilineTextAlignment(.center).padding(.top, 4)
            }
            .padding(18)
        }
        .background(Brand.sand.ignoresSafeArea())
        .navigationTitle(L("Mes avantages"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func card(_ r: Reward) -> some View {
        let affordable = store.loyaltyPoints >= r.cost
        return Card {
            HStack(spacing: 14) {
                Image(systemName: "gift.fill")
                    .font(.title3).foregroundStyle(Brand.orange)
                    .frame(width: 44, height: 44).background(Brand.orange.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bon de \(Fmt.price(r.value))").font(.system(.headline, design: .rounded)).foregroundStyle(Brand.label)
                    Text("\(r.cost) points").font(.caption).foregroundStyle(Brand.textSoft)
                }
                Spacer()
                Button {
                    if store.redeem(cost: r.cost, voucher: r.value) {
                        Haptics.success()
                        withAnimation { flash = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { flash = false } }
                    } else {
                        Haptics.warning()
                    }
                } label: {
                    Text(L("Échanger")).font(.subheadline.weight(.bold))
                        .padding(.vertical, 9).padding(.horizontal, 16)
                        .background(affordable ? AnyShapeStyle(Brand.warm) : AnyShapeStyle(Color.black.opacity(0.1)),
                                    in: Capsule())
                        .foregroundStyle(affordable ? .white : Brand.textSoft)
                }
                .disabled(!affordable)
            }
        }
    }
}

#Preview { NavigationStack { RewardsView() }.environmentObject(AppStore()) }
