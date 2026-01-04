//
//  UpdateView.swift
//  Droppy
//
//  Created by Jordy Spruit on 04/01/2026.
//

import SwiftUI

struct UpdateView: View {
    @ObservedObject var checker = UpdateChecker.shared
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .liquidGlass(radius: 14, depth: 1.2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Update Available")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    
                    if let newVersion = checker.latestVersion {
                        Text("Version \(newVersion) is available. You are on \(checker.currentVersion).")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 8)
            
            // Release Notes
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let notes = checker.releaseNotes {
                        // Use default markdown options to support bullet points and headers
                        if let attributed = try? AttributedString(markdown: notes) {
                            Text(attributed)
                                .font(.system(size: 14))
                                .lineSpacing(4)
                                .foregroundStyle(.white.opacity(0.9))
                                .textSelection(.enabled)
                        } else {
                             Text(notes)
                                .font(.system(size: 14))
                                .lineSpacing(4)
                                .foregroundStyle(.white.opacity(0.9))
                                .textSelection(.enabled)
                        }
                    } else {
                        Text("No release notes available.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.black.opacity(0.2))
            )
            .liquidGlass(radius: 16, depth: 0.5, isConcave: true) // Concave "well" effect for content
            
            // Actions
            HStack(spacing: 16) {
                Button("Later") {
                    UpdateWindowController.shared.closeWindow()
                }
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .onHover { hover in
                    if hover { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                
                Spacer()
                
                LiquidButton(
                    title: "Update & Restart",
                    icon: "arrow.triangle.2.circlepath",
                    action: {
                        if let url = checker.downloadURL {
                            AutoUpdater.shared.installUpdate(from: url)
                            UpdateWindowController.shared.closeWindow()
                        }
                    }
                )
            }
        }
        .padding(24)
        .frame(width: 500, height: 450)
        .background {
            ZStack {
                Color.black // Base
                
                // Subtle ambient gradient
                RadialGradient(
                    colors: [.blue.opacity(0.2), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 400
                )
                
                // Glass texture
                Rectangle()
                    .fill(.ultraThinMaterial)
            }
            .ignoresSafeArea()
        }
    }
}
