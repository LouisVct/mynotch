//
//  ConversionOfferView.swift
//  boringNotch
//
//  Bar shown over the shelf after a drop to pick a conversion format.
//

import SwiftUI

struct ConversionOfferView: View {
    @ObservedObject var tvm: ShelfStateViewModel
    let offer: ConversionOffer

    var body: some View {
        HStack(spacing: 8) {
            if tvm.isConverting {
                ProgressView()
                    .controlSize(.small)
                Text("Converting…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Convert to")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(offer.targets) { target in
                            Button(target.title) { tvm.convert(offer, to: target) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                }
                .scrollIndicators(.never)
                Button {
                    tvm.dismissConversionOffer()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(0.85), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.15)))
        .padding(8)
    }
}
