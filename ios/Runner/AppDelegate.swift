import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Replace YOUR_GOOGLE_MAPS_API_KEY with your actual key from
    // https://console.cloud.google.com/apis/credentials
    GMSServices.provideAPIKey("AIzaSyB3-N5KwVMHmZ41RTmmppaVm80uXeR9yxo")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
