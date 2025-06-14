import AVFoundation

// Rozszerzenie klasy AVSpeechSynthesizer — umożliwia opóźnione wypowiadanie komunikatów (utterance) na głównym wątku
extension AVSpeechSynthesizer {

  // Funkcja do wypowiedzenia komunikatu po określonym czasie (w sekundach)
  // - Parameters:
  //   - utterance: Obiekt AVSpeechUtterance, który ma zostać wypowiedziany
  //   - after: Opóźnienie (w sekundach), po którym ma nastąpić mowa
  func speak(_ utterance: AVSpeechUtterance, after: Double) {
    // Wykonaj na głównym wątku z opóźnieniem
    DispatchQueue.main.asyncAfter(deadline: .now() + after) { [weak self] in
      guard let self = self else { return }
      self.speak(utterance)
    }
  }
}
