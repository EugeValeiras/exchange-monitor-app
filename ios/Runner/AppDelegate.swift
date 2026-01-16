import Flutter
import UIKit
import BackgroundTasks
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {

    private let backgroundTaskId = "com.eugeniovaleiras.exchangeMonitor.widgetRefresh"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Register background task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskId, using: nil) { task in
            self.handleBackgroundTask(task: task as! BGAppRefreshTask)
        }

        // Set minimum background fetch interval
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // Handle legacy background fetch
    override func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Refresh widget timeline
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadTimelines(ofKind: "ExchangeWidget")
        }
        completionHandler(.newData)
    }

    // Schedule next background task
    private func scheduleBackgroundTask() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background task: \(error)")
        }
    }

    // Handle background task
    private func handleBackgroundTask(task: BGAppRefreshTask) {
        // Schedule next task
        scheduleBackgroundTask()

        // Refresh widget
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadTimelines(ofKind: "ExchangeWidget")
        }

        task.setTaskCompleted(success: true)
    }

    // Schedule background task when app goes to background
    override func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleBackgroundTask()
    }
}
