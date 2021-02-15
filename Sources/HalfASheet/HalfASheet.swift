//
//  HalfASheet.swift
//
//  Created by Franklyn Weber on 28/01/2021.
//

import SwiftUI
import Combine

extension UIColor {
    public convenience init?(hex: String) {
        let r, g, b, a: CGFloat

        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])

            if hexColor.count == 8 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0

                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff000000) >> 24) / 255
                    g = CGFloat((hexNumber & 0x00ff0000) >> 16) / 255
                    b = CGFloat((hexNumber & 0x0000ff00) >> 8) / 255
                    a = CGFloat(hexNumber & 0x000000ff) / 255

                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            }
        }

        return nil
    }
}

public struct HalfASheet<Content: View>: View {
    
    @Binding private var isPresented: Bool
    @State private var hasAppeared = false
    @State private var dragOffset: CGFloat = 0
    
    internal var height: HalfASheetHeight = .proportional(0.25) // about the same as a ColorPicker
    internal var contentInsets = EdgeInsets(top: 7, leading: 16, bottom: 0, trailing: 16)
    internal var backgroundColor: UIColor = UIColor(hex: "#25265Fff")!
    internal var closeButtonColor: UIColor = .gray
    internal var allowsDraggingToDismiss = true
    
    private let title: String?
    private let content: () -> Content
    private let cornerRadius: CGFloat = 15
    private let additionalOffset: CGFloat = 44 // this is so we can drag the sheet up a bit
    
    private var actualContentInsets: EdgeInsets {
        return EdgeInsets(top: contentInsets.top, leading: contentInsets.leading, bottom: cornerRadius + additionalOffset + contentInsets.bottom, trailing: contentInsets.trailing)
    }
    
    
    public init(isPresented: Binding<Bool>, title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        _isPresented = isPresented
        self.title = title
        self.content = content
    }
    
    
    public var body: some View {
        
        GeometryReader { geometry in
            
            ZStack {
                
                if isPresented {
                    
                    Color.black.opacity(0.0)
                        .onTapGesture {
                            dismiss()
                        }
                        .transition(.opacity)
                        .onAppear { // we don't want the content to slide up until the background has appeared
                            withAnimation {
                                hasAppeared = true
                            }
                        }
                        .onDisappear() {
                            withAnimation {
                                hasAppeared = false
                            }
                        }
                }
                
                if hasAppeared {
                    
                    VStack {
                        
                        Spacer()
                        
                        ZStack {
                            
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .foregroundColor(.black)
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .foregroundColor(Color(backgroundColor))
                            
                            content()
                                .padding(actualContentInsets)
                            
                            titleView
                        }
                        .frame(height: height.value(with: geometry) + cornerRadius + additionalOffset)
                        .offset(y: cornerRadius + additionalOffset + dragOffset)
                    }
                    .transition(.verticalSlide(height.value(with: geometry)))
                    .highPriorityGesture(
                        dragGesture(geometry)
                    )
                    .onDisappear {
                        dragOffset = 0
                    }
                }
            }
        }
    }
}


// MARK: - Private
extension HalfASheet {
    
    private var titleView: IfLet {
        
        let titleView = IfLet(title) { title in
            
            VStack {
                HStack {
                    Spacer()
                    Text(title)
                        .font(Font.headline.weight(.semibold))
                        .padding(EdgeInsets(top: 18, leading: 0, bottom: 0, trailing: 0))
                        .lineLimit(1)
                    Spacer()
                }
                Spacer()
            }
            
        } else: {
            
            VStack {
                HStack {
                    Spacer()
                }
                Spacer()
            }
        }
        
        return titleView
    }
    
    private func dragGesture(_ geometry: GeometryProxy) -> _EndedGesture<_ChangedGesture<DragGesture>> {
        
        let gesture = DragGesture()
            .onChanged {
                
                guard allowsDraggingToDismiss else {
                    return
                }
                
                let offset = $0.translation.height
                dragOffset = offset > 0 ? offset : sqrt(-offset) * -3
            }
            .onEnded {
                
                guard allowsDraggingToDismiss else {
                    return
                }
                
                if dragOffset > 0, $0.predictedEndTranslation.height / $0.translation.height > 2 {
                    dismiss()
                    return
                }
                
                let validDragDistance = height.value(with: geometry) / 2
                if dragOffset < validDragDistance {
                    withAnimation {
                        dragOffset = 0
                    }
                } else {
                    dismiss()
                }
            }
        
        return gesture
    }
    
    private var closeButton: AnyView {
        
        let button = Button {
            dismiss()
        } label: {
            ZStack {
                Image(systemName: "xmark.circle.fill")
                    .font(Font.title.weight(.semibold))
                    .accentColor(Color(UIColor.lightGray.withAlphaComponent(0.2)))
                Image(systemName: "xmark.circle.fill")
                    .font(Font.title.weight(.semibold))
                    .accentColor(Color(closeButtonColor))
            }
        }
        
        return AnyView(button)
    }
    
    private func dismiss() {
        
        withAnimation {
            hasAppeared = false
            isPresented = false
        }
    }
}


public enum HalfASheetHeight {
    case fixed(CGFloat)
    case proportional(CGFloat)
    
    func value(with geometry: GeometryProxy) -> CGFloat {
        switch self {
        case .fixed(let height):
            return height
        case .proportional(let proportion):
            return geometry.size.height * proportion
        }
    }
}
