//
//  MessageComposeDelegate.swift
//  TrailMatesATX
//
//  Created by Jake Kinchen on 11/20/24.
//


import SwiftUI
import MessageUI

@MainActor
class MessageComposeDelegate: NSObject, MFMessageComposeViewControllerDelegate {
    nonisolated func messageComposeViewController(
        _ controller: MFMessageComposeViewController,
        didFinishWith result: MessageComposeResult
    ) {
        Task { @MainActor in
            controller.dismiss(animated: true)
        }
    }
}

struct MessageComposerView: UIViewControllerRepresentable {
    let recipients: [String]
    let messageBody: String
    let delegate: MessageComposeDelegate

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.messageComposeDelegate = delegate
        controller.recipients = recipients
        controller.body = messageBody
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    static func canSendText() -> Bool {
        MFMessageComposeViewController.canSendText()
    }
}