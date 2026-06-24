#!/bin/bash
set -e

echo "==> iPhoto macOS Test-VM Setup"
echo ""

# KVM prüfen
echo "==> Prüfe KVM-Support..."
if ! cpu_flags=$(grep -m1 -E "vmx|svm" /proc/cpuinfo 2>/dev/null); then
    echo "FEHLER: Kein KVM-Support gefunden. Virtualisierung muss im BIOS aktiviert sein."
    exit 1
fi
echo "    OK: KVM-Support vorhanden"
echo ""

# Docker prüfen / installieren
if ! command -v docker &>/dev/null; then
    echo "==> Installiere Docker..."
    sudo apt-get update -qq
    sudo apt-get install -y docker.io
    sudo systemctl enable --now docker
else
    echo "==> Docker bereits installiert: $(docker --version)"
fi

# Abhängigkeiten installieren
echo "==> Installiere Abhängigkeiten..."
sudo apt-get install -y \
    qemu-kvm \
    libvirt-daemon-system \
    bridge-utils \
    x11-xserver-utils \
    curl \
    unzip 2>/dev/null

# Benutzer zu Gruppen hinzufügen
echo "==> Füge $USER zu docker/kvm-Gruppen hinzu..."
sudo usermod -aG docker "$USER" 2>/dev/null || true
sudo usermod -aG kvm    "$USER" 2>/dev/null || true
sudo usermod -aG libvirt "$USER" 2>/dev/null || true

# iPhoto Artifact herunterladen
echo ""
echo "==> Lade iPhoto von GitHub Actions herunter..."
echo "    Öffne: https://github.com/C0d3Crush/iPhoto/actions"
echo "    → Neuester Run → Artifacts → iPhoto-*.zip herunterladen"
echo "    Dann hier den Pfad eingeben (oder Enter für ~/Downloads/iPhoto*.zip):"
read -r IPHOTO_ZIP
if [ -z "$IPHOTO_ZIP" ]; then
    IPHOTO_ZIP=$(ls ~/Downloads/iPhoto*.zip 2>/dev/null | head -1)
fi

if [ -z "$IPHOTO_ZIP" ] || [ ! -f "$IPHOTO_ZIP" ]; then
    echo "    WARNUNG: iPhoto ZIP nicht gefunden. Du kannst es später manuell in die VM kopieren."
    SHARE_DIR="$HOME/macos-shared"
else
    SHARE_DIR="$HOME/macos-shared"
    mkdir -p "$SHARE_DIR"
    cp "$IPHOTO_ZIP" "$SHARE_DIR/"
    echo "    ZIP nach $SHARE_DIR kopiert."
fi

mkdir -p "$SHARE_DIR"

# Startskript erstellen
cat > "$HOME/start-macos-vm.sh" << VMSCRIPT
#!/bin/bash
echo "==> Starte macOS Sonoma VM..."
echo "    Geteilter Ordner: $SHARE_DIR → in VM unter /Shared verfügbar"
echo "    Beim ersten Start macOS einrichten (dauert 10–20 Minuten)"
echo ""

# X11 erlauben
xhost +local:docker 2>/dev/null || true

docker run -it \\
  --device /dev/kvm \\
  -p 50922:10022 \\
  -v /tmp/.X11-unix:/tmp/.X11-unix \\
  -v "$SHARE_DIR:/mnt/shared" \\
  -e "DISPLAY=\${DISPLAY:-:0.0}" \\
  -e GENERATE_UNIQUE=true \\
  -e MASTER_PLIST_URL='https://raw.githubusercontent.com/sickcodes/osx-serial-generator/master/config-custom.plist' \\
  -e WIDTH=1440 \\
  -e HEIGHT=900 \\
  sickcodes/docker-osx:sonoma
VMSCRIPT
chmod +x "$HOME/start-macos-vm.sh"

echo ""
echo "================================================================"
echo " Setup abgeschlossen!"
echo "================================================================"
echo ""
echo " WICHTIG: Melde dich ab und wieder an (Gruppen-Update):"
echo "   su - $USER"
echo ""
echo " Danach VM starten mit:"
echo "   ~/start-macos-vm.sh"
echo ""
echo " iPhoto in der VM installieren:"
echo "   1. macOS einrichten (beim ersten Start)"
echo "   2. Finder → Gehe zu → /Volumes/My Shared Files"
echo "      oder Terminal: open /mnt/shared"
echo "   3. iPhoto ZIP entpacken"
echo "   4. iPhoto.app nach Programme ziehen"
echo "   5. Rechtsklick → Öffnen (Gatekeeper umgehen)"
echo ""
if [ -n "$IPHOTO_ZIP" ] && [ -f "$IPHOTO_ZIP" ]; then
    echo " iPhoto ZIP liegt bereit in: $SHARE_DIR"
fi
echo "================================================================"
