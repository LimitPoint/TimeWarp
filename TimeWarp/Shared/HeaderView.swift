//
//  HeaderView.swift
//  ScaleAudio
//
//  Created by Joseph Pagliaro on 2/11/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct HeaderView: View {
    
    @ObservedObject var scaleVideoObservable: ScaleVideoObservable
    
    var body: some View {
        VStack {
            Text("Files generated into Documents folder")
                .fontWeight(.bold)
                .padding(2)
                .multilineTextAlignment(.center)
            Text("Variably scale video time with the instantaneous time scaling function selected below.")
                .multilineTextAlignment(.center)
#if os(macOS)
            Button("Go to Documents", action: { 
                NSWorkspace.shared.open(scaleVideoObservable.documentsURL)
            }).padding(2)
#endif
        }
    }
}

struct HeaderView_Previews: PreviewProvider {
    static var previews: some View {
        HeaderView(scaleVideoObservable: ScaleVideoObservable())
    }
}
