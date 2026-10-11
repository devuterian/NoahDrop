//
//  Settings.swift
//  NoahDrop
//

import Foundation
import ServiceManagement

enum Settings{
	private static let defaults=UserDefaults.standard

	static var setupCompleted:Bool{
		get {defaults.bool(forKey: "setupCompleted")}
		set {defaults.set(newValue, forKey: "setupCompleted")}
	}

	static var autoAccept:Bool{
		get {defaults.bool(forKey: "autoAcceptFiles")}
		set {defaults.set(newValue, forKey: "autoAcceptFiles")}
	}

	static var receiveOnLaunch:Bool{
		get {defaults.object(forKey: "receiveOnLaunch") as? Bool ?? true}
		set {defaults.set(newValue, forKey: "receiveOnLaunch")}
	}

	/// nil means the Downloads folder
	static var downloadDirectory:URL?{
		get {defaults.string(forKey: "downloadDirectory").map {URL(fileURLWithPath: $0, isDirectory: true)}}
		set {defaults.set(newValue?.path, forKey: "downloadDirectory")}
	}

	static var effectiveDownloadDirectory:URL{
		downloadDirectory ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
	}

	static var launchAtLoginSupported:Bool{
		if #available(macOS 13.0, *){
			return true
		}
		return false
	}

	static var launchAtLogin:Bool{
		if #available(macOS 13.0, *){
			return SMAppService.mainApp.status == .enabled
		}
		return false
	}

	static func setLaunchAtLogin(_ enabled:Bool) throws{
		guard #available(macOS 13.0, *) else {return}
		let service=SMAppService.mainApp
		if enabled{
			if service.status != .enabled{
				try service.register()
			}
			if service.status == .requiresApproval{
				SMAppService.openSystemSettingsLoginItems()
			}
		}else if service.status != .notRegistered{
			try service.unregister()
		}
	}
}
