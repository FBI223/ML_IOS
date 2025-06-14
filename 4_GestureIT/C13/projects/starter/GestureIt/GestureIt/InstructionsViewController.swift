import UIKit
import AVFoundation
import AVKit

// Kontroler widoku instrukcji — pokazuje filmy demonstracyjne dla każdego gestu
class InstructionsViewController: UIViewController {
  
  // Odtwarzacz wideo (AVPlayer) — przechowuje aktualnie odtwarzany film
  var avPlayer: AVPlayer!

  // Funkcja wywoływana po załadowaniu widoku — tutaj nic się nie dzieje
  override func viewDidLoad() {
    super.viewDidLoad()
  }
  
  // Funkcja zamykająca bieżący widok (np. instrukcji)
  @IBAction func dismiss() {
    dismiss(animated: true, completion: nil)
  }
  
  // Funkcja wywoływana po naciśnięciu przycisku "Demo Chop It"
  @IBAction func demoChopIt() {
    showVideo(filename: "chop_it_demo")
  }

  // Funkcja wywoływana po naciśnięciu przycisku "Demo Drive It"
  @IBAction func demoDriveIt() {
    showVideo(filename: "drive_it_demo")
  }

  // Funkcja wywoływana po naciśnięciu przycisku "Demo Shake It"
  @IBAction func demoShakeIt() {
    showVideo(filename: "shake_it_demo")
  }

  // Funkcja pomocnicza do odtwarzania filmu instruktażowego o podanej nazwie pliku
  func showVideo(filename: String) {
    // Znajdź ścieżkę do pliku w zasobach aplikacji
    let filepath: String? = Bundle.main.path(forResource: filename, ofType: "mov")
    
    // Utwórz URL i AVPlayer do tego pliku
    let url = URL(fileURLWithPath: filepath!)
    let player = AVPlayer(url: url)
    
    // Utwórz kontroler AVPlayerViewController, przypisz gracza
    let controller = AVPlayerViewController()
    controller.player = player
    
    // Zaprezentuj kontroler modally (pełnoekranowo) i rozpocznij odtwarzanie filmu
    present(controller, animated: true) {
      player.play()
    }
  }
}

