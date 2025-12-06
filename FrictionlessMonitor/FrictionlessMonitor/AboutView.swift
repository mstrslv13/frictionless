import SwiftUI

struct AboutView: View {
    @State private var showLicense = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon
            if let imagePath = Bundle.module.path(forResource: "FrictionlessIcon", ofType: "jpg"),
               let nsImage = NSImage(contentsOfFile: imagePath) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80) // Slightly bigger as requested? "INCLUDE THE FUCKING ICON... as About page image"
                    .cornerRadius(16) // Icon style
                    .shadow(color: .white.opacity(0.2), radius: 10)
            } else {
                Image(systemName: "bolt.heart.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 4) {
                Text("Frictionless")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            VStack(spacing: 12) {
                Text("Created by William Azada")
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack(spacing: 12) {
                    Link(destination: URL(string: "https://buymeacoffee.com/mstrslva")!) {
                         Image(systemName: "cup.and.saucer")
                            .frame(width: 20, height: 20)
                    }
                    .help("Buy Me A Coffee")
                    .buttonStyle(.plain)
                    .foregroundColor(.yellow)
                    
                    Link(destination: URL(string: "https://github.com/mstrslv13")!) {
                         Image(systemName: "cat.circle")
                            .frame(width: 20, height: 20)
                    }
                    .help("GitHub")
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                }
                .font(.system(size: 20))
                
                Text("Copyright © 2025 William Azada")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button("License") {
                showLicense.toggle()
            }
            .buttonStyle(.bordered)
            .tint(.gray)
            .controlSize(.small)
            .popover(isPresented: $showLicense) {
                EULAView()
                    .frame(width: 300, height: 400)
                    .background(Color.black)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

struct EULAView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("End User License Agreement")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.bottom, 5)
                
                Text("1. Ownership & Control")
                    .font(.caption).bold()
                    .foregroundColor(.white)
                Text("This software and all associated source code are deeply exclusive property of William Azada. All rights reserved.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("2. Usage Restrictions")
                     .font(.caption).bold()
                     .foregroundColor(.white)
                Text("Usage of this code for commercial purposes, redistribution, or modification without explicit written permission from the author is strictly prohibited.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("3. Disclaimer")
                     .font(.caption).bold()
                     .foregroundColor(.white)
                Text("This software is provided 'as is' without warranty of any kind. Valid only on Earth.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .background(Color.black)
        .scrollContentBackground(.hidden)
    }
}
