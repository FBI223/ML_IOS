import UIKit

extension UIImage {
  
  // Konwertuje obraz UIImage do tablicy bajtów w formacie RGBA (każdy piksel = 4 bajty).
  // - Returns: Tablica bajtów zawierająca dane obrazu (RGBA).
  @nonobjc public func toByteArray() -> [UInt8] {
    let width = Int(size.width)
    let height = Int(size.height)
    
    // Alokacja bufora na piksele: szerokość * wysokość * 4 kanały (R, G, B, A)
    var bytes = [UInt8](repeating: 0, count: width * height * 4)

    bytes.withUnsafeMutableBytes { ptr in
      // Tworzymy kontekst graficzny, który rysuje obraz do naszego bufora
      if let context = CGContext(
        data: ptr.baseAddress,
        width: width,
        height: height,
        bitsPerComponent: 8,                // 8 bitów na komponent (R, G, B, A)
        bytesPerRow: width * 4,             // 4 bajty na piksel
        space: CGColorSpaceCreateDeviceRGB(), // RGB kolor
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue // kolejność RGBA
      ) {
        if let image = self.cgImage {
          let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
          context.draw(image, in: rect) // renderowanie UIImage do bufora
        }
      }
    }

    return bytes
  }

  // Tworzy nowy obiekt UIImage z tablicy bajtów RGBA.
  // - Parameters:
  //   - bytes: Wskaźnik do surowych danych bajtowych (RGBA).
  //   - width: Szerokość obrazu.
  //   - height: Wysokość obrazu.
  // - Returns: UIImage zrekonstruowany z danych bajtowych.
  @nonobjc public class func fromByteArray(_ bytes: UnsafeMutableRawPointer,
                                           width: Int,
                                           height: Int) -> UIImage {
    // Tworzymy kontekst graficzny z danych wejściowych
    if let context = CGContext(
      data: bytes,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: width * 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
       
       let cgImage = context.makeImage() {
      // Tworzymy UIImage z CGImage
      return UIImage(cgImage: cgImage, scale: 0, orientation: .up)
    } else {
      // Zwraca pusty obraz, jeśli kontekst nie został utworzony
      return UIImage()
    }
  }

  // Zmienia rozmiar obrazu do określonego rozmiaru `newSize`.
  // - Parameter newSize: Nowy rozmiar (szerokość i wysokość).
  // - Returns: Przeskalowany obraz `UIImage`.
  @nonobjc public func resized(to newSize: CGSize) -> UIImage {
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1 // Nie używamy skali ekranu (np. Retina), tylko 1:1
    let renderer = UIGraphicsImageRenderer(size: newSize, format: format)

    // Renderujemy nowy obraz o podanym rozmiarze
    let image = renderer.image { _ in
      draw(in: CGRect(origin: .zero, size: newSize))
    }
    return image
  }
}

