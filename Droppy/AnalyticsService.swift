//
//  AnalyticsService.swift
//  Droppy
//
//  Created by Jordy Spruit on 04/01/2026.
//

import Foundation
import SwiftUI

/// Service for tracking anonymous app usage statistics (installs and daily active users)
/// Privacy-focused: No personal data, just counts.
final class AnalyticsService: Sendable {
    static let shared = AnalyticsService()
    
    // TODO: Replace with actual values from Supabase project
    private let supabaseURL = URL(string: "https://anannmonpspjsnfgdglb.supabase.co/rest/v1/analytics_events")!
    private let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFuYW5ubW9ucHNwanNuZmdkZ2xiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1NDgxODQsImV4cCI6MjA4MzEyNDE4NH0.5BvuW5cS0kJCuA2Nm5HCVDLNWNzn6EA_8JVVrW6pfnY"
    
    // UserDefaults keys
    private let kAnalyticsID = "droppy_analytics_id"
    private let kHasTrackedInstall = "droppy_has_tracked_install"
    
    private init() {}
    
    /// Called on app launch to track stats
    func logAppLaunch() {
        Task {
            // 1. Ensure we have an anonymous ID
            let analyticsID = getOrGenerateAnalyticsID()
            
            // 2. Track install if new
            if !UserDefaults.standard.bool(forKey: kHasTrackedInstall) {
                await trackEvent(type: "install", id: analyticsID)
                UserDefaults.standard.set(true, forKey: kHasTrackedInstall)
            }
            
            // 3. Track launch (active user)
            await trackEvent(type: "launch", id: analyticsID)
        }
    }
    
    private func getOrGenerateAnalyticsID() -> String {
        if let existing = UserDefaults.standard.string(forKey: kAnalyticsID) {
            return existing
        }
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: kAnalyticsID)
        return newID
    }
    
    private func trackEvent(type: String, id: String) async {
        // Construct payload
        let payload: [String: Any] = [
            "event_type": type,
            "anonymous_id": id,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            "os_version": ProcessInfo.processInfo.operatingSystemVersionString
        ]
        
        do {
            var request = URLRequest(url: supabaseURL)
            request.httpMethod = "POST"
            request.addValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
            request.addValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            // Prefer minimal representation to save bandwidth
            request.addValue("return=minimal", forHTTPHeaderField: "Prefer")
            
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                print("Analytics failed: \(httpResponse.statusCode)")
            }
        } catch {
            print("Analytics error: \(error)")
        }
    }
    
    /// Fetches the total number of unique installs (downloads)
    func fetchDownloadCount() async throws -> Int {
        // RPC endpoint: /rest/v1/rpc/get_download_count
        let rpcURL = URL(string: "https://anannmonpspjsnfgdglb.supabase.co/rest/v1/rpc/get_download_count")!
        
        var request = URLRequest(url: rpcURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.addValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Supabase RPCs need a body, even if empty
        request.httpBody = try JSONSerialization.data(withJSONObject: [:])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // Response is just the integer number (e.g. 42)
        if let str = String(data: data, encoding: .utf8), let count = Int(str.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return count
        }
        
        return 0
    }
}
