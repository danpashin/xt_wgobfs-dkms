#!/bin/bash
set -exo pipefail

_pkgbase=xt_wgobfs
pkgname=${_pkgbase}-dkms
pkgver=0.5.0
pkgdesc='iptables WireGuard obfuscation extension'
arch='x86_64'
url='https://github.com/infinet/xt_wgobfs'
license=('GPL')
depends=('dkms' 'iptables')
source="https://github.com/infinet/xt_wgobfs/releases/download/v${pkgver}/xt_wgobfs-${pkgver}.tar.xz"
source_sha256sum='3d1c6304b92b1977aeeafa875323b85bdbe69272c481aa5c07c39051fef92655'

basedir=$(
    RL=$(readlink -n "$0")
    SP="${RL:-$0}"
    dirname "$(
        cd "$(dirname "${SP}")"
        pwd
    )/$(basename "${SP}")"
)
srcdir="${basedir}/src"
pkgdir="${basedir}/pkg"
outdir=${OUTDIR:=$basedir}

download() {
    src_name="${_pkgbase}-${pkgver}.tar.xz"

    curl -L -o "${src_name}" "${source}"
    echo "${source_sha256sum} ${src_name}" | sha256sum --check
    tar xf "${src_name}"
}

build() {
  cd "${srcdir}/${_pkgbase}-${pkgver}"
  ./autogen.sh
  ./configure --without-kbuild
  make libxt-local
}

package() {
  # Install scripts
  install -Dm755 package-files/postinst package-files/prerm -t "${pkgdir}/DEBIAN/"
  find "${pkgdir}/DEBIAN/" -type f -exec \
    sed -e "s/@_PKGBASE@/${_pkgbase}/" -e "s/@PKGVER@/${pkgver}/" -i "{}" +

  # Install kernel module sources
  install -Dm644 package-files/dkms.conf package-files/Makefile -t "${pkgdir}/usr/src/${_pkgbase}-${pkgver}/"
  sed -e "s/@_PKGBASE@/${_pkgbase}/" \
      -e "s/@PKGVER@/${pkgver}/" \
      -i "${pkgdir}/usr/src/${_pkgbase}-${pkgver}/dkms.conf"
  cd "${srcdir}/${_pkgbase}-${pkgver}/src"
  install -Dm644 Kbuild chacha.c chacha.h wg.h xt_WGOBFS.h xt_WGOBFS_main.c -t "${pkgdir}/usr/src/${_pkgbase}-${pkgver}/"

  # Install extension
  cd "${srcdir}/${_pkgbase}-${pkgver}"
  mkdir -p "${pkgdir}$(pkg-config --variable=xtlibdir xtables)"
  make libxt-install DESTDIR="${pkgdir}"
}

rm -rf "${pkgdir}" > /dev/null || true
mkdir -p "${srcdir}" "${pkgdir}"


# Compile all sources
pushd "${srcdir}"
    download
    build
popd

pushd .
    package
popd

# Create DEB
mkdir -p "$outdir" > /dev/null || true
cd "$outdir"
fpm \
    --input-type dir \
    --output-type deb \
    --force \
    --log warn \
    --name "${pkgname}" \
    --architecture "${arch}" \
    --maintainer infinet \
    --deb-priority optional \
    --depends "$(IFS=", "; echo "${depends[*]}")" \
    --description "${pkgdesc}" \
    --version "${pkgver}" \
    --license "${license[*]}" \
    --url "${url}" \
    --after-install "${pkgdir}/DEBIAN/postinst" \
    --pre-uninstall "${pkgdir}/DEBIAN/prerm" \
    "${pkgdir}/usr=/" \
    ;

# Cleanup
rm -rf "${pkgdir}"
exit 0
