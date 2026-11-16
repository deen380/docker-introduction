# Audit Docker du quiz : état initial et améliorations

Ce dépôt contient l'audit de l'image Docker d'une application de quiz (projet Vite) et une version améliorée du Dockerfile.

> Les valeurs entre crochets `[à compléter]` sont à remplacer par les résultats réels de ton audit (commandes en fin de document). La version améliorée n'a pas encore été testée : à construire, lancer et scanner avant de conclure.

## Contenu du dépôt

| Fichier | Rôle |
|---|---|
| `Dockerfile.initial` | Dockerfile audité (image `quiz-docker:initial`) |
| `Dockerfile.optimise` | Dockerfile amélioré (build multi-étapes, utilisateur non root) |
| `.dockerignore` | Fichiers exclus du contexte de build |
| `audit.sh` | Script qui collecte les résultats de l'audit |
| `audit/` | Résultats enregistrés (taille, couches, vulnérabilités...) |

## 1. État initial de l'image

Image : `quiz-docker:initial`

| Élément audité | Constat | Risque identifié | Gravité | Recommandation |
|---|---|---|---|---|
| Image de base | `node:18-alpine` | Version Node 18 en fin de vie (plus de correctifs de sécurité, à vérifier sur nodejs.org) | Haute | Version Node maintenue, tag précis |
| Utilisateur du processus | `root` (aucune instruction `USER`) ; résultat réel : `[à compléter : docker run --rm quiz-docker:initial id]` | Une faille dans l'application donne les droits maximums dans le conteneur | Haute | Utilisateur non privilégié |
| Taille de l'image | `[à compléter : docker images quiz-docker:initial]` | Surface d'attaque élargie, déploiement plus lent | Moyenne | Build multi-étapes avec nginx |
| Couches | Couche `RUN npm install ... build` la plus lourde `[à compléter : docker history]` | Outils de build (Node, npm, Vite, sources) conservés dans l'image finale | Moyenne | Séparer construction et exécution |
| Serveur applicatif | `serve` (Node) sur le port 3000 | Surface plus large qu'un serveur statique dédié | Moyenne | nginx non privilégié |
| Contenu copié | `COPY . .` sans `.dockerignore` | Risque d'embarquer des fichiers sensibles (`.env`, `.git`, archives) | Moyenne | Ajouter `.dockerignore` |
| Reproductibilité | `serve` installé sans version fixée, tag `18-alpine` mutable, `npm install` | Builds différents d'un jour à l'autre | Moyenne | `npm ci`, versions et digest figés |
| Surveillance | Pas de `HEALTHCHECK` | Panne de l'application non détectée | Basse | Ajouter un healthcheck |
| Vulnérabilités | `[à compléter : nombre CRITICAL / HIGH / MEDIUM / LOW]` (Docker Scout ou Trivy) | Failles connues exploitables | À évaluer | Mettre à jour la base, rescanner |

## 2. Analyse

### L'image est-elle adaptée à une utilisation en production ?

Non, pour ces raisons :

- l'image de base (Node 18) n'est plus maintenue ;
- le processus tourne en root ;
- l'image embarque Node, npm et le code source alors qu'elle sert seulement un site statique ;
- les versions ne sont pas figées, donc le build n'est pas reproductible.

### Quels composants sont réellement nécessaires ?

Une fois construit, le quiz est un **site statique** : le dossier `dist` (HTML, JavaScript, CSS, images). Il faut seulement ces fichiers et un serveur web léger pour les envoyer. Node, npm, Vite, le code source, `package.json`, le README et le Dockerfile ne servent que pendant la construction.

### Quels risques de sécurité ?

1. Exécution en root.
2. Image de base obsolète, avec des vulnérabilités connues sans correctif.
3. Surface d'attaque large (Node, npm, shell, outils inutiles à l'exécution).
4. Chaîne d'approvisionnement non maîtrisée (versions non figées).
5. Fuite possible de fichiers via `COPY . .`.
6. Aucune détection de panne.

### Améliorations recommandées, par priorité

1. **Ne plus exécuter en root** : utiliser une image dont le processus est non privilégié.
2. **Changer d'image de base** pour une version Node maintenue pour la construction.
3. **Build multi-étapes** : construire avec Node, puis ne conserver que `dist` dans une image nginx. C'est le plus gros gain en taille et en surface d'attaque.
4. **Ajouter un `.dockerignore`** pour exclure `node_modules`, `.git`, `.env`, archives.
5. **Figer les versions** (tag précis, idéalement digest) et utiliser `npm ci` avec le fichier `package-lock.json`.
6. **Ajouter un `HEALTHCHECK`.**
7. **Rescanner** l'image améliorée et comparer avec l'état initial.

## 3. Version améliorée (`Dockerfile.optimise`)

| Changement | Effet |
|---|---|
| `FROM node:22-alpine AS build` | Version Node maintenue, utilisée uniquement pour construire |
| `npm ci` au lieu de `npm install` | Installation reproductible depuis `package-lock.json` |
| Deuxième étape `nginxinc/nginx-unprivileged:alpine` | Plus de Node dans l'image finale ; nginx tourne avec un utilisateur non root |
| `COPY --from=build /app/dist ...` | Seul le site construit est conservé |
| `EXPOSE 8080` | Port non privilégié, requis pour un processus non root |
| `HEALTHCHECK` | Docker sait si le site répond |

Construction et lancement (le site répond sur le port 8080 du conteneur) :

```bash
docker build -f Dockerfile.optimise -t quiz-docker:optimise .
docker run -d --name quiz-optimise -p 8089:8080 quiz-docker:optimise
```

Ouvrir ensuite http://localhost:8089.

Si la construction échoue à cause d'une version de Node, adapter la version de la première ligne à celle demandée par `package.json` (champ `engines`).

## 4. Comparaison avant / après

À remplir après les mesures.

| Critère | `quiz-docker:initial` | `quiz-docker:optimise` |
|---|---|---|
| Image de base | `node:18-alpine` | `nginxinc/nginx-unprivileged:alpine` (étape finale) |
| Utilisateur | root | `[à compléter]` (attendu : non root) |
| Taille | `[à compléter]` | `[à compléter]` |
| Vulnérabilités CRITICAL / HIGH | `[à compléter]` | `[à compléter]` |
| Outils de build dans l'image finale | oui | non |
| Healthcheck | non | oui |

## 5. Reproduire l'audit

Depuis le dossier du projet (celui qui contient `package.json`) :

```bash
docker build -f Dockerfile.initial -t quiz-docker:initial .
docker run -d --name quiz-initial -p 8088:3000 quiz-docker:initial
curl -I http://localhost:8088
./audit.sh quiz-docker:initial
```

Les résultats sont enregistrés dans `audit/`. Pour une analyse avec Trivy :

```bash
docker save quiz-docker:initial -o quiz-initial.tar
docker run --rm -v "$PWD":/work aquasec/trivy image --input /work/quiz-initial.tar --format table --output /work/audit/07-trivy.txt
```

Ne pas publier l'archive `quiz-initial.tar` (déjà exclue par `.gitignore` et `.dockerignore`).
