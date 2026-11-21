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

    var body: some View {
        TextPromptComposer(
            title: "New Task",
            placeholder: "Task title",
            confirmTitle: "Add",
            isPresented: $isPresented,
            text: $title,
            onConfirm: {
                onAdd()
                title = ""
            }
        )
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
