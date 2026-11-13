#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

site_path=${1:?Informe o diretório do site}
archive=${2:?Informe o arquivo enviado pelo CI}
revision=${3:?Informe o commit}
[[ "$archive" =~ ^\.hackarun8-[0-9]+-[0-9]+\.tar\.gz$ && "$revision" =~ ^[0-9a-f]{40}$ ]]
archive="$HOME/$archive"
[[ "$site_path" == "$HOME/htdocs/hackarun8.safra.dev" && -f "$site_path/.env" && -f "$site_path/artisan" ]]

deploy_dir="$HOME/.hackarun8-deploy"
mkdir -p "$deploy_dir"
exec 9>"$deploy_dir/deploy.lock"
flock -w 60 9
stage=$(mktemp -d "$deploy_dir/stage.XXXXXX")
backup=''
maintenance=false
code_changed=false

php_live() {
    (cd "$site_path" && php artisan "$@" --no-interaction)
}

sync_options=(
    -rlpt --delete
    --exclude='/.env' --exclude='/.env.*' --exclude='/.git' --exclude='/storage/'
    --exclude='/bootstrap/cache/' --exclude='/node_modules/'
    --exclude='/database/*.sqlite*' --exclude='/public/storage' --exclude='/public/.well-known/'
    --exclude='*.apk' --exclude='.user.ini' --exclude='auth.json'
)

cleanup() {
    local status=$?
    trap - EXIT
    if [[ "$status" != 0 && "$code_changed" == true ]]; then
        echo 'Falha no deploy. Restaurando os arquivos da versão anterior.' >&2
        if [[ "$maintenance" == false ]]; then
            php_live down --retry=15 && maintenance=true
        fi
        if ! rsync "${sync_options[@]}" "$backup/" "$site_path/" || ! php_live config:clear || ! php_live route:clear || ! php_live view:clear || ! php_live package:discover; then
            echo "Falha na restauração. Backup disponível em $backup." >&2
            exit "$status"
        fi
    fi
    if [[ "$maintenance" == true ]]; then
        php_live up || status=1
    fi
    rm -rf -- "$stage"
    rm -f -- "$archive"
    exit "$status"
}
trap cleanup EXIT

tar --extract --gzip --file "$archive" --directory "$stage" --same-permissions --no-same-owner
chmod --reference="$site_path" "$stage"
test -f "$stage/public/build/manifest.json"
test -f "$stage/vendor/autoload.php"
php -l "$stage/public/index.php"
php -r 'require $argv[1];' "$stage/vendor/autoload.php"

# Guarde um backup privado dos arquivos gerenciados. Banco e storage ficam no servidor.
backup=$(mktemp -d "$deploy_dir/backup-$revision.XXXXXX")
rsync "${sync_options[@]}" "$site_path/" "$backup/"
php_live down --retry=15
maintenance=true
code_changed=true
rsync "${sync_options[@]}" "$stage/" "$site_path/"
php_live config:clear
php_live route:clear
php_live view:clear
php_live package:discover
php_live migrate --force
php_live config:cache
php_live up
maintenance=false

curl --fail --silent --show-error --max-time 15 --retry 3 "https://hackarun8.safra.dev/api/v1/lojas?deploy=$revision" |
    php -r '$body = json_decode(stream_get_contents(STDIN), true, 512, JSON_THROW_ON_ERROR); exit(is_array($body["data"] ?? null) ? 0 : 1);'
printf '%s\n' "$revision" > "$deploy_dir/current-commit"
echo "Deploy concluído. Backup anterior em $backup."
