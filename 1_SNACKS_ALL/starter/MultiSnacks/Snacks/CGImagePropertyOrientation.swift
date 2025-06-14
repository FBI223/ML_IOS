
import UIKit

// Rozszerzenie umożliwiające konwersję typu UIImage.Orientation (używanego przez UIKit)
// do CGImagePropertyOrientation (używanego przez CoreML i Vision).
extension CGImagePropertyOrientation {
  init(_ orientation: UIImage.Orientation) {
    switch orientation {
    case .upMirrored: self = .upMirrored       // Lustrzane odbicie góra
    case .down: self = .down                   // Odwrócony do góry nogami
    case .downMirrored: self = .downMirrored   // Lustrzane odbicie do góry nogami
    case .left: self = .left                   // Obrót w lewo
    case .leftMirrored: self = .leftMirrored   // Lustrzane odbicie w lewo
    case .right: self = .right                 // Obrót w prawo
    case .rightMirrored: self = .rightMirrored // Lustrzane odbicie w prawo
    default: self = .up                        // Domyślnie "do góry"
    }
  }
}

// Drugie rozszerzenie konwertujące UIDeviceOrientation (czyli orientację urządzenia fizycznego)
// na CGImagePropertyOrientation (czyli orientację obrazu w Vision/CoreML).
extension CGImagePropertyOrientation {
  init(_ orientation: UIDeviceOrientation) {
    switch orientation {
    case .portraitUpsideDown: self = .left     // Telefon trzymany do góry nogami
    case .landscapeLeft: self = .up            // Tryb poziomy, telefon obracany w lewo
    case .landscapeRight: self = .down         // Tryb poziomy, telefon obracany w prawo
    default: self = .right                     // Domyślnie portret (standardowa orientacja)
    }
  }
}
