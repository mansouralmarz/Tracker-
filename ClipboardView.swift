import SwiftUI

struct ClipboardView: View {
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "doc.on.clipboard")
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                    .font(.system(size: 48))
                
                Text("Clipboard")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Notes are in the sidebar")
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
                
                Text("Select a note from the sidebar to edit it here.")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

#Preview {
    ClipboardView()
}
