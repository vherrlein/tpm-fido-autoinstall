[ -d ./dist ] && rm -rf ./dist
mkdir -p dist

cmd=$(command -v docker || command -v podman)

$cmd build -t tpm-fido --label=tpm-fido --layer-label=tpm-fido --platform linux/amd64 --output=dist .
$cmd builder prune --filter label=tpm-fido -f
$cmd image prune --filter label=tpm-fido -f
$cmd image rm localhost/tpm-fido:latest -f

exit 0