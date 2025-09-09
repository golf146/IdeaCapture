//
//  NewWidgetExtensionBundle.swift
//  NewWidgetExtension
//
//  Created by ZhangYaoDong on 2025/8/9.
//

import WidgetKit
import SwiftUI

@main
struct NewWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        NewWidgetExtension()
        NewWidgetExtensionLiveActivity()
    }
}
