import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var markdownExportChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "ilovebioconjugation/markdown_export",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "save" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
        let path = arguments["path"] as? String,
        let contents = arguments["contents"] as? String,
        path.hasPrefix("/"),
        URL(fileURLWithPath: path).pathExtension.lowercased() == "md"
      else {
        result(FlutterError(code: "invalid_export", message: "请选择有效的 Markdown 文件。", details: nil))
        return
      }
      do {
        try MainFlutterWindow.saveMarkdown(contents, to: URL(fileURLWithPath: path))
        result(nil)
      } catch {
        result(FlutterError(code: "export_failed", message: error.localizedDescription, details: nil))
      }
    }
    markdownExportChannel = channel

    super.awakeFromNib()
  }

  /// Do not create an arbitrary sibling directory beside a user-selected file:
  /// that sibling is outside the save panel's sandbox grant. Foundation chooses
  /// an accessible replacement directory on the destination volume instead.
  private static func saveMarkdown(_ contents: String, to destination: URL) throws {
    let scoped = destination.startAccessingSecurityScopedResource()
    defer { if scoped { destination.stopAccessingSecurityScopedResource() } }
    let manager = FileManager.default
    var coordinationError: NSError?
    var writeError: Error?
    let options: NSFileCoordinator.WritingOptions =
      manager.fileExists(atPath: destination.path) ? .forReplacing : []
    NSFileCoordinator().coordinate(writingItemAt: destination, options: options,
                                   error: &coordinationError) { selectedURL in
      do {
        var isDirectory: ObjCBool = false
        if manager.fileExists(atPath: selectedURL.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
          throw NSError(domain: "MarkdownExport", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "请选择文件，而不是文件夹。"])
        }
        let directory = try manager.url(for: .itemReplacementDirectory,
                                        in: .userDomainMask,
                                        appropriateFor: selectedURL, create: true)
        defer { try? manager.removeItem(at: directory) }
        let staged = directory.appendingPathComponent("record.md")
        try Data(contents.utf8).write(to: staged, options: .atomic)
        if manager.fileExists(atPath: selectedURL.path) {
          _ = try manager.replaceItemAt(selectedURL, withItemAt: staged,
                                        backupItemName: nil, options: [])
        } else {
          try manager.moveItem(at: staged, to: selectedURL)
        }
      } catch {
        writeError = error
      }
    }
    if let error = coordinationError { throw error }
    if let error = writeError { throw error }
  }
}
