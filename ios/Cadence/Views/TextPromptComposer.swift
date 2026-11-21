//
//  TextPromptComposer.swift
//  Cadence
//

import SwiftUI

/// In-app text prompt used instead of UIKit alerts (which hitch and log
/// invalid UIScreen coordinate conversions).
struct TextPromptComposer: View {
    let title: String
    let placeholder: String
    let confirmTitle: String
    @Binding var isPresented: Bool
    @Binding var text: String
    var onConfirm: () -> Void

    @FocusState private var fieldFocused: Bool

    private var canConfirm: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)

            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)

                TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Theme.textTertiary))
                    .focused($fieldFocused)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .submitLabel(.done)
                    .onSubmit {
                        if canConfirm { confirm() }
                    }
                    .padding(16)
                    .background(Theme.background, in: .rect(cornerRadius: 14))

                HStack(spacing: 12) {
                    Button("Cancel", action: dismiss)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.background, in: .rect(cornerRadius: 12))

                    Button(confirmTitle, action: confirm)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(canConfirm ? Theme.onAccent : Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background {
                            if canConfirm {
                                Theme.accentGradient
                            } else {
                                Theme.background
                            }
                        }
                        .clipShape(.rect(cornerRadius: 12))
                        .disabled(!canConfirm)
                }
            }
            .padding(18)
            .background(Theme.surface, in: .rect(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Theme.strokeSoft, lineWidth: 1)
            )
            .padding(.horizontal, 28)
            .offset(y: -40)
        }
        .onAppear { fieldFocused = true }
    }

    private func confirm() {
        guard canConfirm else { return }
        onConfirm()
        dismiss()
    }

    private func dismiss() {
        fieldFocused = false
        isPresented = false
    }
}
