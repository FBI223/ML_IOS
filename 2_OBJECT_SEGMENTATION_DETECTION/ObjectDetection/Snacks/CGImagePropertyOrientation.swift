import UIKit

// 🔁 Rozszerzenie CGImagePropertyOrientation o inicjalizator z UIImage.Orientation
extension CGImagePropertyOrientation {
  init(_ orientation: UIImage.Orientation) {
    switch orientation {
    case .upMirrored:
      self = .upMirrored // obraz lustrzany "do góry"
    case .down:
      self = .down       // obrócony do dołu
    case .downMirrored:
      self = .downMirrored
    case .left:
      self = .left       // obrócony w lewo (90°)
    case .leftMirrored:
      self = .leftMirrored
    case .right:
      self = .right      // obrócony w prawo (270°)
    case .rightMirrored:
      self = .rightMirrored
    default:
      self = .up         // domyślnie: orientacja "do góry"
    }
  }
}

// 🔁 Drugie rozszerzenie: inicjalizator z UIDeviceOrientation (fizyczna orientacja urządzenia)
extension CGImagePropertyOrientation {
  init(_ orientation: UIDeviceOrientation) {
    switch orientation {
    case .portraitUpsideDown:
      self = .left       // w pionie do góry nogami (kamera frontowa = lewo)
    case .landscapeLeft:
      self = .up         // krajobraz w lewo (urządzenie trzymane poziomo, prawa strona w górę)
    case .landscapeRight:
      self = .down       // krajobraz w prawo (lewa strona w górę)
    default:
      self = .right      // domyślnie: portret (kamera tylna = prawo)
    }
  }
}

