//
//  CadenceLockScreenBundle.swift
//  CadenceLockScreen
//

import SwiftUI
import WidgetKit

@main
struct CadenceLockScreenBundle: WidgetBundle {
    var body: some Widget {
        ListLiveActivity()
        AddTaskControl()
    }
}
