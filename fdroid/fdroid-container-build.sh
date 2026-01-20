#!/usr/bin/env bash
#
# F-Droid Container Build Script
# This script runs inside the fdroidserver Docker container
# Called by fdroid-local-build.sh
#
set -ex

export home_vagrant=/home/vagrant
export ANDROID_HOME=/opt/android-sdk
export CI_PROJECT_DIR=/fdroiddata

cd /fdroiddata
chown -R "$(whoami)" .

for d in logs tmp unsigned "$home_vagrant"/.android "$home_vagrant"/.gradle "$home_vagrant"/metadata "$home_vagrant"/build; do
    test -d "$d" || mkdir -p "$d"
    chown -R vagrant "$d" 2>/dev/null || true
done

export fdroidserver=/opt/fdroidserver
rm -rf "$fdroidserver"
mkdir -p "$fdroidserver"
curl -fsSL https://gitlab.com/fdroid/fdroidserver/-/archive/master/fdroidserver-master.tar.gz \
    | tar -xz --directory="$fdroidserver" --strip-components=1

export PATH="$fdroidserver:$PATH"
export PYTHONPATH="$fdroidserver:$fdroidserver/examples"
export PYTHONUNBUFFERED=true

sdkmanager "platform-tools" "build-tools;31.0.0"

if [[ -d "$home_vagrant/gradlew-fdroid" ]]; then
    git -C "$home_vagrant/gradlew-fdroid" pull || true
else
    git clone https://gitlab.com/niccokunzmann/gradlew-fdroid.git "$home_vagrant/gradlew-fdroid" || true
fi

curl -fsSL 'https://gitlab.com/fdroid/fdroid-bootstrap-buildserver/-/raw/master/roles/production_hardening/files/gitconfig' >> /root/.gitconfig

ln -sf "$home_vagrant/.gradle" /fdroiddata/.gradle 2>/dev/null || true
ln -sf /fdroiddata/tmp "$home_vagrant/tmp" 2>/dev/null || true
ln -sf /fdroiddata/srclibs "$home_vagrant/srclibs" 2>/dev/null || true

sysctl fs.inotify.max_user_watches=524288 2>/dev/null || true

export GRADLE_USER_HOME="$home_vagrant/.gradle"

# Install Java 21 (required for Status app)
apt-get install -y sudo openjdk-21-jdk-headless
update-alternatives --set java /usr/lib/jvm/java-21-openjdk-amd64/bin/java || true

# Set up fdroid command with vagrant user
fdroid_cmd="sudo --preserve-env --user vagrant \
    env PATH=$fdroidserver:\$PATH \
    env PYTHONPATH=$fdroidserver:$fdroidserver/examples \
    env PYTHONUNBUFFERED=true \
    env TERM=$TERM \
    env HOME=$home_vagrant \
    fdroid"

appid="${BUILD_TARGET%:*}"
cp -R /fdroiddata/build "$home_vagrant/build" 2>/dev/null || mkdir -p "$home_vagrant/build"
[[ -d "/fdroiddata/metadata/$appid" ]] && cp -R "/fdroiddata/metadata/$appid" "$home_vagrant/metadata/"
cp -R "/fdroiddata/metadata/$appid.yml" "$home_vagrant/metadata/"
chown -R vagrant "$home_vagrant" /fdroiddata

pushd "$home_vagrant"
ln -sf /fdroiddata "$home_vagrant/fdroiddata"
ln -sf /root/.gitconfig "$home_vagrant/.gitconfig" 2>/dev/null || true

eval "$fdroid_cmd fetchsrclibs $BUILD_TARGET --verbose"

rm -f "$home_vagrant/fdroiddata" "$home_vagrant/.gitconfig"

# unset CI to prevent CI-specific behaviors
(unset CI; eval "$fdroid_cmd build --verbose --test --refresh-scanner --on-server --no-tarball $BUILD_TARGET")

popd

ls -la /fdroiddata/tmp/*.apk
