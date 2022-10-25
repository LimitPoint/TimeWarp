//
//  ScaleOptionsView.swift
//  ScaleVideo
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/time-warp/
//
//  Created by Joseph Pagliaro on 3/15/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct PickerView: View {
    
    @ObservedObject var scaleVideoObservable: ScaleVideoObservable
    
    @State private var isEditing = false
    
    var body: some View {
        VStack {
            Picker("Scaling", selection: $scaleVideoObservable.scalingType) {
                ForEach(ScaleFunctionType.allCases) { scalingType in
                    Text(scalingType.rawValue)
                }
            }
            
            Text("Select an instantaneous time scaling function.\nUse Factor and Modifier parameters to customize it.")
                .font(.caption)
                .padding(1)
        }
    }
}

struct FactorView: View {
    
    @ObservedObject var scaleVideoObservable: ScaleVideoObservable
    
    @State private var isEditing = false
    
    var body: some View {
        VStack {
            Text(String(format: "%.2f", scaleVideoObservable.factor))
                .foregroundColor(isEditing ? .red : .blue)
            
            Slider(
                value: $scaleVideoObservable.factor,
                in: 0.1...4
            ) {
                Text("Factor")
            } minimumValueLabel: {
                Text("0.1")
            } maximumValueLabel: {
                Text("4")
            } onEditingChanged: { editing in
                isEditing = editing
            }
            
            Text("See plot above to see effect of factor on it.")
                .font(.caption)
                .padding()
        }
    }
}

struct ModiferView: View {
    
    @ObservedObject var scaleVideoObservable: ScaleVideoObservable
    
    @State private var isEditing = false
    
    var body: some View {
        
        if scaleVideoObservable.scalingType == .constant {
            Text("Constant time scaling has no modifer.")
        }
        else {
            VStack {
                Text(String(format: "%.2f", scaleVideoObservable.modifier))
                    .foregroundColor(isEditing ? .red : .blue) 
                Slider(
                    value: $scaleVideoObservable.modifier,
                    in: 0.1...1
                ) {
                    Text("Modifier")
                } minimumValueLabel: {
                    Text("0.1")
                } maximumValueLabel: {
                    Text("1")
                } onEditingChanged: { editing in
                    isEditing = editing
                }
                
                Text("See plot above to see effect of modifier on it.")
                    .font(.caption)
                    .padding()
            }
        }
    }
}

struct FrameRateView: View {
    
    @ObservedObject var scaleVideoObservable: ScaleVideoObservable
        
    var body: some View {
        VStack {
            Picker("Frame Rate", selection: $scaleVideoObservable.fps) {
                Text("24").tag(FPS.twentyFour)
                Text("30").tag(FPS.thirty)
                Text("60").tag(FPS.sixty)
                Text("Any").tag(FPS.any)
            }
            .pickerStyle(.segmented)
            
            Text("\'Any\' is the natural rate due to variable scaling. Fixed rates are achieved by resampling.\n\nSee estimated FPS in plot caption above.")
                .font(.caption)
                .padding()
        }
    }
}

struct ScaleOptionsView: View {
    @ObservedObject var scaleVideoObservable: ScaleVideoObservable
    
    @State private var isEditing = false
    
    var body: some View {
        TabView {
            PickerView(scaleVideoObservable: scaleVideoObservable)
                .tabItem {
                    Image(systemName: "function")
                    Text("Scale Type")
                }
            
            FactorView(scaleVideoObservable: scaleVideoObservable)
                .tabItem {
                    Image(systemName: "f.circle.fill")
                    Text("Factor")
                }
            
            ModiferView(scaleVideoObservable: scaleVideoObservable)
                .tabItem {
                    Image(systemName: "m.circle.fill")
                    Text("Modifer")
                }
            
            FrameRateView(scaleVideoObservable: scaleVideoObservable)
                .tabItem {
                    Image(systemName: "speedometer")
                    Text("Frame Rate")
                }
        }
        .padding()
    }
}

struct ScaleOptionsView_Previews: PreviewProvider {
    static var previews: some View {
        ScaleOptionsView(scaleVideoObservable: ScaleVideoObservable())
    }
}
