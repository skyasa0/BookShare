//
//  BSTabBar.swift
//  BookShare
//
//  Four fixed destinations (IA, Deliverable 07). Active tab: terracotta icon +
//  bold label. No badges on tabs at MVP — attention lives inside Home.
//

import SwiftUI

enum AppTab: Int, CaseIterable, Identifiable {
    case discover, home, shelf, profile
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .discover: return "Discover"
        case .home:     return "Home"
        case .shelf:    return "Shelf"
        case .profile:  return "Profile"
        }
    }
    var icon: String {
        switch self {
        case .discover: return "magnifyingglass"
        case .home:     return "house"
        case .shelf:    return "books.vertical"
        case .profile:  return "person.crop.circle"
        }
    }
}

struct BSTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let on = tab == selection
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 19, weight: on ? .semibold : .regular))
                        Text(tab.title)
                            .font(BSFont.sans(11.5, on ? .bold : .medium))
                    }
                    .foregroundStyle(on ? BSColor.rust : BSColor.muted)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, BSSpace.s)
        .background(
            BSColor.card
                .overlay(Rectangle().fill(BSColor.line).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

#Preview {
    struct Demo: View {
        @State var sel: AppTab = .discover
        var body: some View {
            VStack {
                Spacer()
                BSTabBar(selection: $sel)
            }
            .background(BSColor.paper)
        }
    }
    return Demo()
}
