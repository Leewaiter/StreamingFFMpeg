import UIKit
import KSPlayer

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        print("🚀 AppDelegate - didFinishLaunchingWithOptions called")

        KSOptions.firstPlayerType  = KSMEPlayer.self
        KSOptions.secondPlayerType = KSMEPlayer.self

        window = UIWindow(frame: UIScreen.main.bounds)
        print("   Window created: \(UIScreen.main.bounds)")

        let playerVC = PlayerViewController()
        print("   PlayerViewController created")

        let navVC = UINavigationController(rootViewController: playerVC)
        navVC.navigationBar.isHidden = true
        print("   NavigationController created")

        window?.rootViewController = navVC
        window?.makeKeyAndVisible()
        print("✅ Window made key and visible")
        print("   RootViewController: \(String(describing: window?.rootViewController))")

        return true
    }
}

