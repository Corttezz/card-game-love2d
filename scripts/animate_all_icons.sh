#!/bin/bash
# Anima todos os ícones do jogo com ações SUTIS via PixelLab.
# Roda sequencial; cada call ~30-40s. Total ~15min.

set -e

export IMG_GUIDANCE=5.0
export TEXT_GUIDANCE=3.5

cd "$(dirname "$0")/.."

# Formato: name|description|action
declare -a JOBS=(
    "sword_short|short iron sword with tarnished steel blade and gold crossguard|subtle golden light barely shimmering on the blade edge"
    "sword_great|ornate two-handed greatsword with silver blade|subtle golden light barely shimmering on the blade edge"
    "axe|dwarven battle axe with iron head and wooden handle|subtle metallic glint on the blade edge"
    "dagger|assassin curved dagger with steel blade|single tiny blood droplet slowly forming at the blade tip"
    "claw|three bestial demon claws on wooden base|tiny blood droplet slowly forming at claw tip"
    "fang|pair of vampire fangs|tiny blood droplet barely visible at fang tip"
    "shield_round|round wooden shield with iron boss|subtle metallic highlight barely shifting"
    "shield_kite|crusader kite shield with red cross|subtle metallic highlight barely shifting"
    "armor_plate|ornate steel breastplate|subtle metallic highlight barely shifting on the chest"
    "helm|medieval closed iron helmet|subtle metallic highlight barely shifting"
    "bolt|crackling lightning bolt|tiny electric sparks barely visible flickering"
    "fireball|swirling orange fireball with embers|flames gently flickering slightly"
    "crystal|faceted red crystal on gold base|gentle inner glow pulsing very slowly"
    "rune|ancient stone rune tablet|engraved gold symbols barely glowing slowly"
    "orb|mystical arcane orb with swirling mist|inner mist rotating very slowly inside the orb"
    "barrier|magical shield dome|subtle energy ripple barely visible"
    "snowflake|six-pointed ice snowflake|ice crystal barely shimmering with tiny sparkle"
    "water_drop|blue water droplet|subtle ripple barely visible inside the droplet"
    "flame|dancing flame tongue|flame tip gently wavering slightly"
    "heart|anatomical dark heart with dagger|very subtle heart beat pulse barely visible"
    "skull|human skeleton skull|faint glow barely visible in the eye sockets"
    "skull_crowned|royal skull with gold crown|faint glow barely visible in the eye sockets"
    "eye|mystical all-seeing eye|slow gentle blink barely visible"
    "gem|cut red ruby gemstone|subtle sparkle on the gem facets slowly"
    "coin|stack of gold coins|subtle golden shine barely visible on top coin"
    "potion_red|red healing potion bottle with cork|small bubble rising slowly inside the liquid"
    "potion_blue|blue mana potion bottle with cork|small bubble rising slowly inside the liquid"
    "star|five-pointed gold star|subtle twinkle barely visible at tip"
    "moon|crescent gold moon|subtle shimmer barely visible"
    "scroll|rolled aged parchment scroll|parchment edges barely curling"
    "mask|theater mask with purple and gold|faint glow barely visible in the eye holes"
    "jester_hat|three-pointed jester hat with bells|bells barely jingling with tiny motion"
)

TOTAL=${#JOBS[@]}
echo "[animate_all] Total: $TOTAL ícones"
I=0
for job in "${JOBS[@]}"; do
    I=$((I+1))
    IFS='|' read -r NAME DESC ACTION <<< "$job"
    if [[ ! -f "assets/sprites/icons/${NAME}.png" ]]; then
        echo "[$I/$TOTAL] SKIP $NAME (source não existe)"
        continue
    fi
    echo "[$I/$TOTAL] Animando $NAME..."
    ./scripts/animate_icon.sh "$NAME" "$DESC" "$ACTION" 4 > /dev/null 2>&1 || echo "  ERRO em $NAME"
    SZ=$(ls -la "assets/sprites/icons_anim/${NAME}/" 2>/dev/null | wc -l)
    echo "  → $SZ arquivos em icons_anim/${NAME}/"
done
echo "[animate_all] OK"
