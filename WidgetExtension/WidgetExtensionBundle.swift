//
//  WidgetExtensionBundle.swift
//  WidgetExtension
//
//  Created by ZhangYaoDong on 2025/8/9.
//

import WidgetKit
import SwiftUI

@main
struct WidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        WidgetExtension()
        WidgetExtensionControl()
        WidgetExtensionLiveActivity()
    }
}
