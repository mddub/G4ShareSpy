//
//  G4CGMManager+UI.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import LoopKit
import LoopKitUI
import HealthKit


extension G4CGMManager: CGMManagerUI {
    public static func setupViewController() -> (UIViewController & CGMManagerSetupViewController)? {
        return nil  // We don't require configuration
    }

    public func settingsViewController(for glucoseUnit: HKUnit) -> UIViewController {
        return G4CGMManagerSettingsViewController(cgmManager: self, glucoseUnit: glucoseUnit)
    }

    public var smallImage: UIImage? {
        return nil
    }
}
