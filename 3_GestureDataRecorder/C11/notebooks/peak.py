import pandas as pd
import matplotlib.pyplot as plt
import os

# 1. Pobranie ścieżki od użytkownika
csv_path = input("Podaj ścieżkę do pliku CSV: ").strip()

# 2. Sprawdzenie, czy plik istnieje
if not os.path.isfile(csv_path):
    print("Błąd: Plik nie istnieje.")
    exit(1)

# 3. Wczytanie danych
df = pd.read_csv(csv_path, header=None)

# 4. Nazwy kolumn
df.columns = [
    "id", "label",
    "roll", "pitch", "yaw",
    "rotX", "rotY", "rotZ",
    "gravX", "gravY", "gravZ",
    "accX", "accY", "accZ"
]

# 5. Lista cech do wizualizacji
features = ["roll", "pitch", "yaw",
            "rotX", "rotY", "rotZ",
            "accX", "accY", "accZ",
            "gravX", "gravY", "gravZ"]

# 6. Normalizacja cech (Z-score)
df_norm = df.copy()
df_norm[features] = (df[features] - df[features].mean()) / df[features].std()

# 7. Rysowanie wykresu
plt.figure(figsize=(15, 8))
for feature in features:
    plt.plot(df_norm[feature].values[:2000], label=feature, alpha=0.8)

plt.title("Znormalizowane cechy ruchowe (pierwsze 1000 próbek)")
plt.xlabel("Numer próbki")
plt.ylabel("Z-score")
plt.grid(True)
plt.legend(ncol=3)
plt.tight_layout()
plt.show()
