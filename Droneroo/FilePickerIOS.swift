//  Created by Erez Volk
#if os(iOS)
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct FilePickerIOS: UIViewControllerRepresentable {
    @Binding var fileURL: URL?
    let types: [UTType]

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: types)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: FilePickerIOS

        init(_ parent: FilePickerIOS) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.fileURL = urls.first
        }
    }
}
#endif
