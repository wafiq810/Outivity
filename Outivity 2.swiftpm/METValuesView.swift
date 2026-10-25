//
//  METValuesView.swift
//  Outivity
//
//  Created by Assistant on 2/25/26.
//

import SwiftUI

struct METValuesView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let governmentURL = "https://epi.grants.cancer.gov/physical/met/atus-met.php?major%5B%5D=01&major%5B%5D=02&major%5B%5D=03&major%5B%5D=04&major%5B%5D=06&major%5B%5D=07&major%5B%5D=08&major%5B%5D=09&major%5B%5D=10&major%5B%5D=11&major%5B%5D=12&major%5B%5D=13&major%5B%5D=14&major%5B%5D=15&major%5B%5D=16&keywords=&metval_min=&metval_max="
    
    private var activitiesByTheme: [(String, [Activity])] {
        let themes: [(String, [Activity])] = [
            ("Hiking & Walking", [.hiking, .trailWalking, .forestExploring, .snowHiking]),
            ("Water Sports", [.swimming, .kayaking, .canoeing, .surfing, .paddleboarding, .snorkeling, .scubaDiving, .riverCanoe]),
            ("Winter Sports", [.skiing, .snowboarding, .iceSkating, .snowPlay]),
            ("Ball Sports", [.soccer, .basketball, .tennis, .volleyball, .cricket, .baseball, .outdoorBadminton]),
            ("Adventure Sports", [.biking, .running, .climbing, .rockHopping]),
            ("Relaxation & Nature", [.fishing, .outdoorYoga, .outdoorMeditation, .hammockResting]),
            ("Other Activities", [.camping, .beach, .wildlifeSpotting, .birdWatching, .stargazing, .photographyWalk, .picnic, .bonfireNight, .other])
        ]
        
        return themes.filter { !$0.1.isEmpty }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Metabolic Equivalent of Task (MET) Values")
                            .font(.largeTitle.bold())
                        
                        Text("MET values measure the energy cost of activities. One MET is the energy you use at rest. Higher MET values indicate more intense activities that burn more calories.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        
                        Link(destination: URL(string: governmentURL)!) {
                            HStack {
                                Image(systemName: "link")
                                Text("View US Government Source Data")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                            .padding()
                            .background(.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    
                    // MET Values by Theme
                    ForEach(activitiesByTheme, id: \.0) { theme, activities in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(theme)
                                .font(.title2.bold())
                                .padding(.horizontal)
                            
                            LazyVStack(spacing: 1) {
                                ForEach(activities.filter { $0.summaryMET != nil }, id: \.self) { activity in
                                    METValueRow(activity: activity)
                                }
                                
                                // Show activities without MET values at the end
                                ForEach(activities.filter { $0.summaryMET == nil }, id: \.self) { activity in
                                    METValueRow(activity: activity)
                                }
                            }
                            .background(.regularMaterial)
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                    }
                    
                    // Footer with additional information
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About MET Values")
                            .font(.title3.bold())
                        
                        VStack(alignment: .leading, spacing: 8) {
                            METExplanationRow(title: "1 MET", description: "Resting metabolic rate")
                            METExplanationRow(title: "3-6 METs", description: "Light to moderate activities")
                            METExplanationRow(title: "6+ METs", description: "Vigorous activities")
                        }
                        .padding()
                        .background(.gray.opacity(0.1))
                        .cornerRadius(12)
                        
                        Text("Source: US National Cancer Institute Division of Cancer Control & Population Sciences")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct METValueRow: View {
    let activity: Activity
    
    var body: some View {
        HStack {
            // Activity icon and name
            HStack(spacing: 12) {
                Image(systemName: activity.symbolName)
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.displayName)
                        .font(.body.weight(.medium))
                    
                    Text(activity.difficultyLevel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // MET value
            Group {
                if let met = activity.summaryMET {
                    Text(String(format: "%.1f", met))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                } else {
                    Text("N/A")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear)
    }
}

struct METExplanationRow: View {
    let title: String
    let description: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body.weight(.semibold))
                .frame(width: 80, alignment: .leading)
            
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
    }
}

#Preview {
    METValuesView()
}
