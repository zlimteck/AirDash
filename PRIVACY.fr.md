# Politique de confidentialité

**Dernière mise à jour : 4 septembre 2026**

AirDash est une application indépendante et non-officielle pour [AirVPN](https://airvpn.org). Elle n'a aucune affiliation avec AirVPN, et aucun système de compte ou backend propre au-delà de ce qui est décrit ci-dessous. Cette politique explique en détail quelles données AirDash accède, stocke et transmet, et où.

## Les données que vous fournissez

AirDash nécessite votre clé API personnelle AirVPN (depuis votre compte AirVPN, *Espace Client → API*) pour fonctionner. Cette clé est :

- Stockée uniquement dans le Trousseau (Keychain) iOS, sur votre appareil
- Jamais transmise ailleurs qu'à l'API d'AirVPN elle-même (`airvpn.org`), pour récupérer vos données de compte et de serveurs
- Jamais envoyée au développeur de l'app ni à un tiers quelconque

Si vous utilisez Face ID / Touch ID pour verrouiller l'app, les données biométriques sont entièrement gérées par iOS et ne quittent jamais votre appareil ni n'atteignent AirDash lui-même.

## Ce qu'AirDash stocke sur votre appareil

- **Dans le Trousseau iOS** (chiffré, réservé à l'app sauf mention contraire) : votre/vos compte(s) AirVPN et clé(s) API ; votre historique de profils VPN générés, y compris les clés privées WireGuard et les identifiants OpenVPN, pour pouvoir réimporter un profil déjà généré sans avoir à le regénérer.
- **Dans `UserDefaults` local** (cet appareil uniquement, jamais synchronisé ni transmis) : préférences de l'app comme le thème, l'icône, l'ordre de tri, les serveurs favoris (par compte), le dernier appareil choisi lors d'une génération de profil, et les réglages activables (verrouillage biométrique, la fonctionnalité d'historique optionnelle décrite plus bas).
- **Dans un App Group iOS partagé** (`group.com.airdash.ios`, lisible uniquement par AirDash et son propre widget d'écran d'accueil, ne quitte jamais votre appareil) : votre IP publique actuelle, si une session VPN semble active, votre identifiant AirVPN et la date d'expiration de votre abonnement, une courte liste de vos sessions actives (nom du serveur, pays, durée), votre serveur favori/meilleur serveur, et des caches de noms de serveurs et d'appareils. Ceci existe uniquement pour que le widget et les raccourcis Siri puissent afficher des informations utiles et résoudre leurs paramètres sans faire leur propre appel réseau ; rien de tout cela ne quitte l'appareil.
- **Fichiers temporaires** : quand vous appuyez sur Partager ou Importer sur un profil généré, AirDash écrit brièvement ce profil (clé privée incluse, pour WireGuard) dans le dossier temporaire de l'app, uniquement le temps de cette action, et le supprime immédiatement après ; l'app nettoie aussi tout fichier de ce type resté d'une session précédente interrompue, au lancement suivant. En dehors de cette brève fenêtre, aucune copie en clair de votre profil n'existe nulle part, à part l'entrée du Trousseau mentionnée ci-dessus.
- **Connexions VPN natives** (version complète uniquement, pas la version Lite distribuée pour le sideload) : le tunnel WireGuard lui-même est géré par le framework `NetworkExtension` d'iOS. AirDash n'inspecte, ne journalise ni ne transmet votre trafic VPN ; il se contente de démarrer et arrêter le tunnel, et stocke la configuration du tunnel actuel dans le Trousseau (partagé entre l'app et son extension Packet Tunnel) pour que l'extension puisse la lire.

## Historique et tendances des serveurs (optionnel, désactivé par défaut)

Les graphiques d'historique de charge/utilisateurs, les heures creuses, les badges de fiabilité et l'écran Tendances sont **désactivés par défaut** et ne s'activent que si vous activez "Historique et tendances des serveurs" dans les Réglages.

Une fois activé, AirDash interroge en plus `airvpn-api.zmtk.fr`, un petit Worker Cloudflare géré séparément par le développeur, indépendamment d'AirVPN, pour afficher des données historiques que l'API d'AirVPN elle-même n'expose pas. Précisément :

- **Ce qu'il demande et stocke** : uniquement des métriques serveur publiques (charge, utilisateurs connectés, bande passante, santé) collectées périodiquement depuis le statut public d'AirVPN, les mêmes informations visibles par n'importe qui sur la page de statut d'AirVPN. Il ne reçoit jamais votre clé API, vos informations de compte, ni aucune autre donnée personnelle ; le code de l'application n'a aucun chemin qui le permettrait.
- **Ce qu'il voit inévitablement, comme n'importe quel serveur web** : l'adresse IP source de votre appareil et l'horodatage de la requête, simplement parce que ça fait partie du fonctionnement d'une requête HTTP. Ni le code de l'application ni la journalisation de Cloudflare au niveau plateforme ne conservent cette information : la journalisation par requête ("Workers Logs") est désactivée sur ce Worker, donc aucune adresse IP ni métadonnée de requête n'est stockée nulle part, même temporairement, au-delà du moment où la requête est traitée. Seuls les messages d'erreur explicitement journalisés par le code pour le débogage sont conservés, et ceux-ci n'incluent jamais de métadonnées de requête.
- **Code source** : le Worker est open source, disponible sur [github.com/zlimteck/airvpn-history-worker](https://github.com/zlimteck/airvpn-history-worker), pour que vous puissiez vérifier tout ce qui précède vous-même plutôt que de faire confiance à ce document sur parole.

Si vous préférez qu'aucune requête n'atteigne ce service, laissez simplement la fonctionnalité désactivée ; rien de ce qui précède n'est utilisé par une autre partie de l'app.

## Ce qu'AirDash ne fait pas

- Aucun SDK d'analytics, de crash reporting ou de publicité
- Aucun système de compte, d'inscription ou de tracking utilisateur
- Aucune donnée n'est vendue, partagée ou utilisée à des fins publicitaires

## Notifications

Les rappels d'expiration d'abonnement sont planifiés localement sur votre appareil via les notifications iOS. Aucun serveur de notification push n'est impliqué.

## Modifications de cette politique

Si cette politique change, la mise à jour sera reflétée ici avec une nouvelle date de "Dernière mise à jour".

## Contact

Questions ou remarques : ouvrez une issue sur le [dépôt GitHub](https://github.com/zlimteck/AirDash/issues).
