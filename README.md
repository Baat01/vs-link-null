# Vs. Link (Pokémon Null Edition)

*Vs. Link is a universal emulator script intermediary for client applications interacting with Pokémon games.*

> **Credits:** This project is heavily based on the original [Vs. Link by emi (emilyploszaj)](https://github.com/emilyploszaj/vs-link/commits?author=emilyploszaj). My own work on this fork is minimal compared to the incredible foundation she built. All credit for the core engine and original design goes entirely to her!

This fork/adaptation of Vs. Link is specifically tailored for **Pokémon Null**, a ROM hack with unique mechanics (e.g., no EVs, dynamic PC level calculation) and frequent version updates (e.g., v1.2.4, v1.2.5).

The script exposes an HTTP JSON API and handles reading internal game data directly from mGBA memory, parsing varying formats, and presenting it in a consistent JSON format. Client applications (programs, websites, OBS overlays) require no additional libraries to interact with Vs. Link.

## Key Features

*   **Declarative Profile System**: Easily support new patches and versions of Pokémon Null without changing the core code. Addresses and CRCs are managed in `src/engine/profiles.lua`.
*   **Auto-Detection**: Dynamically switches to the correct memory addresses based on the ROM's CRC detected by mGBA.
*   **Custom Game Logic**: Handles specific Pokémon Null data structures (such as +4 byte shifts in expansion memory) and calculates PC levels dynamically using species experience curves. Removes EVs from exported data.
*   **User Script Auto-Loader**: Drop custom `.lua` scripts into the `scripts/` folder at the root of the project, and they will be automatically loaded and executed securely at startup.
*   **Clean Logging**: All logs and errors are cleanly routed to a dedicated "Vs. Link" tab in the mGBA console.

## Use Cases
Applications can interact with Vs. Link using only localhost HTTP requests (port 31123).
Common existing or hypothetical use cases:
*   Stream party/badge display overlay
*   Party status tracking programs
*   Recent catch trackers
*   Integrations with more complex server applications

## Project Structure
*   `src/`: Contains all the core engine code for interacting with Pokémon games, parsing data, and serving HTTP endpoints.
    *   `src/engine/profiles.lua`: Where game version and patch addresses are registered.
*   `malachite/`: An emulator Lua library handling networking (HTTP server) and utilities.
*   `scripts/`: A directory for user-provided `.lua` scripts. Files placed here are auto-loaded when `vs.lua` runs.
*   `example/`: Examples for integration with Vs. Link (e.g., HTML/JS web pages to test the API).

## How to Add a New Patch (e.g., v1.2.5)
When a new version of Pokémon Null is released:
1. Open the new ROM in mGBA and run `vs.lua`.
2. Open `example/debug.html` to see the new **CRC** of the ROM.
3. Open `src/engine/profiles.lua`.
4. Add a new profile block with the new CRC and the updated RAM addresses from the `.map` file.
5. Reload the script. The engine will handle the rest!

---

# Vs. Link (Édition Pokémon Null)

*Vs. Link est un script intermédiaire universel d'émulateur destiné aux applications clientes interagissant avec les jeux Pokémon.*

> **Crédits :** Ce projet est largement basé sur le projet initial [Vs. Link créé par emi (emilyploszaj)](https://github.com/emilyploszaj/vs-link/commits?author=emilyploszaj). Mon propre travail sur cette adaptation n'est que minime par rapport à l'incroyable base qu'elle a développée. Tout le crédit pour le moteur principal et la conception originale lui revient entièrement !

Cette adaptation de Vs. Link a été spécialement conçue pour **Pokémon Null**, une ROM hack avec des mécaniques uniques (ex: pas d'EVs, calcul dynamique du niveau dans le PC) et des mises à jour régulières (ex: v1.2.4, v1.2.5).

Le script expose une API HTTP JSON et se charge de lire les données internes du jeu directement depuis la mémoire de mGBA, d'analyser les différents formats et de les présenter de manière standardisée en JSON. Les applications clientes (programmes, sites web, overlays OBS) ne nécessitent aucune bibliothèque supplémentaire pour interagir avec Vs. Link.

## Fonctionnalités Principales

*   **Système de Profils Déclaratifs** : Supportez facilement les nouveaux patchs et versions de Pokémon Null sans modifier le code central. Les adresses mémoire et les CRCs sont gérés dans `src/engine/profiles.lua`.
*   **Détection Automatique** : Bascule dynamiquement sur les bonnes adresses mémoire en fonction du CRC de la ROM détecté par mGBA.
*   **Logique de Jeu Personnalisée** : Gère les structures de données spécifiques à Pokémon Null (comme les décalages de +4 octets dans la mémoire d'expansion) et calcule dynamiquement le niveau des Pokémon du PC à partir des courbes d'expérience. Les EVs sont exclus des données exportées.
*   **Chargement Automatique de Scripts** : Déposez vos scripts `.lua` personnalisés dans le dossier `scripts/` à la racine du projet, ils seront automatiquement chargés et exécutés de manière sécurisée au démarrage.
*   **Journalisation Propre (Logs)** : Tous les journaux et erreurs sont redirigés proprement vers un onglet dédié "Vs. Link" dans la console mGBA.

## Cas d'Utilisation
Les applications peuvent interagir avec Vs. Link en effectuant simplement des requêtes HTTP en localhost (port 31123).
Cas d'utilisation courants (existants ou hypothétiques) :
*   Overlay de stream pour afficher l'équipe ou les badges
*   Programmes de suivi du statut de l'équipe
*   Suivi des captures récentes
*   Intégrations avec des applications serveur plus complexes

## Structure du Projet
*   `src/` : Contient tout le code moteur de base pour interagir avec les jeux Pokémon, analyser les données et gérer les requêtes HTTP.
    *   `src/engine/profiles.lua` : Fichier où sont enregistrés les versions du jeu et les adresses mémoire.
*   `malachite/` : Une bibliothèque Lua pour émulateur gérant le réseau (serveur HTTP) et les utilitaires.
*   `scripts/` : Un dossier destiné aux scripts `.lua` fournis par l'utilisateur. Les fichiers placés ici sont chargés automatiquement lors du lancement de `vs.lua`.
*   `example/` : Exemples d'intégration avec Vs. Link (ex: pages web HTML/JS pour tester l'API).

## Comment Ajouter un Nouveau Patch (ex: v1.2.5)
Lorsqu'une nouvelle version de Pokémon Null sort :
1. Ouvrez la nouvelle ROM dans mGBA et lancez `vs.lua`.
2. Ouvrez `example/debug.html` pour voir le nouveau **CRC** de la ROM.
3. Ouvrez le fichier `src/engine/profiles.lua`.
4. Ajoutez un nouveau bloc de profil avec le nouveau CRC et les adresses RAM mises à jour (issues du fichier `.map`).
5. Relancez le script. Le moteur s'occupe du reste !
