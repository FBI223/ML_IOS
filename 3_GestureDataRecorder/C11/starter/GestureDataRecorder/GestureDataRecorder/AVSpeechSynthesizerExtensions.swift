import AVFoundation

// Rozszerzenie klasy AVSpeechSynthesizer (czytnik mowy),
// dodające funkcję umożliwiającą opóźnione wypowiadanie tekstu
extension AVSpeechSynthesizer {

  // Wypowiada `utterance` (czyli tekst do przeczytania przez system),
  // ale dopiero po określonym opóźnieniu (`after` sekund).
  //
  // - Parameters:
  //   - utterance: Obiekt typu `AVSpeechUtterance`, zawierający tekst i konfigurację mowy
  //   - after: Liczba sekund, o które należy opóźnić wypowiedź
  func speak(_ utterance: AVSpeechUtterance, after: Double) {
    // Wykonanie kodu po określonym czasie na głównym wątku UI
    DispatchQueue.main.asyncAfter(deadline: .now() + after) { [weak self] in
      // Zapobiega wyciekom pamięci — używa słabego odniesienia do self
      guard let self = self else { return }

      // Wywołuje standardową funkcję speak, aby wypowiedzieć tekst
      self.speak(utterance)
    }
  }
}
