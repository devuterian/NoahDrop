//
//  AppDelegate.swift
//  NearDrop
//
//  Created by Grishka on 08.04.2023.
//

import Cocoa
import UserNotifications
import NearbyShare

@main
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, MainAppDelegate, NSMenuDelegate{
	private var statusItem:NSStatusItem?
	private var activeIncomingTransfers:[String:TransferInfo]=[:]
	private var setupWizard:SetupWizardController?

	private var visibilityItem:NSMenuItem!
	private var receivingItem:NSMenuItem!
	private var autoAcceptItem:NSMenuItem!
	private var saveLocationItem:NSMenuItem!
	private var launchAtLoginItem:NSMenuItem!
	private var receiveOnLaunchItem:NSMenuItem!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
		let menu=NSMenu()
		menu.autoenablesItems=false
		menu.delegate=self
		visibilityItem=menu.addItem(withTitle: "", action: nil, keyEquivalent: "")
		visibilityItem.isEnabled=false
		let deviceNameItem=menu.addItem(withTitle: String(format: NSLocalizedString("DeviceName", value: "Device name: %@", comment: ""), arguments: [Host.current().localizedName!]), action: nil, keyEquivalent: "")
		deviceNameItem.isEnabled=false
		menu.addItem(NSMenuItem.separator())
		receivingItem=addMenuItem(to: menu, title: NSLocalizedString("Receiving", value: "Receive files", comment: ""), action: #selector(toggleReceiving(_:)))
		autoAcceptItem=addMenuItem(to: menu, title: NSLocalizedString("AutoAccept", value: "Accept files automatically", comment: ""), action: #selector(toggleAutoAccept(_:)))
		saveLocationItem=addMenuItem(to: menu, title: "", action: #selector(chooseSaveLocation(_:)))
		addMenuItem(to: menu, title: NSLocalizedString("ShowReceivedFiles", value: "Show Received Files", comment: ""), action: #selector(showReceivedFiles(_:)))
		menu.addItem(NSMenuItem.separator())
		launchAtLoginItem=addMenuItem(to: menu, title: NSLocalizedString("LaunchAtLogin", value: "Open at login", comment: ""), action: #selector(toggleLaunchAtLogin(_:)))
		launchAtLoginItem.isHidden = !Settings.launchAtLoginSupported
		receiveOnLaunchItem=addMenuItem(to: menu, title: NSLocalizedString("ReceiveOnLaunch", value: "Receive files when NoahDrop opens", comment: ""), action: #selector(toggleReceiveOnLaunch(_:)))
		menu.addItem(NSMenuItem.separator())
		addMenuItem(to: menu, title: NSLocalizedString("SetupWizard", value: "Setup Wizard…", comment: ""), action: #selector(showSetupWizard(_:)))
		menu.addItem(withTitle: NSLocalizedString("Quit", value: "Quit NoahDrop", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
		statusItem=NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
		statusItem?.button?.image=NSImage(named: "MenuBarIcon")
		statusItem?.menu=menu
		statusItem?.behavior = .removalAllowed

		let nc=UNUserNotificationCenter.current()
		nc.delegate=self
		let incomingTransfersCategory=UNNotificationCategory(identifier: "INCOMING_TRANSFERS", actions: [
			UNNotificationAction(identifier: "ACCEPT", title: NSLocalizedString("Accept", comment: ""), options: UNNotificationActionOptions.authenticationRequired),
			UNNotificationAction(identifier: "DECLINE", title: NSLocalizedString("Decline", comment: ""))
		], intentIdentifiers: [])
		let errorsCategory=UNNotificationCategory(identifier: "ERRORS", actions: [], intentIdentifiers: [])
		nc.setNotificationCategories([incomingTransfersCategory, errorsCategory])
		NearbyConnectionManager.shared.mainAppDelegate=self
		NearbyConnectionManager.shared.downloadDirectory=Settings.downloadDirectory

		if Settings.setupCompleted{
			requestNotificationPermission()
			if Settings.receiveOnLaunch{
				NearbyConnectionManager.shared.becomeVisible()
			}
		}else{
			showSetupWizard(nil)
		}
		updateMenu()
	}

	func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
		statusItem?.isVisible=true
		return true
	}

    func applicationWillTerminate(_ aNotification: Notification) {
		UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

	@discardableResult
	private func addMenuItem(to menu:NSMenu, title:String, action:Selector) -> NSMenuItem{
		let item=menu.addItem(withTitle: title, action: action, keyEquivalent: "")
		item.target=self
		return item
	}

	func menuWillOpen(_ menu: NSMenu) {
		updateMenu()
	}

	func updateMenu(){
		let visible=NearbyConnectionManager.shared.isVisible
		visibilityItem.title=visible ? NSLocalizedString("VisibleToEveryone", value: "Visible to everyone", comment: "") : NSLocalizedString("ReceivingOff", value: "Receiving is off", comment: "")
		receivingItem.state=visible ? .on : .off
		autoAcceptItem.state=Settings.autoAccept ? .on : .off
		saveLocationItem.title=String(format: NSLocalizedString("SaveTo", value: "Save to: %@", comment: ""), arguments: [FileManager.default.displayName(atPath: Settings.effectiveDownloadDirectory.path)])
		launchAtLoginItem.state=Settings.launchAtLogin ? .on : .off
		receiveOnLaunchItem.state=Settings.receiveOnLaunch ? .on : .off
		statusItem?.button?.appearsDisabled = !visible
	}

	func setReceiving(_ enabled:Bool){
		if enabled{
			NearbyConnectionManager.shared.becomeVisible()
		}else{
			NearbyConnectionManager.shared.becomeInvisible()
		}
		updateMenu()
	}

	func setDownloadDirectory(_ url:URL?){
		Settings.downloadDirectory=url
		NearbyConnectionManager.shared.downloadDirectory=url
		updateMenu()
	}

	@objc func toggleReceiving(_ sender:NSMenuItem){
		setReceiving(!NearbyConnectionManager.shared.isVisible)
	}

	@objc func toggleAutoAccept(_ sender:NSMenuItem){
		Settings.autoAccept = !Settings.autoAccept
		updateMenu()
	}

	@objc func toggleReceiveOnLaunch(_ sender:NSMenuItem){
		Settings.receiveOnLaunch = !Settings.receiveOnLaunch
		updateMenu()
	}

	@objc func toggleLaunchAtLogin(_ sender:NSMenuItem){
		do{
			try Settings.setLaunchAtLogin(!Settings.launchAtLogin)
		}catch{
			AppDelegate.showLaunchAtLoginError(error)
		}
		updateMenu()
	}

	static func showLaunchAtLoginError(_ error:Error){
		let alert=NSAlert()
		alert.alertStyle = .warning
		alert.messageText=NSLocalizedString("LaunchAtLoginError", value: "Couldn't change the login item setting", comment: "")
		alert.informativeText=error.localizedDescription
		alert.runModal()
	}

	@objc func chooseSaveLocation(_ sender:NSMenuItem){
		NSApp.activate(ignoringOtherApps: true)
		if let url=AppDelegate.runFolderPicker(){
			setDownloadDirectory(url)
		}
	}

	static func runFolderPicker() -> URL?{
		let panel=NSOpenPanel()
		panel.canChooseFiles=false
		panel.canChooseDirectories=true
		panel.canCreateDirectories=true
		panel.allowsMultipleSelection=false
		panel.directoryURL=Settings.effectiveDownloadDirectory
		panel.prompt=NSLocalizedString("ChooseFolder", value: "Choose", comment: "")
		return panel.runModal() == .OK ? panel.url : nil
	}

	@objc func showReceivedFiles(_ sender:NSMenuItem){
		NSWorkspace.shared.open(Settings.effectiveDownloadDirectory)
	}

	@objc func showSetupWizard(_ sender:Any?){
		if setupWizard==nil{
			setupWizard=SetupWizardController(appDelegate: self)
		}
		NSApp.activate(ignoringOtherApps: true)
		setupWizard?.showWindow(nil)
		setupWizard?.window?.center()
		setupWizard?.window?.makeKeyAndOrderFront(nil)
	}

	func setupWizardDidClose(){
		setupWizard=nil
		updateMenu()
	}

	func requestNotificationPermission(completion:((Bool)->Void)?=nil){
		UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, err in
			DispatchQueue.main.async {
				if let completion=completion{
					completion(granted)
				}else if !granted{
					self.showNotificationsDeniedAlert()
				}
			}
		}
	}

	func showNotificationsDeniedAlert(){
		let alert=NSAlert()
		alert.alertStyle = .critical
		alert.messageText=NSLocalizedString("NotificationsDenied.Title", value: "Notification Permission Required", comment: "")
		alert.informativeText=NSLocalizedString("NotificationsDenied.Message", value: "NoahDrop needs to be able to display notifications for incoming file transfers. Please allow notifications in System Settings.", comment: "")
		alert.addButton(withTitle: NSLocalizedString("NotificationsDenied.OpenSettings", value: "Open settings", comment: ""))
		alert.addButton(withTitle: NSLocalizedString("Quit", value: "Quit NoahDrop", comment: ""))
		let result=alert.runModal()
		if result==NSApplication.ModalResponse.alertFirstButtonReturn{
			NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
		}else if result==NSApplication.ModalResponse.alertSecondButtonReturn{
			NSApplication.shared.terminate(nil)
		}
	}

	func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
		let userInfo=response.notification.request.content.userInfo
		if let transferID=userInfo["transferID"] as? String{
			NearbyConnectionManager.shared.submitUserConsent(transferID: transferID, accept: response.actionIdentifier=="ACCEPT")
			if response.actionIdentifier != "ACCEPT"{
				activeIncomingTransfers.removeValue(forKey: transferID)
			}
		}else if let folder=userInfo["receivedFolder"] as? String{
			NSWorkspace.shared.open(URL(fileURLWithPath: folder, isDirectory: true))
		}
		completionHandler()
	}

	private func describeFiles(in transfer:TransferMetadata) -> String{
		if let textTitle=transfer.textDescription{
			return textTitle
		}else if transfer.files.count==1{
			return transfer.files[0].name
		}else{
			return String.localizedStringWithFormat(NSLocalizedString("NFiles", value: "%d files", comment: ""), transfer.files.count)
		}
	}

	func obtainUserConsent(for transfer: TransferMetadata, from device: RemoteDeviceInfo) {
		let fileStr=describeFiles(in: transfer)
		self.activeIncomingTransfers[transfer.id]=TransferInfo(device: device, transfer: transfer)
		let notificationContent=UNMutableNotificationContent()
		notificationContent.title="NoahDrop"
		notificationContent.subtitle=String(format:NSLocalizedString("PinCode", value: "PIN: %@", comment: ""), arguments: [transfer.pinCode!])
		notificationContent.sound = .default
		if Settings.autoAccept{
			NearbyConnectionManager.shared.submitUserConsent(transferID: transfer.id, accept: true)
			notificationContent.body=String(format: NSLocalizedString("ReceivingFiles", value: "Receiving %1$@ from %2$@", comment: ""), arguments: [fileStr, device.name])
			notificationContent.categoryIdentifier="ERRORS" // no action buttons
		}else{
			notificationContent.body=String(format: NSLocalizedString("DeviceSendingFiles", value: "%1$@ is sending you %2$@", comment: ""), arguments: [device.name, fileStr])
			notificationContent.categoryIdentifier="INCOMING_TRANSFERS"
			notificationContent.userInfo=["transferID": transfer.id]
			if #available(macOS 11.0, *){
				NDNotificationCenterHackery.removeDefaultAction(notificationContent)
			}
		}
		let notificationReq=UNNotificationRequest(identifier: "transfer_"+transfer.id, content: notificationContent, trigger: nil)
		UNUserNotificationCenter.current().add(notificationReq)
	}

	func incomingTransfer(id: String, didFinishWith error: Error?) {
		guard let transfer=self.activeIncomingTransfers[id] else {return}
		if let error=error{
			let notificationContent=UNMutableNotificationContent()
			notificationContent.title=String(format: NSLocalizedString("TransferError", value: "Failed to receive files from %@", comment: ""), arguments: [transfer.device.name])
			if let ne=(error as? NearbyError){
				switch ne{
				case .inputOutput:
					notificationContent.body="I/O Error";
				case .protocolError(_):
					notificationContent.body=NSLocalizedString("Error.Protocol", value: "Communication error", comment: "")
				case .requiredFieldMissing:
					notificationContent.body=NSLocalizedString("Error.Protocol", value: "Communication error", comment: "")
				case .ukey2:
					notificationContent.body=NSLocalizedString("Error.Crypto", value: "Encryption error", comment: "")
				case .canceled(reason: _):
					break; // can't happen for incoming transfers
				}
			}else{
				notificationContent.body=error.localizedDescription
			}
			notificationContent.categoryIdentifier="ERRORS"
			UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "transferError_"+id, content: notificationContent, trigger: nil))
		}else if Settings.autoAccept && transfer.transfer.textDescription==nil{
			// There's no consent notification to look at when auto-accepting, so say where the files went
			let notificationContent=UNMutableNotificationContent()
			notificationContent.title="NoahDrop"
			notificationContent.body=String(format: NSLocalizedString("FilesReceived", value: "Received %1$@ from %2$@", comment: ""), arguments: [describeFiles(in: transfer.transfer), transfer.device.name])
			notificationContent.categoryIdentifier="ERRORS"
			notificationContent.userInfo=["receivedFolder": Settings.effectiveDownloadDirectory.path]
			UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "received_"+id, content: notificationContent, trigger: nil))
		}
		UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["transfer_"+id])
		self.activeIncomingTransfers.removeValue(forKey: id)
	}
}

struct TransferInfo{
	let device:RemoteDeviceInfo
	let transfer:TransferMetadata
}
