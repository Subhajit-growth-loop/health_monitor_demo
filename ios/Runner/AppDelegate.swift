import Flutter
import HealthKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    enableHealthKitBackgroundDelivery()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Ask HealthKit to wake the app (via background delivery) whenever a tracked
  // data type receives new samples. The actual fetch → local → backend sync,
  // threshold checks and notifications run inside the WorkManager task callback
  // in Dart. Covers the glucose-first metabolic headline set plus the OSA/sleep
  // context types. Unauthorized types fail the completion silently — harmless.
  private func enableHealthKitBackgroundDelivery() {
    guard HKHealthStore.isHealthDataAvailable() else { return }
    let store = HKHealthStore()

    var types: [HKObjectType] = [
      HKObjectType.quantityType(forIdentifier: .bloodGlucose)!,
      HKObjectType.quantityType(forIdentifier: .heartRate)!,
      HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
      HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
      HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
      HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
      HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
      HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
      HKObjectType.quantityType(forIdentifier: .bodyTemperature)!,
      HKObjectType.quantityType(forIdentifier: .stepCount)!,
      HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
      HKObjectType.quantityType(forIdentifier: .bodyMass)!,
      HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
    ]
    if #available(iOS 15.0, *) {
      types.append(HKObjectType.categoryType(forIdentifier: .menstrualFlow)!)
    }

    for type in types {
      store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
    }
  }
}