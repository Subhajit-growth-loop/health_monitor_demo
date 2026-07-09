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

  // Ask HealthKit to wake the app (via background fetch) whenever any of the
  // five tracked data types receive new samples. The actual threshold check and
  // notification fire happen inside the WorkManager task callback in Dart.
  private func enableHealthKitBackgroundDelivery() {
    guard HKHealthStore.isHealthDataAvailable() else { return }
    let store = HKHealthStore()
    let types: [HKObjectType] = [
      HKObjectType.quantityType(forIdentifier: .stepCount)!,
      HKObjectType.quantityType(forIdentifier: .heartRate)!,
      HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
      HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
      HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
    ]
    for type in types {
      store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
    }
  }
}