#!/usr/bin/env bash
# Audit d'une image Docker : enregistre chaque résultat dans le dossier audit/
# Usage : ./audit.sh quiz-docker:initial
set -u

IMAGE="${1:-quiz-docker:initial}"
OUT="audit"
mkdir -p "$OUT"

echo "== 03. Image de base ==" | tee "$OUT/03-image-base.txt"
grep -i '^FROM' Dockerfile.initial | tee -a "$OUT/03-image-base.txt"
docker run --rm "$IMAGE" cat /etc/os-release | tee -a "$OUT/03-image-base.txt"
docker run --rm "$IMAGE" node --version | tee -a "$OUT/03-image-base.txt"

echo "== 04. Utilisateur du processus ==" | tee "$OUT/04-utilisateur.txt"
docker run --rm "$IMAGE" id | tee -a "$OUT/04-utilisateur.txt"
docker inspect -f 'User={{.Config.User}}' "$IMAGE" | tee -a "$OUT/04-utilisateur.txt"

echo "== 05. Taille ==" | tee "$OUT/05-taille.txt"
docker images "$IMAGE" | tee -a "$OUT/05-taille.txt"
docker image inspect "$IMAGE" --format '{{.Size}}' \
  | awk '{printf "%.1f Mo\n", $1/1000000}' | tee -a "$OUT/05-taille.txt"

echo "== 06. Couches ==" | tee "$OUT/06-couches.txt"
docker history "$IMAGE" | tee -a "$OUT/06-couches.txt"
docker history --no-trunc --format "table {{.CreatedBy}}\t{{.Size}}" "$IMAGE" \
  > "$OUT/06-couches-detail.txt"

echo "== 07. Vulnérabilités (Docker Scout) ==" | tee "$OUT/07-scout-resume.txt"
docker scout quickview "$IMAGE" | tee -a "$OUT/07-scout-resume.txt"
docker scout cves "$IMAGE" > "$OUT/07-scout-cves.txt"

echo
echo "Résultats enregistrés dans le dossier $OUT/"
