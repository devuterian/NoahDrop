//
//  SetupWizardController.swift
//  NoahDrop
//

import Cocoa
import UserNotifications

/// First-run setup that asks one question per page. Can be reopened from the menu bar.
class SetupWizardController: NSWindowController, NSWindowDelegate{
	private weak var appDelegate:AppDelegate?
	private var pages:[NSView]=[]
	private var currentPage=0
	private var finished=false

	private let contentHolder=NSView()
	private let stepLabel=NSTextField(labelWithString: "")
	private let backButton=NSButton()
	private let nextButton=NSButton()

	// Choices, applied when the wizard is finished
	private var autoAccept=Settings.autoAccept
	private var downloadDirectory=Settings.downloadDirectory
	private var launchAtLogin=Settings.launchAtLoginSupported ? (Settings.setupCompleted ? Settings.launchAtLogin : true) : false
	private var receiveOnLaunch=Settings.receiveOnLaunch

	private let notificationStatusLabel=NSTextField(labelWithString: "")
	private let folderPathLabel=NSTextField(labelWithString: "")
	private var askEveryTimeRadio:NSButton!
	private var autoAcceptRadio:NSButton!
	private var downloadsRadio:NSButton!
	private var customFolderRadio:NSButton!

	init(appDelegate:AppDelegate){
		self.appDelegate=appDelegate
		let window=NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 340), styleMask: [.titled, .closable], backing: .buffered, defer: false)
		window.title=NSLocalizedString("Wizard.WindowTitle", value: "NoahDrop Setup", comment: "")
		window.isReleasedWhenClosed=false
		super.init(window: window)
		window.delegate=self
		buildPages()
		buildLayout()
		showPage(0)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	// MARK: - Layout

	private func buildLayout(){
		let root=window!.contentView!
		contentHolder.translatesAutoresizingMaskIntoConstraints=false
		root.addSubview(contentHolder)

		stepLabel.textColor = .secondaryLabelColor
		backButton.title=NSLocalizedString("Wizard.Back", value: "Back", comment: "")
		backButton.bezelStyle = .rounded
		backButton.target=self
		backButton.action=#selector(goBack)
		nextButton.bezelStyle = .rounded
		nextButton.keyEquivalent="\r"
		nextButton.target=self
		nextButton.action=#selector(goNext)

		let footer=NSStackView(views: [stepLabel, NSView(), backButton, nextButton])
		footer.orientation = .horizontal
		footer.translatesAutoresizingMaskIntoConstraints=false
		root.addSubview(footer)

		NSLayoutConstraint.activate([
			contentHolder.topAnchor.constraint(equalTo: root.topAnchor, constant: 24),
			contentHolder.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 28),
			contentHolder.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),
			contentHolder.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -16),
			footer.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 28),
			footer.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
			footer.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20),
		])
	}

	private func makePage(title:String, body:String, controls:[NSView]=[]) -> NSView{
		let titleLabel=NSTextField(labelWithString: title)
		titleLabel.font = .boldSystemFont(ofSize: 18)
		let bodyLabel=NSTextField(wrappingLabelWithString: body)
		bodyLabel.preferredMaxLayoutWidth=464
		let stack=NSStackView(views: [titleLabel, bodyLabel]+controls)
		stack.orientation = .vertical
		stack.alignment = .leading
		stack.spacing=12
		stack.setCustomSpacing(16, after: bodyLabel)
		return stack
	}

	private func radio(_ title:String, _ action:Selector) -> NSButton{
		return NSButton(radioButtonWithTitle: title, target: self, action: action)
	}

	private func buildPages(){
		pages.append(makePage(title: NSLocalizedString("Wizard.Welcome.Title", value: "Welcome to NoahDrop", comment: ""),
							  body: NSLocalizedString("Wizard.Welcome.Body", value: "NoahDrop lets Android phones send files to this Mac with Quick Share. It lives in the menu bar.\n\nA few quick questions, one at a time. You can change everything later from the menu bar icon.", comment: "")))

		let allowButton=NSButton(title: NSLocalizedString("Wizard.Notifications.Allow", value: "Allow Notifications", comment: ""), target: self, action: #selector(allowNotifications))
		allowButton.bezelStyle = .rounded
		notificationStatusLabel.textColor = .secondaryLabelColor
		pages.append(makePage(title: NSLocalizedString("Wizard.Notifications.Title", value: "Notifications", comment: ""),
							  body: NSLocalizedString("Wizard.Notifications.Body", value: "When someone sends you a file, NoahDrop shows a notification with the PIN and Accept/Decline buttons. Without notifications you won't know a file is coming.", comment: ""),
							  controls: [allowButton, notificationStatusLabel]))

		askEveryTimeRadio=radio(NSLocalizedString("Wizard.AutoAccept.Ask", value: "Ask me every time (recommended)", comment: ""), #selector(autoAcceptChanged(_:)))
		autoAcceptRadio=radio(NSLocalizedString("Wizard.AutoAccept.Auto", value: "Accept automatically", comment: ""), #selector(autoAcceptChanged(_:)))
		let autoAcceptNote=NSTextField(wrappingLabelWithString: NSLocalizedString("Wizard.AutoAccept.Note", value: "NoahDrop is visible to everyone on your Wi-Fi network. With automatic accept, anyone on the network can drop files on your Mac.", comment: ""))
		autoAcceptNote.textColor = .secondaryLabelColor
		autoAcceptNote.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
		autoAcceptNote.preferredMaxLayoutWidth=464
		pages.append(makePage(title: NSLocalizedString("Wizard.AutoAccept.Title", value: "Incoming files", comment: ""),
							  body: NSLocalizedString("Wizard.AutoAccept.Body", value: "When a phone sends you something, should NoahDrop ask first or just save it?", comment: ""),
							  controls: [askEveryTimeRadio, autoAcceptRadio, autoAcceptNote]))

		downloadsRadio=radio(NSLocalizedString("Wizard.Folder.Downloads", value: "Downloads folder", comment: ""), #selector(folderChoiceChanged(_:)))
		customFolderRadio=radio(NSLocalizedString("Wizard.Folder.Custom", value: "Another folder…", comment: ""), #selector(folderChoiceChanged(_:)))
		folderPathLabel.textColor = .secondaryLabelColor
		folderPathLabel.lineBreakMode = .byTruncatingMiddle
		folderPathLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 464).isActive=true
		pages.append(makePage(title: NSLocalizedString("Wizard.Folder.Title", value: "Where to save", comment: ""),
							  body: NSLocalizedString("Wizard.Folder.Body", value: "Where should received files go?", comment: ""),
							  controls: [downloadsRadio, customFolderRadio, folderPathLabel]))

		var startupControls:[NSView]=[]
		if Settings.launchAtLoginSupported{
			let loginCheckbox=NSButton(checkboxWithTitle: NSLocalizedString("Wizard.Startup.Login", value: "Open NoahDrop when I log in", comment: ""), target: self, action: #selector(launchAtLoginChanged(_:)))
			loginCheckbox.state=launchAtLogin ? .on : .off
			startupControls.append(loginCheckbox)
		}
		let receiveCheckbox=NSButton(checkboxWithTitle: NSLocalizedString("Wizard.Startup.Receive", value: "Start receiving as soon as NoahDrop opens", comment: ""), target: self, action: #selector(receiveOnLaunchChanged(_:)))
		receiveCheckbox.state=receiveOnLaunch ? .on : .off
		startupControls.append(receiveCheckbox)
		pages.append(makePage(title: NSLocalizedString("Wizard.Startup.Title", value: "Starting up", comment: ""),
							  body: NSLocalizedString("Wizard.Startup.Body", value: "You can always turn receiving on or off from the menu bar.", comment: ""),
							  controls: startupControls))

		pages.append(makePage(title: NSLocalizedString("Wizard.Done.Title", value: "All set", comment: ""),
							  body: String(format: NSLocalizedString("Wizard.Done.Body", value: "To send a file from your phone, keep both devices on the same Wi-Fi, tap Share → Quick Share, and pick \"%@\".\n\nTo send from this Mac to a phone, right-click a file in Finder and choose Share → NoahDrop.", comment: ""), arguments: [Host.current().localizedName ?? "Mac"])))

		syncControls()
	}

	private func syncControls(){
		askEveryTimeRadio.state=autoAccept ? .off : .on
		autoAcceptRadio.state=autoAccept ? .on : .off
		downloadsRadio.state=downloadDirectory==nil ? .on : .off
		customFolderRadio.state=downloadDirectory==nil ? .off : .on
		folderPathLabel.stringValue=(downloadDirectory ?? Settings.effectiveDownloadDirectory).path
		UNUserNotificationCenter.current().getNotificationSettings { settings in
			DispatchQueue.main.async {
				switch settings.authorizationStatus{
				case .authorized, .provisional:
					self.notificationStatusLabel.stringValue=NSLocalizedString("Wizard.Notifications.Allowed", value: "✓ Notifications are allowed", comment: "")
				case .denied:
					self.notificationStatusLabel.stringValue=NSLocalizedString("Wizard.Notifications.Denied", value: "Notifications are turned off. Turn them on for NoahDrop in System Settings → Notifications.", comment: "")
				default:
					self.notificationStatusLabel.stringValue=""
				}
			}
		}
	}

	// MARK: - Navigation

	private func showPage(_ index:Int){
		currentPage=index
		contentHolder.subviews.forEach {$0.removeFromSuperview()}
		let page=pages[index]
		page.translatesAutoresizingMaskIntoConstraints=false
		contentHolder.addSubview(page)
		NSLayoutConstraint.activate([
			page.topAnchor.constraint(equalTo: contentHolder.topAnchor),
			page.leadingAnchor.constraint(equalTo: contentHolder.leadingAnchor),
			page.trailingAnchor.constraint(lessThanOrEqualTo: contentHolder.trailingAnchor),
		])
		stepLabel.stringValue="\(index+1) / \(pages.count)"
		backButton.isHidden = index==0
		nextButton.title=index==pages.count-1 ? NSLocalizedString("Wizard.Finish", value: "Done", comment: "") : NSLocalizedString("Wizard.Next", value: "Next", comment: "")
	}

	@objc private func goBack(){
		if currentPage>0{
			showPage(currentPage-1)
		}
	}

	@objc private func goNext(){
		if currentPage<pages.count-1{
			showPage(currentPage+1)
		}else{
			finish()
		}
	}

	private func finish(){
		finished=true
		Settings.autoAccept=autoAccept
		Settings.receiveOnLaunch=receiveOnLaunch
		Settings.setupCompleted=true
		appDelegate?.setDownloadDirectory(downloadDirectory)
		if Settings.launchAtLoginSupported{
			do{
				try Settings.setLaunchAtLogin(launchAtLogin)
			}catch{
				AppDelegate.showLaunchAtLoginError(error)
			}
		}
		appDelegate?.setReceiving(true)
		close()
	}

	func windowWillClose(_ notification: Notification) {
		// Closed halfway through the first run: still start receiving so the app isn't silently useless; the wizard comes back next launch.
		if !finished && !Settings.setupCompleted{
			appDelegate?.setReceiving(true)
		}
		appDelegate?.setupWizardDidClose()
	}

	// MARK: - Actions

	@objc private func allowNotifications(){
		appDelegate?.requestNotificationPermission { granted in
			if !granted{
				NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
			}
			self.syncControls()
		}
	}

	@objc private func autoAcceptChanged(_ sender:NSButton){
		autoAccept = sender===autoAcceptRadio
		syncControls()
	}

	@objc private func folderChoiceChanged(_ sender:NSButton){
		if sender===customFolderRadio{
			if let url=AppDelegate.runFolderPicker(){
				downloadDirectory=url
			}
		}else{
			downloadDirectory=nil
		}
		syncControls()
	}

	@objc private func launchAtLoginChanged(_ sender:NSButton){
		launchAtLogin = sender.state == .on
	}

	@objc private func receiveOnLaunchChanged(_ sender:NSButton){
		receiveOnLaunch = sender.state == .on
	}
}
