import Foundation
import UIKit

// Klasa reprezentująca pojedynczy bounding box na ekranie
class BoundingBoxView {

  // Warstwa do rysowania prostokąta
  let shapeLayer: CAShapeLayer

  // Warstwa do wyświetlania etykiety (tekstu)
  let textLayer: CATextLayer

  // Inicjalizacja obu warstw
  init() {
    // Konfiguracja warstwy rysującej prostokąt
    shapeLayer = CAShapeLayer()
    shapeLayer.fillColor = UIColor.clear.cgColor      // bez wypełnienia
    shapeLayer.lineWidth = 4                          // grubość linii
    shapeLayer.isHidden = true                        // domyślnie ukryta

    // Konfiguracja warstwy tekstowej (nazwa klasy)
    textLayer = CATextLayer()
    textLayer.foregroundColor = UIColor.black.cgColor // kolor tekstu
    textLayer.isHidden = true                         // ukryta na start
    textLayer.contentsScale = UIScreen.main.scale     // skalowanie do retina
    textLayer.fontSize = 14
    textLayer.font = UIFont(name: "Avenir", size: textLayer.fontSize)
    textLayer.alignmentMode = .center                 // wyśrodkowanie tekstu
  }

  // Dodaje obie warstwy (box + tekst) do podanej warstwy nadrzędnej
  func addToLayer(_ parent: CALayer) {
    parent.addSublayer(shapeLayer)
    parent.addSublayer(textLayer)
  }

  // Pokazuje box i tekst na ekranie
  func show(frame: CGRect, label: String, color: UIColor) {
    // Wyłącza animacje zmian (np. alpha, pozycja)
    CATransaction.setDisableActions(true)

    // Tworzy ścieżkę prostokąta i przypisuje do warstwy
    let path = UIBezierPath(rect: frame)
    shapeLayer.path = path.cgPath
    shapeLayer.strokeColor = color.cgColor
    shapeLayer.isHidden = false

    // Ustawia tekst i kolor tła dla etykiety
    textLayer.string = label
    textLayer.backgroundColor = color.cgColor
    textLayer.isHidden = false

    // Oblicza rozmiar etykiety
    let attributes = [
      NSAttributedString.Key.font: textLayer.font as Any
    ]

    let textRect = label.boundingRect(
      with: CGSize(width: 400, height: 100),
      options: .truncatesLastVisibleLine,
      attributes: attributes,
      context: nil
    )

    let textSize = CGSize(width: textRect.width + 12, height: textRect.height)

    // Pozycja tekstu: nad lewym górnym rogiem bounding boxa
    let textOrigin = CGPoint(x: frame.origin.x - 2, y: frame.origin.y - textSize.height)

    // Ustawienie ramki warstwy tekstowej
    textLayer.frame = CGRect(origin: textOrigin, size: textSize)
  }

  // Ukrywa box i tekst
  func hide() {
    shapeLayer.isHidden = true
    textLayer.isHidden = true
  }
}

