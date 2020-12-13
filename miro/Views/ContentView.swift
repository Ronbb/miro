//
//  ContentView.swift
//  miro
//
//  Created by 不会说话的猫 on 2020/11/15.
//

import SwiftUI

struct ContentView: View {
    var cpuCount: Int!
    
    init() {
        cpuCount = Int(av_cpu_count())
    }
    var body: some View {
        Text("CPU: \(cpuCount)")
            .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
