

import UIKit
import AVFoundation
import AVKit

class InstructionsViewController: UIViewController {
  var avPlayer: AVPlayer!

  override func viewDidLoad() {
    super.viewDidLoad()
  }
  
  @IBAction func dismiss() {
    dismiss(animated: true, completion: nil)
  }
  
  @IBAction func demoChopIt() {
    showVideo(filename: "chop_it_demo")
  }

  @IBAction func demoDriveIt() {
    showVideo(filename: "drive_it_demo")
  }

  @IBAction func demoShakeIt() {
    showVideo(filename: "shake_it_demo")
  }

  func showVideo(filename: String) {
    let filepath: String? = Bundle.main.path(forResource: filename, ofType: "mov")
    let url = URL.init(fileURLWithPath: filepath!)
    let player = AVPlayer(url: url)
    
    let controller = AVPlayerViewController()
    controller.player = player
    
    // Modally present the player and play the video when complete.
    present(controller, animated: true) {
      player.play()
    }
  }
}
