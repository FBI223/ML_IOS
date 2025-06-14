import UIKit
import AVFoundation
import AVKit

// Ten widok służy do pokazywania użytkownikowi wideo-instrukcji, jak wykonywać poszczególne gesty
class InstructionsViewController: UIViewController {

  // Odtwarzacz multimedialny AVFoundation — wykorzystywany do odtwarzania plików .mov z pakietu aplikacji
  var avPlayer: AVPlayer!

  // Wywoływane po załadowaniu widoku do pamięci — tutaj nie ma dodatkowej konfiguracji
  override func viewDidLoad() {
    super.viewDidLoad()
    // Zwykle można tu dodać np. preload filmów lub styl UI
  }

  // Akcja wywoływana po naciśnięciu przycisku "X" lub "Zamknij" — zamyka ekran instrukcji
  @IBAction func dismiss() {
    // Zamknięcie widoku modalnego z animacją
    dismiss(animated: true, completion: nil)
  }

  // Akcja przypisana do przycisku demonstracyjnego dla gestu "Chop It"
  @IBAction func demoChopIt() {
    // Odtwarza plik chop_it_demo.mov z zasobów aplikacji
    showVideo(filename: "chop_it_demo")
  }

  // Akcja przypisana do przycisku demonstracyjnego dla gestu "Drive It"
  @IBAction func demoDriveIt() {
    // Odtwarza plik drive_it_demo.mov z zasobów aplikacji
    showVideo(filename: "drive_it_demo")
  }

  // Akcja przypisana do przycisku demonstracyjnego dla gestu "Shake It"
  @IBAction func demoShakeIt() {
    // Odtwarza plik shake_it_demo.mov z zasobów aplikacji
    showVideo(filename: "shake_it_demo")
  }

  // Funkcja pomocnicza do odtwarzania wideo z lokalnego pliku w pakiecie aplikacji
  func showVideo(filename: String) {
    // Szuka ścieżki do pliku .mov w głównym bundle aplikacji (czyli zasobach wgranych do appki)
    let filepath: String? = Bundle.main.path(forResource: filename, ofType: "mov")

    // Tworzy URL ze ścieżki
    let url = URL(fileURLWithPath: filepath!)

    // Inicjalizuje odtwarzacz AVPlayer z wideo znajdującym się pod tym URL
    let player = AVPlayer(url: url)

    // Tworzy kontroler do prezentacji wideo w stylu natywnym (AVPlayerViewController)
    let controller = AVPlayerViewController()
    controller.player = player

    // Prezentuje kontroler modalnie (czyli wysuwa ekran z odtwarzaczem)
    // Po zakończeniu animacji wywołuje `player.play()` aby zacząć odtwarzanie automatycznie
    present(controller, animated: true) {
      player.play()
    }
  }
}

