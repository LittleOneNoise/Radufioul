<p align="center">
  <img src="assets/logo_radufioul.png" width="340" alt="Radufioul">
</p>

<h1 align="center">Radufioul</h1>

<p align="center">
  <em>Radufioul (rat du fuel) permet de trouver la meilleure affaire pour faire son plein de carburant sans devoir hypothéquer sa maison. On vit dans une époque de fou quand-même...</em>
</p>

---

## Ce que ça fait

Toutes les x minutes, Radufioul interroge le flux officiel des prix des carburants,
ne garde que les stations dans un rayon autour de chez toi, et t'envoie une
notification sur téléphone via [ntfy](https://ntfy.sh) quand un carburant passe sous ton prix plancher.

Un fichier d'état évite de te renotifier en boucle : tu es prévenu **une fois**
quand une station passe sous le seuil, puis seulement si elle baisse encore.
Une station qui remonte au-dessus du seuil est oubliée, et redéclenchera si elle
redescend.

La notification contient le prix, le carburant, l'adresse, la date du relevé,
et un lien qui ouvre directement la station dans Google Maps.

## D'où viennent les données

Du jeu de données ouvert **« Prix des carburants en France — Flux instantané v2 »**,
publié par les ministères économiques et financiers sur
[data.economie.gouv.fr](https://data.economie.gouv.fr/explore/dataset/prix-des-carburants-en-france-flux-instantane-v2/),
exposé via l'API Opendatasoft Explore v2.1. Licence Ouverte / Open Licence.

Ce sont les prix déclarés par les stations elles-mêmes en application de
l'arrêté du 12 décembre 2006, remontés au site officiel
[prix-carburants.gouv.fr](https://www.prix-carburants.gouv.fr/). Quelques
conséquences pratiques :

- Le flux est rafraîchi toutes les 10 minutes — inutile de sonder plus souvent.
- Un prix peut dater de plusieurs jours. `MAX_AGE_DAYS` écarte les relevés trop vieux.
- La donnée est déclarative : un écart avec l'affichage à la pompe est possible.
- Une station peut afficher un prix et être fermée, ou en rupture.

Aucune clé d'API, aucun compte, aucun quota.

## Variables d'environnement

Aucune valeur n'est committée. Tout se configure à l'extérieur du dépôt.

| Variable | Requis | Défaut | Description |
|---|---|---|---|
| `NTFY_URL` | ✅ | — | URL complète du topic, ex. `https://ntfy.sh/mon-topic-secret-x7f2q` |
| `LAT` | ✅ | — | Latitude du point de référence, en degrés décimaux |
| `LON` | ✅ | — | Longitude du point de référence (négative à l'ouest de Greenwich) |
| `RADIUS_KM` | | `10` | Rayon de recherche en kilomètres |
| `FUELS` | | `e10,sp95` | Carburants surveillés, séparés par des virgules. Valeurs possibles : `gazole`, `sp95`, `sp98`, `e10`, `e85`, `gplc` |
| `THRESHOLD` | | `2.00` | Prix plancher en euros. Une notif part dès qu'un prix passe strictement en dessous |
| `MAX_AGE_DAYS` | | `3` | Âge maximum d'un relevé pour être pris en compte |
| `INTERVAL` | | `1800` | Secondes entre deux vérifications |
| `TZ` | | `Europe/Paris` | Fuseau, pour l'horodatage des logs |
| `STATE` | | `/data/state.json` | Chemin du fichier d'état anti-spam |

## Licence

MIT