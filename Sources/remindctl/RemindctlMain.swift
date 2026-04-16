import Foundation

@main
enum RemindctlMain {
  static func main() async {
    let code = await CommandRouter().run()
    exit(code)
  }
}
