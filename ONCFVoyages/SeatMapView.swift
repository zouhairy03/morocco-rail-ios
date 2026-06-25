//
//  SeatMapView.swift
//  Interactive coach seat selection.
//

import SwiftUI

struct SeatMapView: View {
    @Environment(\.dismiss) private var dismiss
    let coach: Int
    @Binding var selection: String
    let taken: Set<String>
    @State private var temp: String

    private let rows = 14

    init(coach: Int, selection: Binding<String>, taken: Set<String> = []) {
        self.coach = coach
        self._selection = selection
        self.taken = taken
        self._temp = State(initialValue: selection.wrappedValue)
    }

    // Externally reserved seats (other passengers) + a stable deterministic set.
    private func isTaken(_ code: String) -> Bool {
        if taken.contains(code) { return true }
        var h = 5381
        for ch in "\(coach)-\(code)".unicodeScalars { h = (h &* 33 &+ Int(ch.value)) & 0xffff }
        return h % 100 < 38
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    legend
                    VStack(spacing: 10) {
                        Image(systemName: "tram.fill").foregroundStyle(Brand.textSoft)
                        Text("Voiture \(coach) · sens de la marche")
                            .font(.caption).foregroundStyle(Brand.textSoft)
                    }
                    grid
                }
                .padding(20)
            }
            .background(Brand.sand.ignoresSafeArea())
            .navigationTitle(L("Choisissez votre place"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Confirmer")) { selection = temp; dismiss() }
                        .fontWeight(.semibold)
                        .disabled(temp.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Annuler")) { dismiss() }
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 18) {
            legendItem(Brand.field, L("Libre"), border: true)
            legendItem(Color(hex: 0xCFD5E0), L("Occupé"))
            legendItem(Brand.orange, L("Choisi"))
        }
        .font(.caption2).foregroundStyle(Brand.textSoft)
    }
    private func legendItem(_ c: Color, _ t: String, border: Bool = false) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4).fill(c).frame(width: 16, height: 16)
                .overlay(border ? RoundedRectangle(cornerRadius: 4).strokeBorder(Color.black.opacity(0.15)) : nil)
            Text(t)
        }
    }

    private var grid: some View {
        Card {
            VStack(spacing: 10) {
                ForEach(1...rows, id: \.self) { row in
                    HStack(spacing: 8) {
                        Text("\(row)").font(.caption2).foregroundStyle(Brand.textSoft).frame(width: 18)
                        seat(row, "A"); seat(row, "B")
                        Spacer().frame(width: 18)
                        seat(row, "C"); seat(row, "D")
                    }
                }
            }
        }
    }

    private func seat(_ row: Int, _ letter: String) -> some View {
        let code = "\(row)\(letter)"
        let taken = isTaken(code)
        let selected = temp == code
        return Button {
            if !taken { temp = code }
        } label: {
            Text(letter)
                .font(.caption.weight(.bold))
                .foregroundStyle(selected ? .white : (taken ? Brand.textSoft.opacity(0.6) : Brand.label))
                .frame(width: 40, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(selected ? Brand.orange : (taken ? Color(hex: 0xCFD5E0) : Brand.field))
                )
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(selected ? Brand.orange3 : Color.black.opacity(0.12)))
        }
        .disabled(taken)
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(L("Place")) \(code)"))
        .accessibilityValue(Text(taken ? L("Occupé") : (selected ? L("Choisi") : L("Libre"))))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    SeatMapView(coach: 4, selection: .constant("22A"))
}
