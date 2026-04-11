//
//  CardRow.swift
//  Focus
//
//  Created by Dan Berry on 4/11/26.
//

import SwiftUI

struct CardRow<Content: View>: View {
    
    @ViewBuilder let content: Content
    
    var body: some View {
        Section {
            content
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(in: RoundedRectangle(cornerRadius: 26))
        }
        .listRowSeparator(.hidden)
        .listSectionSpacing(18)
    }
    
}

#Preview {
    CardRow {
        LabeledContent { } label: {
            Text("Hello")
            Text("World")
        }
    }
}
