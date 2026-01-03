//
//  TargetSizeDialog.swift
//  Droppy
//
//  Created by Jordy Spruit on 03/01/2026.
//

import SwiftUI
import AppKit

/// A dialog for entering a target file size for compression
struct TargetSizeDialogView: View {
    let currentSize: Int64
    let fileName: String
    let onCompress: (Int64) -> Void
    let onCancel: () -> Void
    
    @State private var targetSizeMB: String = ""
    @State private var dashPhase: CGFloat = 0
    @State private var hoverLocation: CGPoint = .zero
    @State private var isBgHovering: Bool = false
    @State private var isCompressButtonHovering = false
    @State private var isCancelButtonHovering = false
    
    private let cornerRadius: CGFloat = 24
    
    var body: some View {
        ZStack {
            // Background with hexagon effect
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.black)
                .overlay {
                    HexagonDotsEffect(
                        mouseLocation: hoverLocation,
                        isHovering: isBgHovering,
                        coordinateSpaceName: "compressDialog"
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius - 8, style: .continuous)
                        .stroke(
                            Color.white.opacity(0.2),
                            style: StrokeStyle(
                                lineWidth: 1.5,
                                lineCap: .round,
                                dash: [6, 8],
                                dashPhase: dashPhase
                            )
                        )
                        .padding(12)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
            
            // Content
            VStack(spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 24))
                        .foregroundStyle(.blue.gradient)
                    
                    VStack(alignment: .leading) {
                        Text("Compress File")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(fileName)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                
                // Current size info
                HStack {
                    Text("Current Size:")
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Text(FileCompressor.formatSize(currentSize))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // Target size input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Size (MB)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                    
                    HStack {
                        CompressTextField(text: $targetSizeMB, onSubmit: compress)
                        
                        Text("MB")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue.opacity(0.5), lineWidth: 1.5)
                    )
                }
                
                // Buttons
                HStack(spacing: 12) {
                    Button {
                        onCancel()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(isCancelButtonHovering ? 0.25 : 0.1))
                            .clipShape(Capsule())
                            .scaleEffect(isCancelButtonHovering ? 1.05 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isCancelButtonHovering)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovering in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            isCancelButtonHovering = isHovering
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        compress()
                    } label: {
                        Text("Compress")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(isCompressButtonHovering ? 1.0 : 0.8))
                            .clipShape(Capsule())
                            .scaleEffect(isCompressButtonHovering ? 1.05 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isCompressButtonHovering)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovering in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            isCompressButtonHovering = isHovering
                        }
                    }
                    .disabled(targetBytes == nil || targetBytes! >= currentSize)
                    .opacity(targetBytes == nil || targetBytes! >= currentSize ? 0.5 : 1.0)
                }
            }
            .padding(24)
        }
        .frame(width: 340, height: 280)
        .coordinateSpace(name: "compressDialog")
        .onContinuousHover(coordinateSpace: .named("compressDialog")) { phase in
            switch phase {
            case .active(let location):
                hoverLocation = location
                isBgHovering = true
            case .ended:
                isBgHovering = false
            }
        }
        .onAppear {
            // Animate dashed border
            withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
                dashPhase -= 280
            }
            // Default to 50% of current size
            let suggestedMB = Double(currentSize) / (1024 * 1024) / 2
            targetSizeMB = String(format: "%.1f", suggestedMB)
        }
    }
    
    private var targetBytes: Int64? {
        guard let mb = Double(targetSizeMB.replacingOccurrences(of: ",", with: ".")),
              mb > 0 else {
            return nil
        }
        return Int64(mb * 1024 * 1024)
    }
    
    private func compress() {
        guard let bytes = targetBytes else { return }
        onCompress(bytes)
    }
}

// MARK: - Editable Text Field

struct CompressTextField: NSViewRepresentable {
    @Binding var text: String
    let onSubmit: () -> Void
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.drawsBackground = false
        textField.backgroundColor = .clear
        textField.textColor = .white
        textField.font = .systemFont(ofSize: 16, weight: .medium)
        textField.alignment = .left
        textField.focusRingType = .none
        textField.stringValue = text
        textField.isEditable = true
        textField.isSelectable = true
        
        // Make it the first responder after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            textField.window?.makeFirstResponder(textField)
            textField.selectText(nil)
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CompressTextField
        
        init(_ parent: CompressTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }
    }
}

/// Window controller for showing the target size dialog
class TargetSizeDialogController {
    static let shared = TargetSizeDialogController()
    
    private var window: NSWindow?
    private var continuation: CheckedContinuation<Int64?, Never>?
    
    private init() {}
    
    /// Shows the dialog and returns the target size in bytes, or nil if cancelled
    @MainActor
    func show(currentSize: Int64, fileName: String) async -> Int64? {
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            
            let dialogView = TargetSizeDialogView(
                currentSize: currentSize,
                fileName: fileName,
                onCompress: { [weak self] bytes in
                    self?.dismiss(result: bytes)
                },
                onCancel: { [weak self] in
                    self?.dismiss(result: nil)
                }
            )
            
            let hostingView = NSHostingView(rootView: dialogView)
            hostingView.frame = NSRect(x: 0, y: 0, width: 340, height: 280)
            
            let window = NSPanel(
                contentRect: hostingView.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            
            window.contentView = hostingView
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.level = .floating
            window.isMovableByWindowBackground = true
            
            // Center on screen
            if let screen = NSScreen.main {
                let screenFrame = screen.frame
                let x = (screenFrame.width - 340) / 2
                let y = (screenFrame.height - 280) / 2
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }
            
            self.window = window
            window.makeKeyAndOrderFront(nil)
            
            // Make window accept key events
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func dismiss(result: Int64?) {
        window?.close()
        window = nil
        continuation?.resume(returning: result)
        continuation = nil
    }
}
