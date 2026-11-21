//
//  QuickTaskComposer.swift
//  Cadence
//

import SwiftUI

/// Lightweight in-app title prompt. Avoids UIKit `.alert` presentation, which
/// hits invalid UIScreen coordinate conversions and feels delayed on + taps.
struct QuickTaskComposer: View {
    @Binding var isPresented: Bool
    @Binding var title: String
    var onAdd: () -> Void

    @FocusState private var titleFocused: Bool

    private var canAdd: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)

            VStack(alignment: .leading, spacing: 16) {
                Text("New Task")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)

                TextField("", text: $title, prompt: Text("Task title").foregroundStyle(Theme.textTertiary))
                    .focused($titleFocused)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .submitLabel(.done)
                    .onSubmit {
                        if canAdd { submit() }
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

                    Button("Add", action: submit)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(canAdd ? Theme.onAccent : Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background {
                            if canAdd {
                                Theme.accentGradient
                            } else {
                                Theme.background
                            }
                        }
                        .clipShape(.rect(cornerRadius: 12))
                        .disabled(!canAdd)
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
        .transition(.opacity)
        .onAppear {
            titleFocused = true
        }
    }

    private func submit() {
        guard canAdd else { return }
        onAdd()
        dismiss()
    }

    private func dismiss() {
        titleFocused = false
        title = ""
        isPresented = false
    }
}

extension View {
    func quickTaskComposer(
        isPresented: Binding<Bool>,
        title: Binding<String>,
        onAdd: @escaping () -> Void
    ) -> some View {
        overlay {
            if isPresented.wrappedValue {
                QuickTaskComposer(isPresented: isPresented, title: title, onAdd: onAdd)
            }
        }
        .animation(nil, value: isPresented.wrappedValue)
    }
}
