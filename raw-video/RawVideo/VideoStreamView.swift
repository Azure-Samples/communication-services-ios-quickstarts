//
//  RemoteVideoStreamRenderer.swift
//  RawVideo
//
//  Created by Yassir Amadh Bisteni Aldana on 20/04/23.
//

import AzureCommunicationCalling
import Foundation
import SwiftUI

struct VideoStreamView : UIViewRepresentable
{
    @Binding var view: RendererView!

    func makeUIView(context: Context) -> UIView
    {
        return UIView()
    }

    func updateUIView(_ uiView: UIView, context: Context)
    {
        for view in uiView.subviews
        {
            view.removeFromSuperview()
        }
        
        if let view = view
        {
            uiView.addSubview(view)
        }
    }
}
