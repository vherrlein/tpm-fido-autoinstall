CURRENT_USER=$(whoami)
UDEV_RULE_FILE_PATH=/etc/udev/rules.d/tpm-udev.rules
MODULE_UHID_CONF_PATH=/etc/modules-load.d/uhid.conf
TPM_SERVICE_PATH=/etc/systemd/user/tpm-fido.service
TPM_FIDO_BIN_PATH=./dist/tpm-fido
TPM_FIDO_USRBIN_PATH=/usr/bin/tpm-fido
echo "--> Build <--"
([ ! -f "$TPM_FIDO_BIN_PATH" ] && echo "Build tpm-fido binary" && sudo ./build.sh) ||
([ -f "$TPM_FIDO_BIN_PATH" ] && echo "Binary found" && echo "") || (echo "Cannot build the binary" && exit -1)


echo "--> Install <--"

echo "Copy binary to usr bin"

sudo cp -f "$TPM_FIDO_BIN_PATH" "$TPM_FIDO_USRBIN_PATH"
sudo chmod +x "$TPM_FIDO_USRBIN_PATH"

echo "Add ${CURRENT_USER} to tss group"
sudo usermod -a -G tss $CURRENT_USER

echo "Add/Update UDEV rule to grant TSS members to access tpm devices"

if test -f "$UDEV_RULE_FILE_PATH"; then
    sudo rm -f $UDEV_RULE_FILE_PATH
fi

cat << EOF | sudo tee $UDEV_RULE_FILE_PATH > /dev/null
# tpm devices can only be accessed by the tss user but the tss
# group members can access tpmrm devices
KERNEL=="tpm[0-9]*", TAG+="systemd", MODE="0660", OWNER="tss"
KERNEL=="tpmrm[0-9]*", TAG+="systemd", MODE="0660", GROUP="tss"
KERNEL=="tcm[0-9]*", TAG+="systemd", MODE="0660", OWNER="tss"
KERNEL=="tcmrm[0-9]*", TAG+="systemd", MODE="0660", GROUP="tss"
KERNEL=="uhid", SUBSYSTEM=="misc", GROUP="tss", MODE="0660"
EOF
sudo udevadm control --reload-rules && sudo udevadm trigger

if test -f "$MODULE_UHID_CONF_PATH"; then
    sudo rm -f $MODULE_UHID_CONF_PATH
fi

cat << EOF | sudo tee $MODULE_UHID_CONF_PATH > /dev/null
uhid
EOF

echo "Create service $TPM_SERVICE_PATH"

if test -f "$TPM_SERVICE_PATH"; then
    systemctl --user stop tpm-fido
    sudo rm -f $TPM_SERVICE_PATH
fi

cat << EOF | sudo tee $TPM_SERVICE_PATH > /dev/null
[Unit]
Description=FIDO Implementation using TPM
After=tpm2.target graphical-session.target
BindsTo=graphical-session.target
PartOf=graphical-session.target
Requisite=graphical-session.target

[Service]
Type=simple
Environment="DISPLAY=:0"
Environment="WAYLAND_DISPLAY=wayland-0"
Environment="XDG_SESSION_CLASS=user"
Environment="QT_WAYLAND_RECONNECT=1"
Environment="QT_AUTO_SCREEN_SCALE_FACTOR=0"
ExecStart=/usr/bin/tpm-fido
SyslogIdentifier=tpm-fido

[Install]
WantedBy=graphical-session.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now tpm-fido

echo "In case the TPM 2.0 is DA lockout mode, run the following command to reset it"
echo "$ sudo tpm2_dictionarylockout --setup-parameters --max-tries=4294967295 --clear-lockout"

echo "You must reboot to take effects"
