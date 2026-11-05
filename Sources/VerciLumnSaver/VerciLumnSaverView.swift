import ScreenSaver
import AppKit
import SwiftUI

@objc(VerciLumnSaverView)
public final class VerciLumnSaverView: ScreenSaverView {
    private var stateModel: ScreenSaverStateModel?
    private var hostingView: NSHostingView<VerciLumnSaverContentView>?
    
    public override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        commonInit(isPreview: isPreview)
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit(isPreview: false)
    }
    
    private func commonInit(isPreview: Bool) {
        // Enforce strict thermal invariant: 30 FPS cap
        self.animationTimeInterval = 1.0 / 30.0
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.black.cgColor
        
        let model = ScreenSaverStateModel(isPreview: isPreview)
        self.stateModel = model
        let contentView = VerciLumnSaverContentView(model: model, isPreview: isPreview)
        let hosting = NSHostingView(rootView: contentView)
        hosting.frame = self.bounds
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        self.addSubview(hosting)
        self.hostingView = hosting
    }
    
    public override var hasConfigureSheet: Bool {
        return false
    }
    
    public override func animateOneFrame() {
        stateModel?.stepFrame()
    }
    
    public override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        hostingView?.frame = self.bounds
    }
}
