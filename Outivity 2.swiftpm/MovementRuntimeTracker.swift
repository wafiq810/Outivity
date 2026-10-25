//
//  MovementRuntimeTracker.swift
//  Outivity
//
//  Created by Wafiq on 1/3/26.
//

import Foundation
import CoreLocation
import CoreMotion

@MainActor
final class MovementRuntimeTracker: NSObject, ObservableObject, @MainActor CLLocationManagerDelegate {
    @Published var isTracking: Bool = false
    @Published var totalDistanceMeters: Double = 0
    @Published var totalDistanceFeet: Double = 0
    @Published var currentSpeedMps: Double? = nil
    @Published var lastAccuracyMeters: Double? = nil
    @Published var totalSeconds: Int = 0
    @Published var movingSeconds: Int = 0
    @Published var activityG: Double = 0
    @Published var peakSteps: Int = 0
    @Published var isMovingByAccel: Bool = false
    
    @Published var trackSteps: Bool = false


    /// Called whenever we accept a GPS segment.
    /// distanceDelta is meters since last accepted point.
    /// speed is instantaneous m/s (if available).
    var onSample: ((Double, Double?) -> Void)?

    private let locationManager = CLLocationManager()
    private let motionManager = CMMotionManager()

    private var lastGoodLocation: CLLocation? = nil
    private var timer: Timer? = nil

    private let minHorizontalAccuracy: CLLocationAccuracy = 25
    private let maxHorizontalAccuracy: CLLocationAccuracy = 80
    private let maxReasonableSpeedMps: Double = 12.0
    private let minMovingSpeedMps: Double = 0.7

    private var accelHP: Double = 0
    private var accelSmoothed: Double = 0
    private var lastWasAbovePeak: Bool = false
    private var lastStepTime: TimeInterval = 0
    private let minStepInterval: TimeInterval = 0.45

    func start() {
        guard !isTracking else { return }
        isTracking = true

        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 3
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()

        startAccelerometer()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.totalSeconds += 1
                if (self.currentSpeedMps ?? 0) > self.minMovingSpeedMps || self.isMovingByAccel {
                    self.movingSeconds += 1
                }
            }
        }
    }

    func stop() {
        guard isTracking else { return }
        isTracking = false
        locationManager.stopUpdatingLocation()
        stopAccelerometer()
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        totalDistanceMeters = 0
        currentSpeedMps = nil
        lastAccuracyMeters = nil
        lastGoodLocation = nil
        totalSeconds = 0
        movingSeconds = 0
        activityG = 0
        peakSteps = 0
        isMovingByAccel = false
        accelHP = 0
        accelSmoothed = 0
        lastWasAbovePeak = false
        lastStepTime = 0
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isTracking else { return }

        for loc in locations {
            if loc.horizontalAccuracy < 0 { continue }
            lastAccuracyMeters = loc.horizontalAccuracy
            if loc.horizontalAccuracy > maxHorizontalAccuracy { continue }

            let accuracyOK = loc.horizontalAccuracy <= minHorizontalAccuracy
            let speed = loc.speed >= 0 ? loc.speed : nil
            currentSpeedMps = speed
            if let spd = speed, spd > maxReasonableSpeedMps { continue }

            if let last = lastGoodLocation {
                let dt = loc.timestamp.timeIntervalSince(last.timestamp)
                if dt <= 0 { continue }

                let segment = loc.distance(from: last)
                let impliedSpeed = segment / dt
                if impliedSpeed > maxReasonableSpeedMps { continue }

                if !accuracyOK {
                    if let spd = speed, spd < minMovingSpeedMps {
                        lastGoodLocation = loc
                        continue
                    }
                    if segment < 5 {
                        lastGoodLocation = loc
                        continue
                    }
                }

                totalDistanceMeters += segment
                totalDistanceFeet = totalDistanceMeters * 3.28084
                onSample?(segment, speed)
            }

            lastGoodLocation = loc
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error.localizedDescription)
    }

    private func startAccelerometer() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 1.0 / 30.0

        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let a = data?.acceleration, let data else { return }

            // Always compute activityG + isMovingByAccel (optional, can keep)
            let mag = sqrt(a.x*a.x + a.y*a.y + a.z*a.z)
            let alpha = 0.02
            self.accelHP = self.accelHP + alpha * (mag - self.accelHP)
            let dyn = abs(mag - self.accelHP)

            self.accelSmoothed = (0.9 * self.accelSmoothed) + (0.1 * dyn)
            self.activityG = self.accelSmoothed
            self.isMovingByAccel = self.accelSmoothed > 0.025

            // Only count steps when the activity needs it
            guard self.trackSteps else { return }

            let now = data.timestamp
            let peakThreshold = 0.075
            let isAbove = dyn > peakThreshold
            if isAbove && !self.lastWasAbovePeak {
                if now - self.lastStepTime >= self.minStepInterval {
                    self.peakSteps += 1
                    self.lastStepTime = now
                }
            }
            self.lastWasAbovePeak = isAbove
        }
    }


    private func stopAccelerometer() {
        motionManager.stopAccelerometerUpdates()
    }
}
