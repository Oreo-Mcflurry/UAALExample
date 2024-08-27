//
//  UnityEmbeddedSwift.swift
//  native_app
//

import Foundation
import UnityFramework
import SwiftUI

class UnityEmbeddedSwift: UIResponder, UIApplicationDelegate, UnityFrameworkListener {

    private struct UnityMessage {
        let objectName : String?
        let methodName : String?
        let messageBody : String?
    }

    private static var instance : UnityEmbeddedSwift!
    var ufw : UnityFramework!
    private static var hostMainWindow : UIWindow! // Window to return to when exiting Unity window
    private static var launchOpts : [UIApplication.LaunchOptionsKey: Any]?
    private var maskView: UIView?
    private static var cachedMessages = [UnityMessage]()
    static var toolbarHeight: CGFloat = .zero

    // MARK: - Static functions (that can be called from other scripts)

    static func getUnityRootViewController() -> UIViewController? {
        return instance.ufw.appController()?.rootViewController
    }
    
    static func addSubView(_ view: UIView) {
        guard let rootViewController = instance.ufw.appController()?.rootViewController else {
            return
        }
        
        rootViewController.view.addSubview(view)
        
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            // 중앙 정렬
            view.centerXAnchor.constraint(equalTo: rootViewController.view.centerXAnchor),
            view.centerYAnchor.constraint(equalTo: rootViewController.view.centerYAnchor),
            view.widthAnchor.constraint(equalToConstant: 100),
            view.heightAnchor.constraint(equalToConstant: 100)
        ])
    }
    
    static func resizeViewControllerView(topConstant: CGFloat, leadingConstant: CGFloat, trailingConstant: CGFloat, height: CGFloat, withAnimation: Bool = false) {
        guard let appController = instance?.ufw?.appController(),
                  let rootView = appController.rootViewController,
                  let window = appController.window else { return }
        
        let windowWidth = UIScreen.main.bounds.width - leadingConstant - trailingConstant
        
        let safeAreaInset = (UIApplication.shared.connectedScenes.first
            .flatMap { ($0 as? UIWindowScene)?.windows.first }?
            .flatMap { $0.safeAreaInsets.top } ?? 0) ?? 0
        
        let navHeight: CGFloat = 38.8
        let adjustedTopConstant = topConstant + safeAreaInset + navHeight
        
        let windowFrame = CGRect(
            x: leadingConstant,
            y: adjustedTopConstant,
            width: windowWidth,
            height: height
        )
        
        UIView.animate(withDuration: withAnimation ? 0.3 : 0) {
            window.frame = windowFrame
            
            if let maskView = instance.maskView {
                if 0 >= topConstant {
                    maskView.frame = CGRect(x: 0, y: -topConstant, width: windowWidth, height: height)
                } else {
                    maskView.frame = rootView.view.frame
                }
            } else {
                let maskView = UIView()
                maskView.backgroundColor = .red
                maskView.frame = rootView.view.frame
                instance.maskView = maskView
                
                rootView.view.mask = instance.maskView
            }
        }
    }

    static func getUnityView() -> UIView! {
        return instance.ufw.appController()?.rootViewController?.view
    }

    static func setHostMainWindow(_ hostMainWindow : UIWindow?) {
        UnityEmbeddedSwift.hostMainWindow = hostMainWindow
        let value = UIInterfaceOrientation.landscapeLeft.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
    }

    static func setLaunchinOptions(_ launchingOptions :  [UIApplication.LaunchOptionsKey: Any]?) {
        UnityEmbeddedSwift.launchOpts = launchingOptions
    }

    static func showUnity() {
        if(UnityEmbeddedSwift.instance == nil || UnityEmbeddedSwift.instance.unityIsInitialized() == false) {
            UnityEmbeddedSwift().initUnityWindow()
        }
        else {
            UnityEmbeddedSwift.instance.showUnityWindow()
        }
    }

    static func hideUnity() {
        UnityEmbeddedSwift.instance?.hideUnityWindow()
    }

    static func pauseUnity() {
        UnityEmbeddedSwift.instance?.pauseUnityWindow()
    }

    static func unpauseUnity() {
        UnityEmbeddedSwift.instance?.unpauseUnityWindow()
    }

    static func unloadUnity() {
        UnityEmbeddedSwift.instance?.unloadUnityWindow()
    }

    static func sendUnityMessage(_ objectName : String, methodName : String, message : String) {
        let msg : UnityMessage = UnityMessage(objectName: objectName, methodName: methodName, messageBody: message)

        // Send the message right away if Unity is initialized, else cache it
        if(UnityEmbeddedSwift.instance != nil && UnityEmbeddedSwift.instance.unityIsInitialized()) {
            UnityEmbeddedSwift.instance.ufw.sendMessageToGO(withName: msg.objectName, functionName: msg.methodName, message: msg.messageBody)
        }
        else {
            UnityEmbeddedSwift.cachedMessages.append(msg)
        }
    }

    // MARK - Callback from UnityFrameworkListener

    func unityDidUnload(_ notification: Notification!) {
        ufw.unregisterFrameworkListener(self)
        ufw = nil
        UnityEmbeddedSwift.hostMainWindow?.makeKeyAndVisible()
    }

    // MARK: - Private functions (called within the class)

    private func unityIsInitialized() -> Bool {
        return ufw != nil && (ufw.appController() != nil)
    }

    private func initUnityWindow() {
        if unityIsInitialized() {
            showUnityWindow()
            return
        }

        ufw = UnityFrameworkLoad()!
        ufw.setDataBundleId("com.unity3d.framework")
        ufw.register(self)
//        NSClassFromString("FrameworkLibAPI")?.registerAPIforNativeCalls(self)

        ufw.runEmbedded(withArgc: CommandLine.argc, argv: CommandLine.unsafeArgv, appLaunchOpts: UnityEmbeddedSwift.launchOpts)
        sendUnityMessageToGameObject()

        ufw.appController().window = UnityEmbeddedSwift.hostMainWindow
        UnityEmbeddedSwift.instance = self
    }

    private func showUnityWindow() {
        if unityIsInitialized() {
            ufw.showUnityWindow()
            sendUnityMessageToGameObject()
        }
    }

    private func hideUnityWindow() {
        if(UnityEmbeddedSwift.hostMainWindow == nil) {
            print("WARNING: hostMainWindow is nil! Cannot switch from Unity window to previous window")
        }
        else {
            UnityEmbeddedSwift.hostMainWindow?.makeKeyAndVisible()
        }
    }

    private func pauseUnityWindow() {
        ufw.pause(true)
    }

    private func unpauseUnityWindow() {
        ufw.pause(false)
    }

    private func unloadUnityWindow() {
        if unityIsInitialized() {
            UnityEmbeddedSwift.cachedMessages.removeAll()
            ufw.unloadApplication()
        }
    }

    private func sendUnityMessageToGameObject() {
        if (UnityEmbeddedSwift.cachedMessages.count >= 0 && unityIsInitialized())
        {
            for msg in UnityEmbeddedSwift.cachedMessages {
                ufw.sendMessageToGO(withName: msg.objectName, functionName: msg.methodName, message: msg.messageBody)
            }

            UnityEmbeddedSwift.cachedMessages.removeAll()
        }
    }

    private func UnityFrameworkLoad() -> UnityFramework? {
        let bundlePath: String = Bundle.main.bundlePath + "/Frameworks/UnityFramework.framework"

        let bundle = Bundle(path: bundlePath )
        if bundle?.isLoaded == false {
            bundle?.load()
        }

        let ufw = bundle?.principalClass?.getInstance()
        if ufw?.appController() == nil {
            // unity is not initialized
            //            ufw?.executeHeader = &mh_execute_header

            let machineHeader = UnsafeMutablePointer<MachHeader>.allocate(capacity: 1)
            machineHeader.pointee = _mh_execute_header

            ufw!.setExecuteHeader(machineHeader)
            
//            ufw?.appController()?.window.windowScene = UnityEmbeddedSwift.hostMainWindow.windowScene
        }
        
        ufw?.appController()?.window = UnityEmbeddedSwift.hostMainWindow
        return ufw
    }
}

//        let newVC = UIViewController()
//        if let specificWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
//            specificWindow.frame = CGRect(x: 50, y: 100, width: 200, height: 100)
//            specificWindow.rootViewController = newVC
//            newVC.addChild(unityController)
//            newVC.view.addSubview(unityController.view)
//            unityController.view.frame = CGRect(x: 50, y: 100, width: 200, height: 100)
            
//        UnityEmbeddedSwift.hideUnity()
        
//        rootViewController.addChild(hostingController)
//        hostingController.view.addSubview(rootViewController.view)
        
        
        
        //        if let rootViewController = instance.ufw.appController()?.rootViewController {
        //            let hostingController = UIHostingController(rootView: UnityControllView())
//
//            // 기존 rootViewController의 뷰를 대체하는 대신, rootViewController 자체를 교체합니다.
//            instance.ufw.appController()?.rootViewController = hostingController
////            instance.ufw.appController().rootViewController.addChild(hostingController)
////            instance.ufw.appController().rootViewController.view.addSubview(hostingController.view)
////
////            hostingController.view.frame = instance.ufw.appController().rootViewController.view.bounds
////            hostingController.didMove(toParent: instance.ufw.appController().rootViewController)
//
//
////            rootView.frame = CGRect(x: 50, y: 100, width: 200, height: 100)
//        }

//if let maskView = rootView.view.viewWithTag(888) {
//    print("tttt")
////            clearView.removeConstraints(clearView.constraints)
////            maskView.removeConstraints(maskView.constraints)
//    if 0 >= topConstant {
////                NSLayoutConstraint.activate([
////                    clearView.topAnchor.constraint(equalTo: rootView.view.topAnchor),
////                    clearView.leadingAnchor.constraint(equalTo: rootView.view.leadingAnchor),
////                    clearView.trailingAnchor.constraint(equalTo: rootView.view.trailingAnchor),
////                    clearView.heightAnchor.constraint(equalToConstant: min(abs(topConstant), height)),
////                ])
////
////                NSLayoutConstraint.activate([
////                    maskView.topAnchor.constraint(equalTo: clearView.bottomAnchor),
////                    maskView.leadingAnchor.constraint(equalTo: rootView.view.leadingAnchor),
////                    maskView.trailingAnchor.constraint(equalTo: rootView.view.trailingAnchor),
////                    maskView.bottomAnchor.constraint(equalTo: rootView.view.bottomAnchor)
////                ])
//    } else {
////                NSLayoutConstraint.activate([
////                    clearView.topAnchor.constraint(equalTo: rootView.view.topAnchor),
////                    clearView.leadingAnchor.constraint(equalTo: rootView.view.leadingAnchor),
////                    clearView.trailingAnchor.constraint(equalTo: rootView.view.trailingAnchor),
////                    clearView.heightAnchor.constraint(equalToConstant: 0),
////                ])
////
////                NSLayoutConstraint.activate([
////                    maskView.topAnchor.constraint(equalTo: clearView.bottomAnchor),
////                    maskView.leadingAnchor.constraint(equalTo: rootView.view.leadingAnchor),
////                    maskView.trailingAnchor.constraint(equalTo: rootView.view.trailingAnchor),
////                    maskView.bottomAnchor.constraint(equalTo: rootView.view.bottomAnchor)
////                ])
//    }
//} else {
////            let clearView = UIView()
////            clearView.translatesAutoresizingMaskIntoConstraints = false
////            clearView.backgroundColor = .clear
////            clearView.tag = 999
////            rootView.view.addSubview(clearView)
//    
//    let maskView = UIView()
//    maskView.translatesAutoresizingMaskIntoConstraints = false
//    maskView.tag = 888
//    maskView.backgroundColor = .red
//    maskView.frame = rootView.view.frame
//    rootView.view.mask = maskView
//    
////            NSLayoutConstraint.activate([
////                clearView.topAnchor.constraint(equalTo: rootView.view.topAnchor),
////                clearView.leadingAnchor.constraint(equalTo: rootView.view.leadingAnchor),
////                clearView.trailingAnchor.constraint(equalTo: rootView.view.trailingAnchor)
////            ])
////
////            NSLayoutConstraint.activate([
////                maskView.topAnchor.constraint(equalTo: clearView.bottomAnchor),
////                maskView.leadingAnchor.constraint(equalTo: rootView.view.leadingAnchor),
////                maskView.trailingAnchor.constraint(equalTo: rootView.view.trailingAnchor),
////                maskView.bottomAnchor.constraint(equalTo: rootView.view.bottomAnchor)
////            ])
//}
