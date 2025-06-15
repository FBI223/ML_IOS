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

# 5. Lista cech do wykresów
features = ["roll", "pitch", "yaw",
            "rotX", "rotY", "rotZ",
            "accX", "accY", "accZ",
            "gravX", "gravY", "gravZ"]

# 6. Tworzenie subplots
fig, axes = plt.subplots(nrows=4, ncols=3, figsize=(18, 10))
axes = axes.flatten()

for i, feature in enumerate(features):
    axes[i].plot(df[feature].values[:1000], label=feature, color="tab:blue")
    axes[i].set_title(feature)
    axes[i].set_xlabel("Próbka")
    axes[i].set_ylabel("Wartość")
    axes[i].grid(True)

plt.suptitle(f"Wykresy cech ruchu (pierwsze 1000 próbek)\n{os.path.basename(csv_path)}", fontsize=16)
plt.tight_layout(rect=[0, 0, 1, 0.95])
plt.show()

