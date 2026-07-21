//
//  BSField.swift
//  BookShare
//
//  Filled style on the field tint; label set above in tracked uppercase.
//  Placeholder shows format, never instructions. Focus ring: 2px terracotta.
//

import SwiftUI

struct BSField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: BSSpace.s) {
            Text(label).bsFieldLabel()

            TextField("", text: $text, prompt:
                Text(placeholder).foregroundColor(BSColor.placeholder))
                .font(BSFont.sans(15))
                .foregroundStyle(BSColor.ink)
                .keyboardType(keyboard)
                .focused($focused)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(BSColor.field)
                .clipShape(RoundedRectangle(cornerRadius: BSRadius.m))
                .overlay(
                    RoundedRectangle(cornerRadius: BSRadius.m)
                        .strokeBorder(focused ? BSColor.rust : BSColor.fieldLine,
                                      lineWidth: focused ? 2 : 1)
                )
                .animation(.easeOut(duration: 0.15), value: focused)
        }
    }
}

#Preview {
    struct Demo: View {
        @State var name = "Jane Smith"
        @State var phone = ""
        var body: some View {
            VStack(spacing: 20) {
                BSField(label: "Name", placeholder: "Full name", text: $name)
                BSField(label: "Phone", placeholder: "+1 (___) ___-____",
                        text: $phone, keyboard: .phonePad)
            }
            .padding(BSSpace.xl)
            .frame(maxHeight: .infinity)
            .background(BSColor.paper)
        }
    }
    return Demo()
}
