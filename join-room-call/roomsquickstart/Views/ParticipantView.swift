//
//  ParticipantView.swift
//  roomsquickstart
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT license.

import SwiftUI
import AzureCommunicationCalling
import Combine

struct ParticipantView : View, Hashable {
    static func == (lhs: ParticipantView, rhs: ParticipantView) -> Bool {
        return lhs.participant.getMri() == rhs.participant.getMri()
    }

    private let owner: HomePageView

    @State var showPopUp: Bool = false
    @State var videoHeight = CGFloat(200)
    @ObservedObject private var participant:Participant

    var body: some View {
        ZStack {
            if (participant.rendererView != nil) {
                HStack {
                    RenderInboundVideoView(view: $participant.rendererView)
                }
                .background(Color(.black))
                .frame(height: videoHeight)
                .animation(Animation.default)
            } else {
                HStack {
                    Text("No incoming video")
                }
                .background(Color(.red))
                .frame(height: videoHeight)
            }
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(participant.getMri())
    }

    init(_ owner: HomePageView, _ participant: Participant) {
        self.owner = owner
        self.participant = participant
    }

    func resizeVideo() {
        videoHeight = videoHeight == 200 ? 150 : 200
    }

    func showAlert(_ title: String, _ message: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.owner.alertMessage = message
            self.owner.showAlert = true
        }
    }
}

struct RenderInboundVideoView: UIViewRepresentable {
    @Binding var view:RendererView!

    func makeUIView(context: Context) -> UIView {
        return UIView()
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        for view in uiView.subviews {
            view.removeFromSuperview()
        }
        if (view != nil) {
            uiView.addSubview(view)
        }
    }
}
