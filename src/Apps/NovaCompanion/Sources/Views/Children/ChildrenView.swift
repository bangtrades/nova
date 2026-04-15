import SwiftUI
import NovaCore

/// View for managing child profiles.
public struct ChildrenView: View {
    @StateObject private var viewModel = ChildProfileViewModel()
    @State private var showingAddChild = false
    @State private var selectedChild: ChildProfile?
    @State private var isEditingChild = false

    public var body: some View {
        NavigationStack {
            ZStack {
                CompanionPalette.companionBackground
                    .ignoresSafeArea()

                if viewModel.childProfiles.isEmpty {
                    EmptyStateView(
                        icon: "person.crop.circle.badge.plus",
                        title: "No Children Yet",
                        message: "Add your child's profile to start tracking their AI learning journey",
                        actionTitle: "Add Child",
                        action: { showingAddChild = true }
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Your Children")
                                .font(CompanionPalette.headingFont())
                                .fontWeight(.semibold)
                                .padding(.horizontal, 16)

                            VStack(spacing: 12) {
                                ForEach(viewModel.childProfiles) { child in
                                    ChildProfileCard(
                                        child: child,
                                        onEdit: {
                                            selectedChild = child
                                            isEditingChild = true
                                        },
                                        onDelete: {
                                            viewModel.deleteChild(child)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)

                            Spacer()
                                .frame(height: 20)
                        }
                        .padding(.vertical, 16)
                    }
                }

                // Floating Action Button
                VStack {
                    Spacer()

                    HStack {
                        Spacer()

                        Button(action: { showingAddChild = true }) {
                            Image(systemName: "plus")
                                .font(.title3.weight(.semibold))
                                .frame(width: 56, height: 56)
                                .background(CompanionPalette.novaBlue)
                                .foregroundStyle(.white)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding(24)
                    }
                }
            }
            .navigationTitle("Children")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddChild) {
                AddChildView { child in
                    viewModel.addChild(child)
                }
            }
        }
    }
}

#Preview {
    ChildrenView()
}
