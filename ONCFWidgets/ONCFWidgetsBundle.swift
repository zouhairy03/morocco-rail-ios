//
//  ONCFWidgetsBundle.swift
//  ONCFWidgets
//
//  Created by Zouhair Youssef on 29/6/2026.
//

import WidgetKit
import SwiftUI

@main
struct ONCFWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ONCFWidgets()
        ONCFWidgetsControl()
        ONCFWidgetsLiveActivity()
    }
}
