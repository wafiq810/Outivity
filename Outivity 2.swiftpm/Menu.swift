//
//  SwiftUIView.swift
//  Outivity-pretest
//
//  Created by Wafiq on 12/27/25.
//

import SwiftUI
import SwiftData

struct Menu: View {
    let sections: [MenuSection]
    var actionHandler: (MenuRoute) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            
            List {
                Section{} footer: {
                    VStack(alignment: .center) {
                        
                        Image(systemName: "figure.outdoor.soccer")
                            .font(.system(size: 44))
                            .padding(18)
                            .background(Circle().fill(Color.accentColor))
                            .foregroundColor(.white)
                        
                        Text("Outivity")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.primary)
                            .multilineTextAlignment(.center)

                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom)
                }
                ForEach(sections) { section in
                    Section(section.title) {
                        ForEach(section.actions) { action in
                            switch action.presentation {
                            case .internalView(let destination):
                                NavigationLink {
                                    destination
                                } label: {
                                    Label(action.title, systemImage: action.systemImage)
                                }
                            case .routed(let route):
                                Button {
                                    actionHandler(route)
                                    dismiss()
                                } label: {
                                    Label(action.title, systemImage: action.systemImage)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Outivity Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}

struct MenuSection: Identifiable {
    let id: String
    let title: String
    let actions: [MenuAction]
}

struct MenuAction: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let presentation: MenuActionPresentation

    static func internalAction<V: View>(id: String, title: String, systemImage: String, destination: V) -> MenuAction {
        MenuAction(id: id, title: title, systemImage: systemImage, presentation: .internalView(destination: AnyView(destination)))
    }

    static func routedAction(id: String, title: String, systemImage: String, route: MenuRoute) -> MenuAction {
        MenuAction(id: id, title: title, systemImage: systemImage, presentation: .routed(route))
    }
}

enum MenuActionPresentation {
    case internalView(destination: AnyView)
    case routed(MenuRoute)
}

enum MenuRoute: Hashable {
    case activityHistory
    case gallery
    case scheduledActivities
    case scheduledActivitiesAdd
    case backpack
    case backpackAdd
    case progress
}
