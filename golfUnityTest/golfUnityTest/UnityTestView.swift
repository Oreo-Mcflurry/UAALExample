//
//  ViewController.swift
//  golfUnityTest
//
//  Created by 에스지랩 on 8/20/24.
//

import SwiftUI
import UnityFramework

struct UnityTestView: View {
    @State private var offset: CGFloat = .zero
    @State private var top: CGFloat = .zero
    @State private var leading: CGFloat = .zero
    @State private var trailing: CGFloat = .zero
    @State private var height: CGFloat = .zero
    var body: some View {
        NavigationStack {
            NavigationLink("123") {
                unityView
            }
        }
    }
}

extension UnityTestView {
    private var unityView: some View {
        OffsetObservableScrollView(scrollOffset: $offset) {
            
            Rectangle()
                .frame(height: 200)
                .padding(20)
            
            Spacer()
            
            Button {
                UnityEmbeddedSwift.showUnity()
                top = 20
                leading = 20
                trailing = 20
                height = 200
                UnityEmbeddedSwift.resizeViewControllerView(topConstant: top - offset, leadingConstant: leading, trailingConstant: trailing, height: height, withAnimation: true)
            } label: {
                Text("TestTest")
            }
            
            
            Button {
                top = 20
                leading = 20
                trailing = 80
                height = 100
                UnityEmbeddedSwift.resizeViewControllerView(topConstant: top - offset, leadingConstant: leading, trailingConstant: trailing, height: height, withAnimation: true)
            } label: {
                Text("Animation")
            }
            
            Spacer()
        }
        .onChange(of: offset) { newValue in
            UnityEmbeddedSwift.resizeViewControllerView(topConstant: top - newValue, leadingConstant: leading, trailingConstant: trailing, height: height)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UnityEmbeddedSwift.hideUnity()
                } label: {
                    Image(systemName: "star")
                }
            }
        }
    }
}

struct UnityControllView: View {
    var body: some View {
        Button {
            UnityEmbeddedSwift.hideUnity()
        } label: {
            Text("Control")
        }
    }
}


class HybridViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        UnityEmbeddedSwift.showUnity()
        
//        if let uView = UnityEmbeddedSwift.getUnityView() {
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
//                self.view.addSubview(uView)
//                
//                NSLayoutConstraint.activate([
//                    uView.topAnchor.constraint(equalTo: self.view.topAnchor),
//                    uView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
//                    uView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
//                    uView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
//                ])
//                
////                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
////                    self.view.sendSubviewToBack(uView)
////                })
//            })
//        }
    }
}

extension UIViewController {
    func toSwiftUIView() -> some View {
        // Custom UIViewControllerRepresentable to wrap the UIViewController
        struct ViewControllerWrapper: UIViewControllerRepresentable {
            let viewController: UIViewController
            
            func makeUIViewController(context: Context) -> UIViewController {
                return viewController
            }
            
            func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
                // No update needed for static content
            }
        }
    
        return ViewControllerWrapper(viewController: self)
    }
}

struct OffsetObservableScrollView<Content: View>: View {
  var axes: Axis.Set = .vertical
  var showsIndicators: Bool = true
  
  @Binding var scrollOffset: CGFloat
  @ViewBuilder var content: () -> Content
  
  @Namespace var coordinateSpaceName: Namespace.ID
  
  init(
    _ axes: Axis.Set = .vertical,
    showsIndicators: Bool = true,
    scrollOffset: Binding<CGFloat>,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.axes = axes
    self.showsIndicators = showsIndicators
    self._scrollOffset = scrollOffset
    self.content = content
  }
  
  var body: some View {
    ScrollView(axes, showsIndicators: showsIndicators) {
      ScrollViewReader { _ in
        content()
          .background {
            GeometryReader { geometryProxy in
              Color.clear
                .preference(
                  key: ScrollOffsetPreferenceKey.self,
                  value: CGPoint(
                    x: -geometryProxy.frame(in: .named(coordinateSpaceName)).minX,
                    y: -geometryProxy.frame(in: .named(coordinateSpaceName)).minY
                  )
                )
            }
          }
      }
    }
    .coordinateSpace(name: coordinateSpaceName)
    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
        scrollOffset = value.y
    }
  }
  
  private struct ScrollOffsetPreferenceKey: SwiftUI.PreferenceKey {
    static var defaultValue: CGPoint { .zero }
    
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
      value.x += nextValue().x
      value.y += nextValue().y
    }
  }
}
