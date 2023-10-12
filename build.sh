#!/bin/bash
set -exo pipefail

_pkgbase=xt_wgobfs
pkgname=${_pkgbase}-dkms
pkgver=0.4.2
pkgdesc='iptables WireGuard obfuscation extension'
arch='x86_64'
url='https://github.com/infinet/xt_wgobfs'
license=('GPL')
depends=('dkms' 'iptables')
source="https://github.com/infinet/xt_wgobfs/releases/download/v${pkgver}/xt_wgobfs-${pkgver}.tar.xz"
source_sha256sum='09fa493d8305e1fa3224a940cab607b1860a9b5d9d395615105c7009e2bec767'

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
  ./configure --without-kbuild --with-xtlibdir="${pkgdir}/usr/lib/xtables"
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
  install -Dm644 Kbuild chacha8.c chacha8.h wg.h xt_WGOBFS.h xt_WGOBFS_main.c -t "${pkgdir}/usr/src/${_pkgbase}-${pkgver}/"

  # Install extension
  cd "${srcdir}/${_pkgbase}-${pkgver}"
  mkdir -p "${pkgdir}/usr/lib/xtables"
  make libxt-install
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
