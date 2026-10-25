//
//  SwiftUIView.swift
//  Outivity-pretest
//
//  Created by Wafiq on 12/25/25.
//

import SwiftUI
import SwiftData

final class RecommendationReloader: ObservableObject {
    @Published var trigger: Bool = false
    func reload() { trigger.toggle() }
}

extension Notification.Name {
    static let predictedActivityReload = Notification.Name("PredictedActivityView.reload")
}

struct PredictedActivityView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var recommendationReloader: RecommendationReloader
    @State private var recommendedActivities: [Activity] = []
    @State private var isShowingAlgorithmExplanation = false

    var onSelect: ((Activity) -> Void)? = nil

    @Query(sort: [SortDescriptor(\ActivityTracker.startedAt, order: .reverse)])
    private var sessions: [ActivityTracker]

    @Query private var userInfos: [UserInfo]

    private var activityPredictor: ActivityPredictorAlgorithm { ActivityPredictorAlgorithm(modelContext: modelContext) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recommended for you")
                    .font(.title3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(.secondary)
                
                Button {
                    isShowingAlgorithmExplanation = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 16) {
                if recommendedActivities.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 64))
                            .foregroundColor(.accentColor)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.accentColor.opacity(0.12))
                            )
                        Text("No recommendations yet")
                            .font(.headline)
                        Text("Tell us about your preferences or refresh to get suggestions.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .animation(.default, value: recommendedActivities)

                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(recommendedActivities, id: \.self) { activity in
                            Button {
                                onSelect?(activity)
                            } label: {
                                ActivityCard(activity: activity)
                                    .glassEffect(.regular.interactive())
                            }
                            .buttonStyle(.plain)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer(minLength: 24)
            }
            .padding(.top, 13)
        }
#if os(iOS)
        .refreshable { loadRecommendations() }
#endif
        .onAppear { loadRecommendations() }
        .onReceive(NotificationCenter.default.publisher(for: .predictedActivityReload)) { _ in loadRecommendations() }
        .onReceive(NotificationCenter.default.publisher(for: {
#if os(iOS)
            UIApplication.willEnterForegroundNotification
#else
            NSApplication.didBecomeActiveNotification
#endif
        }())) { _ in loadRecommendations() }
        .onChange(of: sessions) { _, _ in loadRecommendations() }
        .onChange(of: userInfos) { _, _ in loadRecommendations() }
        .onChange(of: recommendationReloader.trigger) { _, _ in loadRecommendations() }
        .sheet(isPresented: $isShowingAlgorithmExplanation) {
            ActivityPredictorExplanationSheet()
        }
    }

    private func loadRecommendations() {
        let new = activityPredictor.recommendActivities(count: 6)
        withAnimation { recommendedActivities = new }
    }
}

// MARK: - Algorithm Explanation Sheet

struct ActivityPredictorExplanationSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("How Activity Recommendations Work")
                            .font(.largeTitle.bold())
                        
                        Text("Outivity uses an intelligent algorithm to suggest activities based on your preferences, history, and current circumstances. Here's how it works:")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 20) {
                        ExplanationSection(
                            icon: "person.fill",
                            color: .blue,
                            title: "Personal Profile Analysis",
                            description: "The algorithm analyzes your activity preferences, intensity level (1-5), available time, and preferred environment to build a personalized profile."
                        )
                        
                        ExplanationSection(
                            icon: "clock.arrow.circlepath",
                            color: .orange,
                            title: "Activity History Learning",
                            description: "Your past activities are analyzed to identify patterns and themes you enjoy. Recent activities have more influence, with older activities gradually becoming less important."
                        )
                        
                        ExplanationSection(
                            icon: "brain.head.profile",
                            color: .purple,
                            title: "Smart Theme Matching",
                            description: "Activities are categorized by themes (Chill Nature, Team Sports, Winter, etc.). The algorithm matches activities with themes you've shown preference for."
                        )
                        
                        ExplanationSection(
                            icon: "gear",
                            color: .green,
                            title: "Equipment Consideration",
                            description: "Recommendations factor in the equipment you own. Activities requiring gear you don't have are less likely to be suggested."
                        )
                        
                        ExplanationSection(
                            icon: "timer",
                            color: .red,
                            title: "Time & Intensity Matching",
                            description: "The algorithm considers your available time and preferred intensity level, avoiding high intensity activities when you have less time."
                        )
                        
                        ExplanationSection(
                            icon: "sparkles",
                            color: .yellow,
                            title: "Novelty & Diversity",
                            description: "To keep things interesting, the algorithm looks at the variation of activity you want to do and suggest you activities that are alike or that are different."
                        )
                        
                        ExplanationSection(
                            icon: "figure.roll",
                            color: .teal,
                            title: "Accessibility Considerations",
                            description: "If you add accessibility considerations (like low vision or mobility needs), Outivity uses them to avoid suggestions that may be harder or unsafe. You can change these anytime in Settings."
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Dynamic Adaptation")
                            .font(.title2.bold())
                        
                        Text("The recommendation system continuously learns from your choices and adapts to changes in your preferences over time. It also applies smart exploration to occasionally suggest activities outside your usual preferences to help you discover new interests.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top)
                }
                .padding()
            }
            .navigationTitle("How it works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button{
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}

struct ExplanationSection: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
