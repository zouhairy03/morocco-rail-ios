//
//  ReductionCardView.swift
//  Register & verify a reduction card (Tarifa / Jeune / Senior), linked to the
//  account. The discount only applies once a matching card is verified, and the
//  loyalty programme is tied to it.
//

import SwiftUI

struct ReductionCardView: View {
    @EnvironmentObject var store: AppStore
    @State private var type: DiscountCard = .tarifa
    @State private var holder = ""
    @State private var number = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let c = store.reductionCard, c.verified {
                    linkedCard(c)
                } else {
                    form
                }
            }
            .padding(18)
        }
        .background(Brand.sand.ignoresSafeArea())
        .navigationTitle(L("Carte de réduction"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if holder.isEmpty { holder = store.memberName } }
    }

    // MARK: Linked state

    private func linkedCard(_ c: ReductionCard) -> some View {
        VStack(spacing: 16) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Brand.warm)
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(c.type.rawValue.uppercased())
                            .font(.caption.weight(.bold)).tracking(2).foregroundStyle(.white.opacity(0.95))
                        Spacer()
                        Label(L("Vérifiée"), systemImage: "checkmark.seal.fill")
                            .font(.caption2.weight(.bold)).foregroundStyle(.white)
                    }
                    Spacer()
                    Text(c.masked)
                        .font(.system(.title2, design: .monospaced).weight(.bold)).foregroundStyle(.white)
                    Spacer()
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("Titulaire").uppercased()).font(.system(size: 8, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
                            Text(c.holder).font(.system(.subheadline, design: .rounded).weight(.bold)).foregroundStyle(.white)
                        }
                        Spacer()
                        Text("−\(Int(c.type.reduction * 100))%")
                            .font(.system(.title3, design: .rounded).weight(.heavy)).foregroundStyle(.white)
                    }
                }
                .padding(20)
            }
            .frame(height: 190)
            .shadow(color: Brand.orange.opacity(0.3), radius: 16, y: 8)

            infoRow("checkmark.seal.fill", L("Carte vérifiée"),
                    L("La réduction s'applique automatiquement à vos réservations."))
            infoRow("star.fill", L("Fidélité liée"),
                    c.type == .tarifa ? L("Vos points fidélité sont crédités sur cette carte (×1,5).")
                                      : L("Vos points fidélité sont crédités sur cette carte."))

            Button(role: .destructive) { store.removeReductionCard(); Haptics.warning() } label: {
                Label(L("Supprimer la carte"), systemImage: "trash")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.red.opacity(0.1), in: Capsule())
                    .foregroundStyle(Color.red)
            }
        }
    }

    private func infoRow(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon).foregroundStyle(Brand.orange)
                    .frame(width: 28, height: 28).background(Brand.orange.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.label)
                    Text(subtitle).font(.caption).foregroundStyle(Brand.textSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Registration form

    private var form: some View {
        VStack(spacing: 16) {
            Card {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "creditcard.and.123").font(.title3).foregroundStyle(Brand.orange)
                    Text(L("Liez votre carte de réduction ONCF pour appliquer vos tarifs réduits et cumuler des points."))
                        .font(.subheadline).foregroundStyle(Brand.textSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 14) {
                    Text(L("Type de carte").uppercased()).font(.system(size: 10, weight: .semibold)).foregroundStyle(Brand.textSoft)
                    Picker("", selection: $type) {
                        ForEach(DiscountCard.registrable) { Text($0.short).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    field(L("Nom du titulaire"), text: $holder, placeholder: "Youssef Zouhair")
                    field(L("Numéro de carte"), text: $number, placeholder: "1234 5678", keyboard: .numberPad)

                    if let e = error {
                        Text(e).font(.caption).foregroundStyle(.red)
                    }

                    Button { link() } label: {
                        HStack {
                            if busy { ProgressView().tint(.white) }
                            Text(busy ? L("Vérification…") : L("Vérifier & lier"))
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(busy)
                }
            }
        }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String,
                       keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.system(size: 10, weight: .semibold)).foregroundStyle(Brand.textSoft)
            TextField(placeholder, text: text)
                .keyboardType(keyboard).autocorrectionDisabled()
                .padding(.vertical, 12).padding(.horizontal, 13)
                .background(Brand.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel(Text(label))
        }
    }

    private func link() {
        busy = true; error = nil
        Task {
            let ok = await store.linkReductionCard(type: type, number: number, holder: holder)
            busy = false
            if ok { Haptics.success() }
            else { error = L("Vérification échouée. Vérifiez le numéro et le nom."); Haptics.error() }
        }
    }
}

#Preview { NavigationStack { ReductionCardView() }.environmentObject(AppStore()) }
