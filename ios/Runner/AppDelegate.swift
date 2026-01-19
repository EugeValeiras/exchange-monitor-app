import Flutter
import UIKit
import BackgroundTasks
import WidgetKit
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {

    private let backgroundTaskId = "com.eugeniovaleiras.exchangeMonitor.widgetRefresh"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()

        GeneratedPluginRegistrant.register(with: self)

        // Register for remote notifications
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()

        // Register background task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskId, using: nil) { task in
            self.handleBackgroundTask(task: task as! BGAppRefreshTask)
        }

        // Set minimum background fetch interval
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // Handle APNs token registration
    override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    // Handle silent push notifications (content-available)
    override func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("[AppDelegate] Received remote notification: \(userInfo)")

        // Check if this is a widget refresh notification with data
        if #available(iOS 14.0, *) {
            let defaults = UserDefaults(suiteName: "group.com.eugeniovaleiras.exchangeMonitor")

            // Check for widgetData in the notification payload
            if let widgetDataString = userInfo["widgetData"] as? String {
                print("[AppDelegate] Found widgetData in push notification, saving to UserDefaults...")

                // Save the widget data directly to App Group (same key Flutter uses)
                defaults?.set(widgetDataString, forKey: "widgetData")
                defaults?.set(Date().timeIntervalSince1970, forKey: "pushDataReceivedAt")
                defaults?.synchronize()

                print("[AppDelegate] Widget data saved from push notification")
            }

            // Save a refresh trigger timestamp
            defaults?.set(Date().timeIntervalSince1970, forKey: "refreshTrigger")
            defaults?.synchronize()

            // Request widget reload
            print("[AppDelegate] Reloading widget timelines...")
            WidgetCenter.shared.reloadAllTimelines()
            WidgetCenter.shared.reloadTimelines(ofKind: "ExchangeWidget")

            print("[AppDelegate] Widget reload requested at \(Date())")
        }

        // Let Flutter handle the notification and call completion handler
        super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
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
